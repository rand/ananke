# Type Inhabitation

The type inhabitation system converts type analysis into token masks for
constrained decoding. Given a target type and a set of in-scope bindings, it
determines which tokens can begin or continue an expression that will produce a
value of that type, then feeds those decisions into the CLaSH Types hard domain.

The question it answers is not "is this well-typed?" but "what can I write here
that would have this type?" The first is a verdict. The second is guidance.

## Overview

Four modules, layered bottom-up:

| Module | File | Tests | Role |
|--------|------|------:|------|
| TypeArena | `src/braid/types/type_system.zig` | 5 | Arena-allocated unified type representation |
| TypeParser | `src/braid/types/parser.zig` | 7 | Parse string type signatures into Type nodes |
| InhabitationGraph | `src/braid/types/inhabitation.zig` | 4 | BFS reachability over type-to-type transitions |
| MaskGenerator | `src/braid/types/mask_generator.zig` | 8 | Convert reachability into token masks |

Total: 24 tests across the subsystem.

## TypeArena

Arena-allocated type representation supporting 10 languages.

### Language

The `Language` enum has 10 variants: `typescript`, `javascript`, `python`,
`rust`, `go`, `java`, `cpp`, `csharp`, `kotlin`, `zig_lang`.

Each variant implements `getTypeSyntax()`, returning a `TypeSyntax` struct with
language-specific notation: array prefix/suffix, generic brackets, function
arrow, nullable and optional suffixes. This is the single source of truth for
how each language spells its type syntax.

### PrimitiveKind

20 variants: `void_type`, `boolean`, `i8`, `i16`, `i32`, `i64`, `u8`, `u16`,
`u32`, `u64`, `f32`, `f64`, `number` (JS/TS unified), `string`, `char`,
`null_type`, `undefined`, `any`, `unknown`, `never`.

Methods:
- `isNumeric()` -- true for all integer and float kinds, plus `number`.
- `isIntegral()` -- true for i8..u64 only.
- `canonicalName(Language)` -- returns the language-native spelling.
  `string` in TypeScript, `str` in Python, `String` in Rust, `[]const u8` in
  Zig. Coverage is not exhaustive; less common primitives fall through to
  `"unknown"`.

### Type

A tagged union with 12 variants:

- **primitive** -- a `PrimitiveKind`
- **array** -- pointer to element type
- **tuple** -- slice of element types
- **object** -- named fields with optional/readonly flags
- **function** -- params (with optional names, rest, optional flags) + return type + async/generator flags
- **union_type** -- slice of member types
- **intersection** -- slice of member types
- **optional** -- wraps an inner type (T? / Option\<T\>)
- **named** -- name string + optional language tag
- **generic** -- base type + slice of type parameters
- **reference** -- pointee + mutability (Rust &/&mut, Go *)
- **error_union** -- ok type + optional error type (Rust Result, Zig error union)

Key methods:

- `isAssignableTo(target, language)` -- structural assignability with
  language-specific coercion rules. `any` accepts everything. TS/JS unifies all
  numeric types. Python allows int->float. JS/TS treats null and undefined as
  interchangeable. Union types require all members to be assignable. Primitives
  can be wrapped into optionals.
- `hash()` -- Wyhash over tag + contents, used to key the inhabitation graph.
- `eql()` -- structural equality.
- `containsNamed(name)` -- recursive search for a named type within compounds.

### Allocation

`TypeArena` wraps a Zig `ArenaAllocator`. All nodes go into one arena -- no
individual frees, one `deinit()` releases everything. Factory methods:
`primitive()`, `array()`, `optional()`, `named()`, `unionType()`, `function()`,
`generic()`.

## TypeParser

Parses string type signatures into the unified `Type` representation.

Entry point: `TypeParser.parse(type_sig: []const u8) !*Type`. The parser resets
`pos` to 0 on each call, so one instance handles multiple signatures
sequentially.

### Per-language parsing

Each language gets its own compound-type parser. After trying primitives
(language-specific keyword lists), the parser dispatches:

| Language | Arrays | Optionals | Maps / Dicts | Error types | References | Functions |
|----------|--------|-----------|--------------|-------------|------------|-----------|
| TypeScript | `Array<T>`, `T[]` | `T?` | -- | -- | -- | `(p: T) => R` |
| Python | `List[T]` | `Optional[T]` | `Dict[K, V]` | -- | -- | `Callable[[...], R]` (simplified) |
| Rust | `Vec<T>` | `Option<T>` | -- | `Result<T, E>` | `&T`, `&mut T` | -- |
| Go | `[]T` | -- | `map[K]V` | -- | `*T` | -- |
| Java | `List<T>` | `Optional<T>` | `Map<K, V>` | -- | -- | -- |
| C++ | `std::vector<T>` | `std::optional<T>` | `std::map<K, V>` | -- | -- | -- |
| C# | `List<T>` | `T?` | `Dictionary<K, V>` | -- | -- | -- |
| Kotlin | `List<T>` | `T?` | `Map<K, V>` | -- | -- | -- |
| Zig | `[]T` | `?T` (prefix) | -- | error unions (simplified) | -- | -- |

Named types with generic parameters are parsed generically: identifier followed
by `<` (or `[` for Python), up to 8 type parameters, then close bracket.
TypeScript function params are capped at 16. Go's `interface{}` parses directly
as `any`.

## InhabitationGraph

The core analysis. Nodes are types, edges are operations that transform an
expression of one type into another.

### EdgeKind

9 variants:

| Kind | Meaning | Example |
|------|---------|---------|
| `coercion` | Implicit conversion | int -> float |
| `binary_op` | Operator result | `number + number -> number` |
| `property` | Property access | `.length` |
| `method` | Method call | `.toString()` |
| `application` | Function application | `String(x)`, `parseInt(x)` |
| `indexing` | Array/object index | `arr[0]` |
| `construction` | Literal start | `"`, digit, boolean keyword |
| `template` | Template/interpolation | `` `${ `` , `f"{ `, `$"{ ` |
| `assertion` | Type cast | -- |

### Edge

Each edge carries: `kind`, `target_type`, `token_pattern` (the string the LLM
would emit), `description`, and `priority` (higher wins in conflicts).

### Binding

A name + type pair representing a variable in scope. If a token matches a
binding name, reachability is checked from the binding's type to the goal.

### Built-in edges

`addBuiltinEdges()` dispatches to per-language edge sets. Each populates its
idiomatic type conversion vocabulary:

- **TypeScript**: `number` to `string` via `.toString()`, `.toFixed()`,
  `String()`, template literals. Reverse via `.length`, `parseInt()`,
  `parseFloat()`, `Number()`, unary `+`. Arithmetic, comparisons, string
  concatenation. Literal construction for `"`, `'`, `` ` ``, digits, `true`,
  `false`.

- **Python**: `str()`, `int()`, `float()`, `len()`, f-strings. Literals for
  `"`, `'`, digits, `True`, `False`.

- **Rust**: `.to_string()`, `.parse()`, `.len()`, `format!()`. Literals for
  `"`, digits, `true`, `false`.

- **Go**: `strconv.Itoa()`, `strconv.Atoi()`, `fmt.Sprintf()`, `len()`.

- **Java**: `String.valueOf()`, `Integer.toString()`, `Integer.parseInt()`,
  `.length()`.

- **C++**: `std::to_string()`, `std::stoi()`, `.length()`.

- **C#**: `.ToString()`, `int.Parse()`, `.Length`, `$"{"` interpolation.

- **Kotlin**: `.toString()`, `.toInt()`, `.length`, `"$"` templates.

- **Zig**: `std.fmt.allocPrint()`, `std.fmt.parseInt()`, `.len`.

Construction edges originate from a synthetic `any` type node, representing the
start-of-expression case. A digit can begin a number; a quote can begin a
string.

### Reachability

`isReachable(source, target)` runs BFS from source, checking `isAssignableTo`
at each node and exploring outgoing edges. Results are cached (`TypePair ->
bool`); the cache is invalidated when edges are added.

`getValidTransitions(current, goal)` returns edges from `current` whose target
can reach `goal`. If `current` is null, returns construction edges filtered to
those whose target reaches the goal.

`canTokenLeadToGoal(token, current_type, goal_type)` is the top-level query:
1. Token matches a binding name -- check reachability from binding type to goal.
2. Token matches a transition pattern from `getValidTransitions`.

Pattern matching is prefix-based: single-character patterns check the token's
first character; multi-character patterns check prefix or exact match.

## MaskGenerator

Converts inhabitation analysis to token masks for constrained decoding.

### TokenMaskData

Two optional fields: `allowed_tokens` and `forbidden_tokens`, each `[]u32`.
With a tokenizer, `generateMask` scans the full vocabulary and populates
`allowed_tokens`. Without one, it returns pattern-based hints with null IDs --
the sglang backend resolves patterns to token IDs downstream.

### TypeInhabitationState

Progressive generation state, tracking where we are mid-expression:

- `current_type: ?*const Type` -- type of the partial expression so far.
  Null at the start.
- `goal_type: *const Type` -- what we need to end up with.
- `bindings: []const Binding` -- variables in scope.
- `partial_expression` -- string of tokens consumed so far.
- `language` -- the source language.

`toJson()` serializes the state for transmission to the sglang backend.
This is the wire format between Braid (Zig) and the inference server (Python).

### advanceState

The state machine that updates `current_type` as tokens are consumed:

1. **Binding lookup**: if `current_type` is null and the token matches a
   binding name, `current_type` becomes the binding's type.
2. **Literal start**: if `current_type` is null and the token begins a string
   literal (quote character, or `f"` in Python), number literal (digit), or
   boolean literal (`true`/`false`, or `True`/`False` in Python),
   `current_type` becomes the corresponding primitive.
3. **Edge transition**: if `current_type` is set, check the graph for edges
   from the current type whose `token_pattern` matches the token. First match
   wins; `current_type` becomes the edge's `target_type`.

### canFinish

Returns true when `current_type.isAssignableTo(goal_type, language)`. If
`current_type` is null (nothing generated yet), only returns true when the goal
is `void_type` -- you can finish an empty expression only when nothing is
expected.

### TypeInhabitationBuilder

Convenience for constructing a `TypeInhabitationState` from hole context.
`buildFromHole(expected_type, bindings)` parses the expected type string and
each binding's type annotation through `TypeParser`, producing a ready-to-use
state. Unknown type annotations fall back to `any`.

## Cross-language normalization

The parser normalizes 10 languages' type syntax into one representation. Some of
the more entertaining divergences:

- Zig uses prefix optional `?T`. Everyone else uses suffix (`T?`) or wrapper
  (`Optional[T]`, `Option<T>`, `std::optional<T>`).
- Rust spells error unions as `Result<T, E>`. Zig uses `T!E`. The parser maps
  both to the `error_union` variant.
- Go has no generics syntax for built-in collection types: `[]int` is a slice,
  `map[string]int` is a map. These are parsed structurally rather than as
  generic applications.
- Python's `Optional[T]` is sugar for `Union[T, None]`. The parser normalizes
  it to the `optional` variant directly.
- JavaScript and TypeScript unify all numeric types into `number`. The
  `isAssignableTo` check knows this: in TS/JS, any numeric primitive is
  assignable to any other.

The TypeArena handles assignability rules that depend on language semantics
rather than syntax: TS/JS numeric unification, Python int-to-float coercion,
null/undefined interop in JS/TS.

## Integration with CLaSH

Type inhabitation feeds the **Types** hard domain in the CLaSH constraint
algebra. During domain fusion (`src/braid/domain_fusion.zig`), token masks from
three hard domains compose by intersection:

```
valid_tokens = syntax_mask  &cap;  type_mask  &cap;  import_mask
```

A token blocked by any hard domain is impossible to generate. Soft domains
(ControlFlow, Semantics) reweight logits within this feasible set but never
block.

If inhabitation cannot determine valid transitions, it returns top (all tokens
allowed) rather than bottom. Missing type information never blocks generation.
Conservative about what it forbids, permissive about what it does not
understand.

## Limitations

- Pattern matching is prefix-based, not regex. Sufficient for idiomatic
  patterns but would need extension for more complex token-level analysis.
- Construction edges originate from a single `any` node -- no
  context-sensitive construction (e.g., different literal forms inside vs.
  outside a template).
- The parser covers common generic patterns per language but not every
  possible type expression. Unrecognized syntax is preserved as named types.
- Without a tokenizer attached, `generateMask` returns null token IDs.
  The actual vocabulary scan requires the tokenizer interface.

## References

- Source: `src/braid/types/type_system.zig` (5 tests)
- Source: `src/braid/types/parser.zig` (7 tests)
- Source: `src/braid/types/inhabitation.zig` (4 tests)
- Source: `src/braid/types/mask_generator.zig` (8 tests)
- `src/braid/domain_fusion.zig` -- CLaSH domain intersection
- SPEC-01: CLaSH Constraint Algebra (Types domain)
