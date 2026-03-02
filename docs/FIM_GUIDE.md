# Fill-in-the-Middle Constrained Decoding

FIM generates code that fits between a prefix and a suffix. The cursor is in the
middle of a file, not at the end. Standard FIM models see both sides but enforce
nothing about how the generated code connects to them. Constrained FIM quotients
the grammar by the prefix and suffix, so every generated token is guaranteed to
produce a syntactically valid program when the three pieces are joined.

## The Problem with Unconstrained FIM

A FIM model receives prefix and suffix as context, but treats them as suggestions
rather than invariants. The model can generate code that:

- Introduces a syntax error at the join point (e.g., unbalanced delimiters)
- Uses variables that are not in scope at the cursor position
- Returns a type incompatible with what the suffix expects
- Breaks indentation or opens brackets that the suffix never closes

These are not rare edge cases. They are the common mode of failure for
unconstrained infill, because the model's token probabilities do not encode the
hard constraint that `prefix + generated + suffix` must parse.

## How Constraints Fix This

The key insight from Ugare et al. (2024) is that FIM can be reformulated as a
constrained decoding problem using grammar quotienting:

**Left-quotient by prefix.** Parse the prefix to determine the parser's state at
the cursor. The generated code must be a valid continuation from that state --
not from the start symbol of the grammar. If the prefix has two unmatched open
braces, the generator knows it is two scopes deep.

**Right-quotient by suffix.** The suffix constrains where the generated code must
lead. Generated tokens must leave the parser in a state where the suffix is a
valid next input. If the suffix starts with `}`, the generated code must
eventually close its scope to that depth.

The intersection of these two quotient grammars defines the exact set of valid
infills. At each decoding step, only tokens consistent with both constraints are
allowed. The result is not a heuristic filter -- it is a formal guarantee that
the joined output parses.

**Graceful degradation.** If the right-quotient fails (suffix is ambiguous or
incomplete), Ananke falls back to left-quotient only. If the left-quotient also
fails, it falls back to standard syntax constraints. You always get at least
syntax-level guarantees.

## Architecture

The FIM pipeline has two stages. The lightweight analysis happens in the CLI
(Zig). The heavy grammar quotienting happens at the sglang backend.

```
(prefix, suffix, language) --> FimContext --> analyzeContext()
    --> FimConstraints --> serializeToJson()
    --> constraint_spec.fim JSON --> sglang backend
    --> left/right-quotiented grammar masks per token
```

The Zig side does not allocate during analysis. It scans the prefix and suffix
character-by-character to extract the syntactic context that the backend needs
for quotienting.

### FimContext

The input to the analysis pipeline. Defined in `src/braid/fim.zig`:

```zig
pub const FimContext = struct {
    prefix: []const u8,          // code before the hole
    suffix: []const u8,          // code after the hole
    language: []const u8,        // source language
    hole_scale: HoleScale = .statement,
    file_path: ?[]const u8 = null,
    cursor_line: ?u32 = null,
    cursor_column: ?u32 = null,
};
```

### Prefix Analysis

`analyzePrefix` scans the prefix tracking:

| Field | Type | Meaning |
|-------|------|---------|
| `open_delimiters` | `u32` | Unmatched `(`, `[`, `{` at end of prefix |
| `ends_mid_expression` | `bool` | True if unclosed parens or brackets remain |
| `ends_in_string` | `bool` | Prefix ends inside a string literal |
| `ends_in_comment` | `bool` | Prefix ends inside a line comment |
| `indent_level` | `u32` | Character count of indentation on the last line |
| `indent_char` | `u8` | `' '` or `'\t'` |
| `indent_width` | `u32` | Indent characters per level (default 4) |

The scanner handles nested delimiters, escaped quotes, and `//`-style line
comments. It does not allocate -- all analysis is performed on the input slice.

### Suffix Analysis

`analyzeSuffix` examines the suffix to determine what the generated code must
produce:

| Field | Type | Meaning |
|-------|------|---------|
| `close_delimiters` | `u32` | Leading `)`, `]`, `}` after skipping whitespace |
| `starts_with` | `?[]const u8` | First meaningful token of the suffix |
| `requires_trailing_newline` | `bool` | True if suffix begins with `\n` |

### FimConstraints

The output of `analyzeContext`, combining both analyses:

```zig
pub const FimConstraints = struct {
    prefix: PrefixAnalysis,
    suffix: SuffixAnalysis,
    hole_scale: HoleScale,
    intensity: salience.IntensityLevel,
    requires_complete_unit: bool = true,
};
```

`requires_complete_unit` is `false` when the prefix ends inside a string or
comment. In those cases the infill is completing a literal, not a syntactic
unit, and the constraint engine adjusts accordingly.

## Hole Scale

Hole scale tells the constraint engine how much code to expect. Smaller holes
get tighter constraints because the surrounding context provides more signal.

| Scale | Default Intensity | What it means |
|-------|-------------------|---------------|
| `expression` | `syntax_only` | A single expression -- function argument, return value |
| `statement` | `standard` | One statement, the default |
| `block` | `standard` | A code block -- loop body, if-else branch, match arm |
| `function` | `full_hard` | An entire function body |
| `module` | `full` | Module-level generation, the loosest setting |

Intensity levels map to CLaSH constraint domains:

- `syntax_only` -- grammar conformance only
- `standard` -- Syntax + Types
- `full_hard` -- Syntax + Types + Imports (all hard constraint domains)
- `full` -- all 5 CLaSH domains (Syntax, Types, Imports, ControlFlow, Semantics)

The mapping is intentional: an expression-scale hole inside a function call
already has strong type context from the surrounding code, so syntax constraints
alone suffice. A function-scale hole needs type and import constraints to avoid
generating references to names that do not exist.

## CLI Usage

FIM mode requires both `--prefix` and `--suffix`. Hole scale defaults to
`statement` if not specified.

```bash
# Basic FIM -- generate code between prefix and suffix
ananke generate --fim \
    --prefix "fn add(" \
    --suffix ") -> i32 {" \
    --language zig

# Specify hole scale for tighter constraints
ananke generate --fim \
    --prefix "def process(data: List[str]) -> " \
    --suffix ":\n    for item in data:" \
    --language python \
    --hole-scale expression

# Full context with file path and cursor position
ananke generate --fim \
    --prefix "..." --suffix "..." \
    --language rust \
    --context src/lib.rs \
    --cursor-line 42 --cursor-column 8 \
    --backend sglang
```

All FIM CLI flags:

| Flag | Required | Description |
|------|----------|-------------|
| `--fim` | yes | Enable FIM mode |
| `--prefix <code>` | yes | Code before the hole |
| `--suffix <code>` | yes | Code after the hole |
| `--hole-scale <s>` | no | `expression`, `statement`, `block`, `function`, `module` |
| `--cursor-line <n>` | no | Cursor line in original file |
| `--cursor-column <n>` | no | Cursor column in original file |
| `--context <file>` | no | Source file for rich context extraction |
| `--language <lang>` | no | Target language (default: from config) |
| `--backend <name>` | no | `sglang` or `modal` |

## IDE Integration

FIM is the natural interface for editor plugins. The integration loop:

1. The editor captures text before and after the cursor position.
2. It sends both as `--prefix` and `--suffix` to Ananke (or calls the API
   directly with a `FimContext`).
3. Ananke analyzes the syntactic context: delimiter balance, indentation,
   whether the cursor is inside a string or comment, what token the suffix
   expects first.
4. The sglang backend receives the constraint spec and applies grammar
   quotienting at each decoding step.
5. The returned completion is guaranteed to:
   - Match the indentation of the surrounding code
   - Close any delimiters opened in the prefix
   - Not open delimiters that the suffix does not close
   - Maintain syntactic validity when `prefix + completion + suffix` are joined

The `serializeToJson` function produces JSON for the sglang `constraint_spec`
with these fields: `mode`, `language`, `hole_scale`, `intensity`,
`prefix_length`, `suffix_length`, `open_delimiters`, `close_delimiters`,
`indent_level`, `requires_complete_unit`, `ends_mid_expression`, `file_path`,
and `cursor_line`. The prefix and suffix content goes in the prompt, not the
constraint spec -- the spec carries only the structural analysis.

## A Concrete Example

Consider completing inside a TypeScript function:

```typescript
function validate(input: string): boolean {
    |                              // <-- cursor here
    return true;
}
```

Prefix: `"function validate(input: string): boolean {\n    "`
Suffix: `"\n    return true;\n}"`

Ananke's analysis:

- **Prefix**: 1 open delimiter (`{`), indent level 4, indent char space, not in
  string or comment
- **Suffix**: 0 leading close delimiters (the `}` is on a later line, after
  `return`), starts with `return`, requires trailing newline
- **Constraints**: `requires_complete_unit = true`, `hole_scale = statement`,
  `intensity = standard`

The left-quotient tells the backend: we are inside a function body, one brace
deep, at 4-space indentation. The right-quotient tells it: the generated code
must end in a state where `\n    return true;\n}` is a valid continuation. The
model cannot generate a `return` statement (the suffix already has one) or an
unmatched `{` (nothing in the suffix closes it at this depth).

## References

- `src/braid/fim.zig` -- FIM context analysis (12 tests)
- `src/cli/commands/generate.zig` -- CLI flags and backend dispatch
- `src/braid/salience.zig` -- IntensityLevel enum and CLaSH intensity mapping
- Ugare et al. 2024, "Constrained Decoding for Fill-in-the-Middle Code Generation"
- SPEC-05: Domain Fusion and Performance (FIM quotienting section)
