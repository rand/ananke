# Tutorial 6: Understanding CLaSH Constraint Domains

**Time**: 20 minutes
**Level**: Intermediate
**Prerequisites**: [Tutorial 1](01-extract-constraints.md) (constraint extraction), [Tutorial 2](02-compile-constraints.md) (compilation)
**You'll Learn**: The 5 CLaSH domains, hard vs soft tiers, cross-domain morphisms, adaptive intensity

---

## Overview

CLaSH (Coordinated Logical and Semantic Holes) is how Ananke decides which tokens a language model is allowed to generate and which tokens it should prefer. Five constraint domains, organized into two tiers, compose into a single per-token decision at decode time.

This tutorial walks through the five domains on a concrete Rust file, shows what happens when hard and soft constraints disagree, traces a cross-domain morphism, and demonstrates how intensity levels adapt to the scale of the hole being filled.

---

## Step 1: Extract Constraints from a Rust File

Save this as `payment.rs`:

```rust
use std::collections::HashMap;
use crate::models::User;

/// Processes a batch of payments, returning a summary per user.
/// Ensures all items are processed before returning.
pub async fn process_payments(
    data: Vec<String>,
    users: &HashMap<String, User>,
) -> Result<PaymentSummary, PaymentError> {
    let mut summary = PaymentSummary::new();

    for raw in &data {
        let parsed = parse_payment(raw)?;
        match users.get(&parsed.user_id) {
            Some(user) => summary.record(user, parsed.amount),
            None => return Err(PaymentError::UnknownUser(parsed.user_id.clone())),
        }
    }

    Ok(summary)
}
```

Extract constraints:

```bash
ananke extract payment.rs --output payment-constraints.json --verbose
```

The `--verbose` flag shows which CLaSH domain each constraint is tagged with. Ananke's Clew engine parses the AST via tree-sitter and classifies every extracted constraint into exactly one of the five domains.

---

## Step 2: Map Constraints to Domains

Here is what Clew finds in `payment.rs` and where each constraint lands:

| Extracted Constraint | Domain | Tier |
|---|---|---|
| Grammar rules for the function body (valid Rust statements) | **Syntax** | Hard |
| `fn process_payments(...) -> Result<PaymentSummary, PaymentError>` | **Types** | Hard |
| `use std::collections::HashMap` and `use crate::models::User` | **Imports** | Hard |
| `match ... { Some(user) => ..., None => return Err(...) }` | **ControlFlow** | Soft |
| Docstring: "Ensures all items are processed before returning" | **Semantics** | Soft |

Five domains, two tiers:

```
Syntax  x  Types  x  Imports  x  ControlFlow  x  Semantics
|________ Hard Tier ________|    |________ Soft Tier ________|
```

The three hard domains produce binary masks -- sets of token IDs that are allowed at each position. The two soft domains produce scores in [-1.0, 1.0] that nudge the model's preferences without vetoing anything.

---

## Step 3: Hard vs Soft -- The Difference That Matters

The tier distinction is the single most important design decision in CLaSH. Here is what it means in practice.

### Hard constraint rejects a token

Suppose the model wants to generate the identifier `TransactionLog` at a position inside `process_payments`. The Syntax domain allows it (valid identifier). The Types domain allows it (could be a compatible type). But the Imports domain rejects it -- `TransactionLog` is not in scope.

Result: `TransactionLog` is eliminated. The model cannot generate it. There is no appeal, no weighting, no probability adjustment. The token is removed from the feasible set before soft domains ever see it.

### Soft constraint scores a token low

Now suppose the model wants to generate `return Ok(summary)` without first iterating through `data`. The ControlFlow domain scores this continuation low -- it looks like an early return that skips the loop. The Semantics domain agrees, since the docstring says "all items" must be processed.

Result: `return` gets a negative logit adjustment. Its probability drops. But it remains in the feasible set. If the model's base logits for `return` are high enough, it can still be sampled. Soft constraints bias; they do not block.

### The calibration quote

This asymmetry is load-bearing:

> Hard constraints compose by intersection. If the syntax domain says a token is invalid, it does not matter how enthusiastically the semantics domain endorses it. Hard means hard.

And the converse is equally important: soft constraints can never cause generation failure. Adding a coding convention (soft) to a project cannot make a previously satisfiable constraint set unsatisfiable. This is enforced structurally in the implementation -- soft domain outputs are score vectors (`DomainScore`), not masks. The fusion layer applies them only to tokens that survive hard intersection.

---

## Step 4: Cross-Domain Morphisms in Action

Domains are not independent. Information propagates between them through monotonic morphisms -- functions that can tighten constraints, never loosen them.

### Types <-> Imports: the bidirectional morphism

Look at the return type in `payment.rs`:

```rust
) -> Result<PaymentSummary, PaymentError> {
```

The type `HashMap<String, User>` in the parameter list activates the Types <-> Imports morphism in both directions:

1. **Types -> Imports**: Using `HashMap<String, User>` means `HashMap` must be imported from `std::collections` and `User` must be imported from `crate::models`. The Types domain tells the Imports domain which symbols are required.

2. **Imports -> Types**: Conversely, the `use crate::models::User` import makes `User` available as a valid type. Without that import, the Types domain would not recognize `User` -- the Imports domain feeds back into Types to establish what type names are in scope.

This is the only bidirectional morphism pair in CLaSH. It converges fast because import resolution is deterministic: a type either is or is not importable. The fixpoint is typically reached in one or two iterations.

### Types -> ControlFlow: one-way morphism

The return type `Result<PaymentSummary, PaymentError>` triggers a one-way morphism into the ControlFlow domain. A `Result` return type implies the function body should contain error-handling patterns -- `match`, `?` operator, `unwrap_or`, and similar. The ControlFlow domain scores continuations that follow these patterns higher.

You can see this in the source. In `src/clew/extractors/base.zig`, the `deriveSemanticConstraints` function inspects function signatures and produces soft score expectations:

```zig
// Result types imply error handling obligation
if (std.mem.indexOf(u8, rt, "Result") != null or
    std.mem.indexOf(u8, rt, "!") != null)
{
    // ... emit soft constraint: "error_handling_required"
}
```

The output is tagged `"tier": "soft"`. Always. No morphism from a hard domain into another hard domain can cross tiers, and no morphism from a soft domain can tighten a hard mask. Soft -> Hard morphisms are structurally forbidden.

### Why morphisms terminate

Morphisms are monotonic over finite lattices. Monotonicity means tightening a source constraint can only tighten (never loosen) the target. Finite lattice height means there are bounded steps before fixpoint. Together, these guarantee convergence without cycle detection or iteration limits. The theoretical bound on the Types <-> Imports loop is `|type_refs| + |imports|` iterations, but in practice it converges in one or two.

---

## Step 5: Adaptive Intensity Levels

Not every generation needs every domain. Filling in a single expression does not warrant the same analysis as generating a new module. CLaSH defines intensity levels that control which domains are active.

### The levels

| Level | Active Domains | Per-Token Latency | When To Use |
|---|---|---|---|
| `SYNTAX_ONLY` | Syntax | ~50us | Small expression completions |
| `STANDARD` | Syntax + Types | ~200us | Statement or block fills |
| `FULL_HARD` | Syntax + Types + Imports | ~500us | Function-level generation |
| `FULL` | All 5 domains | ~2ms | Module-level or critical code |

These map directly to the `IntensityLevel` enum in `src/braid/salience.zig` and the `selectActiveDomains` function in `src/braid/domain_fusion.zig`. `STANDARD` activates exactly Syntax and Types -- not "syntax plus whatever fits in the budget."

### Hole scale drives intensity

The scale of the hole being filled maps naturally to intensity:

| Hole Scale | Intensity | Reasoning |
|---|---|---|
| `expression` | `SYNTAX_ONLY` | Grammar conformance is enough for a single expression |
| `statement` | `STANDARD` | Type checking catches mismatched returns |
| `block` | `STANDARD` | Same as statement -- types matter, imports usually stable |
| `function` | `FULL_HARD` | All hard domains -- imports may change at function scope |
| `module` | `FULL` | Everything -- new modules need full constraint coverage |

You can set this explicitly via `--hole-scale` on the CLI:

```bash
ananke generate --fim \
    --prefix "fn process(data: Vec<String>) -> " \
    --suffix "{ ... }" \
    --hole-scale function \
    --language rust
```

Or Ananke infers it from context. Expression holes get cheap, fast constraints. Module holes get the full treatment.

### Salience overrides

When Homer repository intelligence is available, salience analysis can override the default mapping. Code classified as `FoundationalStable` (high centrality, low churn) gets bumped to `FULL_HARD` even for smaller holes. Code classified as `QuietLeaf` (low centrality, low churn) stays at `SYNTAX_ONLY` unless it has tests, in which case it upgrades to `STANDARD`. The four-quadrant classification from Homer feeds directly into `adjustFromQuadrant` in `salience.zig`.

### Under latency pressure

If the per-token budget is tight, domains are shed in reverse priority order: Semantics first, then ControlFlow, then Imports. Syntax is the floor -- it is never shed. This means degradation is graceful: you lose soft guidance before you lose hard correctness, and you lose the most context-dependent hard domain (Imports) before you lose the most fundamental ones (Types, Syntax).

---

## What You've Learned

1. **Five domains, two tiers**: Syntax, Types, and Imports form the hard tier (binary masks, compose by intersection). ControlFlow and Semantics form the soft tier (graded scores, compose by weighted addition).

2. **Hard means hard**: A token blocked by any hard domain cannot be generated. Soft constraints bias but never block.

3. **Morphisms propagate information**: Types and Imports inform each other bidirectionally. Types inform ControlFlow and Semantics one-way. Soft domains never tighten hard masks.

4. **Intensity adapts**: Hole scale, salience classification, and latency budget together determine which domains are active for a given generation.

---

## Further Reading

- [CLASH_ALGEBRA.md](../CLASH_ALGEBRA.md) -- the full algebraic specification: lattice structure, composition semantics, termination proofs
- [DOMAIN_FUSION.md](../DOMAIN_FUSION.md) -- implementation details of the per-token fusion pipeline, relaxation cascade, ASAp distribution preservation
- [Tutorial 7](07-fim-mode.md) -- FIM (fill-in-the-middle) mode, where hole scale and intensity interact with prefix/suffix context

---

**Previous**: [Tutorial 5: Integration](05-integration.md)
**Next**: [Tutorial 7: FIM Mode](07-fim-mode.md)
