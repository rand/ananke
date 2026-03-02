# Language Support

Ananke extracts structural constraints from source code using a hybrid
tree-sitter AST + pattern-matching pipeline. Fourteen languages are supported.
All fourteen have vendored tree-sitter grammars. The difference between tiers is
testing maturity, not capability.

## Support Matrix

| Language   | Extensions                    | Extractor        | Patterns | Tier | Confidence |
|------------|-------------------------------|------------------|----------|------|------------|
| C          | `.c` `.h`                     | `c.zig`          | 29       | 1    | 0.95       |
| C++        | `.cpp` `.cc` `.hpp`           | `cpp.zig`        | 44       | 1    | 0.95       |
| Go         | `.go`                         | `go.zig`         | 30       | 1    | 0.95       |
| Java       | `.java`                       | `java.zig`       | 42       | 1    | 0.95       |
| JavaScript | `.js` `.jsx`                  | `javascript.zig` | 24       | 1    | 0.95       |
| Python     | `.py`                         | `python.zig`     | 22       | 1    | 0.95       |
| Rust       | `.rs`                         | `rust.zig`       | 27       | 1    | 0.95       |
| TypeScript | `.ts` `.tsx`                  | `typescript.zig` | 23       | 1    | 0.95       |
| Zig        | `.zig`                        | `zig_lang.zig`   | 29       | 1    | 0.95       |
| C#         | `.cs`                         | `csharp.zig`     | 26       | 2    | 0.85       |
| Kotlin     | `.kt` `.kts`                  | `kotlin.zig`     | 25       | 2    | 0.85       |
| PHP        | `.php`                        | `php.zig`        | 22       | 2    | 0.85       |
| Ruby       | `.rb` `.rake` `.gemspec`      | `ruby.zig`       | 16       | 2    | 0.85       |
| Swift      | `.swift`                      | `swift.zig`      | 24       | 2    | 0.85       |

**383 patterns** across 14 languages, 8 categories each.

All extractors live in `src/clew/extractors/`. Pattern definitions are in
`src/clew/patterns.zig`. Language detection by file extension is in
`src/clew/tree_sitter/parser.zig`.


## Tier 1 -- Full AST (9 languages)

C, C++, Go, Java, JavaScript, Python, Rust, TypeScript, Zig.

These languages have mature tree-sitter grammars vendored in `vendor/` and
extensive test coverage. Extraction performs a full AST walk via tree-sitter,
then supplements with pattern matching as a fallback. AST-extracted constraints
carry 0.95 confidence; pattern-only extraction drops to 0.75.

Vendored grammars:

- `tree-sitter-c` -- also provides the scanner used by C++
- `tree-sitter-cpp`
- `tree-sitter-go`
- `tree-sitter-java`
- `tree-sitter-javascript`
- `tree-sitter-python`
- `tree-sitter-rust`
- `tree-sitter-typescript` -- also covers JavaScript (JS is parsed as a subset)
- `tree-sitter-zig`

All Tier 1 languages support:

- Function signatures and return types
- Import/module analysis
- Error handling patterns (try/catch, Result, error unions, etc.)
- Async/await patterns (where the language has them)
- Security-relevant patterns
- Class/struct/interface/enum definitions
- All five CLaSH domains (Syntax, Types, Imports, ControlFlow, Semantics)
- Type inhabitation (for statically typed languages)


## Tier 2 -- AST + Patterns (5 languages)

C#, Kotlin, PHP, Ruby, Swift.

Same extraction pipeline, same feature set. Tree-sitter grammars are vendored
and AST extraction works. The 0.85 confidence reflects less battle-testing in
production, not a weaker extraction path. As test coverage accumulates, these
will graduate to Tier 1.

Vendored grammars:

- `tree-sitter-c-sharp`
- `tree-sitter-kotlin`
- `tree-sitter-php` -- uses nested path: `vendor/tree-sitter-php/php/`
- `tree-sitter-ruby`
- `tree-sitter-swift` -- alex-pinkus fork, pinned to `v0.7.1-with-generated-files`


## Pattern Categories

Every language defines patterns across the same eight categories. The split is
deliberate: it maps to the constraint kinds that flow into Braid compilation.

| Category              | What it matches                                      |
|-----------------------|------------------------------------------------------|
| `function_decl`       | Function and method declarations                     |
| `type_annotation`     | Type hints, annotations, generics                    |
| `async_pattern`       | async/await, promises, futures, actors               |
| `error_handling`      | try/catch, Result types, error unions, throws        |
| `imports`             | import/require/use/include statements                |
| `class_struct`        | Class, struct, interface, enum, protocol definitions |
| `metadata`            | Decorators, attributes, annotations, pragmas         |
| `memory_management`   | Ownership, borrowing, weak refs, GC hints            |

Not every category applies to every language. Python has no `memory_management`
patterns; C has no `async_pattern` entries. The schema is uniform; the content
is not. Languages get patterns where patterns make sense.


## Language-Specific Notes

**C++** has the most patterns (44). Templates, STL containers, RAII idioms, and
multiple inheritance all generate distinct constraint signals. The tree-sitter
grammar shares its scanner with the C grammar.

**Java** comes second (42). Annotations alone account for a meaningful chunk --
`@Override`, `@Deprecated`, `@FunctionalInterface`, etc. each carry semantic
weight that Braid uses during compilation.

**Go** leads Tier 1 at 30 patterns. Go's rigid conventions (exported names are
capitalized, error returns are idiomatic, goroutines follow patterns) make it
unusually pattern-friendly for a systems language.

**JavaScript and TypeScript** share the `tree-sitter-typescript` grammar.
JavaScript is parsed as a subset. Their pattern counts are close (24 vs 23) --
TypeScript adds type annotation patterns but drops a few JS-specific ones.

**Zig** uses `zig_lang.zig` as its extractor filename. `zig.zig` would shadow
the standard library import, which is the kind of bug you only make once.

**Swift** uses the alex-pinkus fork of tree-sitter-swift, not the official
repository. The fork is pinned to the `v0.7.1-with-generated-files` tag because
the main branch does not include the generated `parser.c`. This is the single
most fragile dependency in the vendor tree.

**PHP** has a nested vendor structure: `vendor/tree-sitter-php/php/`. The
upstream grammar repository contains multiple sub-grammars (PHP and PHP-only);
the build system selects the full PHP variant.

**Ruby** recognizes `.rake` and `.gemspec` in addition to `.rb`. Pattern count
is the lowest at 16 -- Ruby's metaprogramming-heavy style resists static
pattern matching. The AST path compensates.


## How Extraction Works

The `HybridExtractor` in `src/clew/hybrid_extractor.zig` orchestrates the
pipeline:

1. **Tree-sitter parse** -- Source is parsed into a concrete syntax tree. If
   parsing succeeds, the AST is walked to extract structural constraints
   (functions, types, imports, error handling). Confidence: 0.95.

2. **Pattern fallback** -- If tree-sitter parsing fails or as a supplement,
   pattern rules from `src/clew/patterns.zig` are matched line-by-line against
   the source. Confidence: 0.75 for pattern-only extraction.

3. **Constraint emission** -- Extracted constraints carry their confidence
   scores into Braid compilation, where they participate in CLaSH domain
   fusion, feasibility analysis, and priority scoring.

The strategy is always tree-sitter-first. Patterns exist because tree-sitter
grammars occasionally fail on malformed or partial code (think: mid-edit IDE
completions). The two paths are complementary, not competing.


## Adding a Language

The short version. See `docs/EXTENDING.md` for the full procedure.

1. Vendor the tree-sitter grammar into `vendor/tree-sitter-<lang>/`.
2. Add the grammar to `build.zig` -- compile the C parser and scanner.
3. Register the language enum variant in `src/clew/tree_sitter/parser.zig`,
   including file extension mappings.
4. Create `src/clew/extractors/<lang>.zig` implementing the `parse()` function
   that returns a `base.SyntaxStructure`.
5. Add pattern rules to `src/clew/patterns.zig` across the eight categories.
6. Wire it into `src/clew/extractors.zig` (the dispatch table).
7. Write tests. The extractor should handle empty input, single declarations,
   and realistic multi-construct source files.

Languages 1 through 9 took progressively less effort as the infrastructure
matured. Languages 10 through 14 were largely mechanical once the pattern was
established. Language 15 should take an afternoon.


## References

| Resource                        | Path                               |
|---------------------------------|------------------------------------|
| Extractors                      | `src/clew/extractors/`             |
| Pattern definitions             | `src/clew/patterns.zig`            |
| Hybrid extraction               | `src/clew/hybrid_extractor.zig`    |
| Tree-sitter integration         | `src/clew/tree_sitter/`            |
| Language detection               | `src/clew/tree_sitter/parser.zig` |
| Vendored grammars               | `vendor/tree-sitter-*/`            |
| Extension guide                 | `docs/EXTENDING.md`                |
