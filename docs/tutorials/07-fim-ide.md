# Tutorial 7: Fill-in-the-Middle for IDE Completions

**Time**: 15 minutes
**Level**: Intermediate
**Prerequisites**: Tutorial 1 (constraint extraction)
**You'll Learn**: Standard vs FIM completion, constraint-aware FIM, HoleScale, IDE integration

---

## Step 1: Standard Completion vs FIM Completion

Standard completion sees everything before the cursor and generates forward. It
has no idea what comes after. FIM (fill-in-the-middle) sees both the **prefix**
(before the cursor) and the **suffix** (after it), generating text to bridge the
gap. This is the mode your editor uses when you trigger autocomplete mid-file.

Without constraints, FIM can generate code that:

- Breaks syntax when joined with the suffix (double-closed braces)
- Introduces delimiter mismatches the suffix never closes
- Uses variables not in scope at the cursor position
- Returns the wrong type for what follows

These are the normal failure mode of unconstrained infill. Model probabilities
do not encode the invariant that `prefix + generated + suffix` must parse.
Ananke fixes this by quotienting the grammar -- only tokens that maintain
validity across both join points are allowed at each decoding step.

---

## Step 2: Basic FIM via CLI

The `--fim` flag switches `ananke generate` into fill-in-the-middle mode.
It requires both `--prefix` and `--suffix`.

```bash
# Simple expression-level fill
ananke generate --fim \
    --prefix "let total = items.map(x => x." \
    --suffix ").reduce((a, b) => a + b, 0);" \
    --language typescript
```

The model sees `x.` before the cursor and `).reduce(...)` after it. The
constraint ensures the generated property or method produces valid syntax when
the closing `)` and `.reduce(` chain are appended.

```bash
# Statement-level fill
ananke generate --fim \
    --prefix "def validate(email: str) -> bool:\n    " \
    --suffix "\n    return is_valid" \
    --language python \
    --hole-scale statement
```

Here the model fills one or more statements inside a function body. The
`--hole-scale statement` tells Ananke to apply standard-intensity constraints --
syntax plus types -- which is the default when you omit `--hole-scale`.

**Key rule:** `--fim` always requires both `--prefix` and `--suffix`. If you
only have a prefix, you want standard (non-FIM) generation. If you have an empty
suffix, pass `--suffix ""` -- Ananke degrades gracefully to left-quotient only.

---

## Step 3: Constraint-Aware FIM with Type Context

Raw prefix and suffix strings are enough for syntactic constraints. Ananke can
do more when you point it at the source file.

```bash
# FIM with full context from source file
ananke generate --fim \
    --prefix "fn process(data: &[u8]) -> Result<" \
    --suffix ", ParseError> {\n    let parsed = parse(data)?;" \
    --language rust \
    --context src/parser.rs \
    --cursor-line 42 --cursor-column 38 \
    --backend sglang
```

With `--context`, Ananke reads the source file and extracts rich context via
Clew: type bindings, import information, function signatures, and control flow
constraints. All of this feeds into the five CLaSH domains. The `constraint_spec`
sent to sglang carries both the FIM analysis (delimiter counts, indentation,
syntactic state) and the rich context. Hard domains mask invalid tokens; soft
domains adjust probabilities.

The `--cursor-line` and `--cursor-column` flags are optional but improve scope
resolution -- they tell Clew exactly where the hole is, so it resolves which
bindings are visible at that point.

---

## Step 4: HoleScale Variations

The `--hole-scale` flag controls how aggressively Ananke constrains the
generation. Smaller holes get tighter constraints, because there is less
ambiguity about what should go there.

| Scale | Example Use Case | Default Intensity |
|-------|-----------------|-------------------|
| `expression` | Single value: `x.` followed by a property or method | `syntax_only` |
| `statement` | One statement in a function body | `standard` |
| `block` | An if-else body, loop body, match arm | `standard` |
| `function` | An entire function implementation | `full_hard` |
| `module` | Top-level module content | `full` |

The intensity levels correspond to active CLaSH domains:

- **`syntax_only`**: Grammar only (~50us/token). Nearly instant.
- **`standard`**: Syntax + Types (~200us). The IDE sweet spot.
- **`full_hard`**: Syntax + Types + Imports (~500us). All hard-tier domains.
- **`full`**: All five domains (~2ms). Includes soft-tier ControlFlow and Semantics.

Smaller holes = tighter constraints = more predictable infill.

```bash
# Expression: fast, tight
ananke generate --fim \
    --prefix "const area = Math." \
    --suffix " * radius * radius;" \
    --language javascript \
    --hole-scale expression

# Function: thorough, slower
ananke generate --fim \
    --prefix "impl Parser {\n    fn parse_expression(&mut self) -> Result<Expr, Error> {\n" \
    --suffix "\n    }\n}" \
    --language rust \
    --hole-scale function \
    --context src/parser.rs \
    --backend sglang
```

---

## Step 5: How FIM Analysis Works

When you pass `--fim`, Ananke runs a lightweight, zero-allocation analysis
before sending anything to the backend:

1. **`analyzePrefix`**: Scans the prefix tracking open delimiters (unmatched
   `(`, `[`, `{`), string/comment state, and indentation on the last line.

2. **`analyzeSuffix`**: Counts leading close delimiters after whitespace,
   identifies the first token, checks whether the infill needs a trailing
   newline.

3. **Left-quotient**: The sglang backend parses the prefix to determine parser
   state at the cursor. Generated code must be a valid continuation from that
   state -- not from the grammar's start symbol.

4. **Right-quotient**: The suffix constrains where generated code must lead.
   Only tokens that leave the parser able to accept the suffix are allowed.

5. **Intersection**: Both quotient grammars are intersected per token. This is a
   formal guarantee that `prefix + generated + suffix` parses -- not a heuristic.

**Graceful degradation.** If right-quotient fails, fall back to left-only. If
left-quotient fails, fall back to standard syntax. The system never blocks on a
failed analysis.

The results are serialized via `serializeToJson()` and sent as the `fim` field
inside the `constraint_spec` payload to sglang. The backend does the expensive
quotienting; the CLI does the cheap context extraction.

---

## Step 6: IDE Integration Path

The editor captures everything before and after the cursor and sends them to
Ananke. The completion it gets back is guaranteed to:

- Match indentation of surrounding code
- Close any delimiters opened in the prefix
- Not open delimiters the suffix does not close
- Maintain syntactic validity when the three pieces are joined

A minimal integration:

```
Editor cursor event
  --> split buffer at cursor into (prefix, suffix)
  --> POST to Ananke with --fim --prefix ... --suffix ...
  --> receive completion text
  --> insert at cursor position
```

The `serializeToJson()` function produces the full `constraint_spec` -- delimiter
counts, indentation, hole scale, intensity, cursor position, file path -- so the
backend has everything it needs in a single request. For richer completions, the
editor sends `--context` pointing at the current file plus `--cursor-line` and
`--cursor-column`, adding type and import constraints on top of the syntactic
guarantee.

---

## What's Next

- **[FIM_GUIDE.md](../FIM_GUIDE.md)** -- The full technical reference for FIM
  constrained decoding, including the grammar quotienting algorithm, the
  `FimContext` and `FimConstraints` structs, and backend integration details.
- **[CLASH_ALGEBRA.md](../CLASH_ALGEBRA.md)** -- How the five constraint
  domains compose, how hard and soft tiers interact, and why adaptive intensity
  matters for FIM.
- **[Tutorial 6: CLaSH Domains](06-clash-domains.md)** -- Hands-on exploration
  of the constraint domains that FIM leverages.

FIM is most useful for **expression and statement-level completions**, where the
surrounding context is rich and the hole is small enough for tight constraints to
be decisive. For larger holes (function or module scale), the constraints still
help, but the model has more room to maneuver -- and more ways to be right.
