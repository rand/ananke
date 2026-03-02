# CLaSH Constraint Algebra

CLaSH -- Constraint Lattice for Shaped Holefilling -- is the algebraic foundation for composing multiple constraint sources into per-token generation decisions. It defines five constraint domains in two tiers, their composition semantics, cross-domain information flow, and adaptive intensity selection. The algebra is shared between Ananke (constraint extraction and compilation) and the sglang backend (constraint enforcement at decode time). If a constraint exists in Ananke, it exists in CLaSH. If it shapes a token probability, CLaSH defines how.

---

## The Five Domains

The constraint space over a generation context Gamma is the product of five domains, partitioned into two tiers:

```
Omega(Gamma) = Syntax(Gamma) x Types(Gamma) x Imports(Gamma) x ControlFlow(Gamma) x Semantics(Gamma)
               |____________ Hard Tier _____________|   |____________ Soft Tier ______________|
```

| Domain | Tier | Compilation Target | What It Catches | Latency Budget |
|--------|------|--------------------|-----------------|----------------|
| Syntax | Hard | Earley parser / PDA (llguidance/derivre) or PDA (XGrammar) | Grammar violations | ~50us |
| Types | Hard | Prefix automata (PLDI 2025 approach) | Type errors at the hole position | ~100-200us |
| Imports | Hard | Vocabulary subset mask | References to unavailable symbols | ~10us |
| ControlFlow | Soft | Logit adjustments | Error handling, async/await, loop patterns | ~50us |
| Semantics | Soft | Logit adjustments | Pre/postconditions, invariants from docs/assertions | ~100us |

In the implementation (`domain_fusion.zig`), the `Domain` enum has exactly five variants: `.syntax`, `.types`, `.imports`, `.control_flow`, `.semantics`. The `DomainTier` enum has exactly two: `.hard`, `.soft`. Each domain knows its tier:

```zig
pub fn tier(self: Domain) DomainTier {
    return switch (self) {
        .syntax, .types, .imports => .hard,
        .control_flow, .semantics => .soft,
    };
}
```

No sixth domain may be added without revising SPEC-01.

---

## Hard vs Soft: The Two Tiers

The tier distinction is the single most important architectural decision in CLaSH (see ADR-002).

**Hard tier**: Binary pass/fail. A token either passes ALL hard domains or it cannot be generated. Hard domains produce bitmasks over the vocabulary. They compose by intersection -- the feasible set is the set of tokens valid in every hard domain simultaneously. The `intersectHardMasks` function in `domain_fusion.zig` implements this as a sorted merge-intersect (O(n+m) per pair). If the intersection is empty, the system signals that relaxation is needed (`required_relaxation = true` on the `FusionResult`).

**Soft tier**: Graded scores in [0.0, 1.0]. Soft domains never block tokens; they adjust probabilities within the feasible set via additive logit reweighting. The formula:

```
adjustment[i] = SUM_d(weight_d * score_d[i] / temperature)
```

This preserves the LLM's conditional distribution shape within the feasible set (the ASAp insight from NeurIPS 2024) while biasing toward convention and semantic conformance. Weights and temperature are configurable per-domain through `FusionConfig`.

This is the key architectural invariant: **soft constraints never cause generation failure**. Adding a soft constraint cannot make a satisfiable constraint set unsatisfiable. The worst case for soft domain noise is wasted generation quality, never generation impossibility.

Hard constraints compose by intersection. If the syntax domain says a token is invalid, it does not matter how enthusiastically the semantics domain endorses it. Hard means hard.

The invariant is enforced structurally, not by convention. Soft domain outputs are score vectors (`DomainScore`), not masks. The fusion layer applies soft scores only to tokens that survive hard intersection. No API accepts a soft constraint in a hard domain slot -- the types are different.

---

## The Lattice Structure

Each domain D forms a bounded meet-semilattice (D, meet, top, bottom):

- **Top** (top): Unconstrained. All tokens are allowed (hard) or score 1.0 (soft).
- **Bottom** (bot): Unsatisfiable. No tokens are allowed (hard) or score 0.0 for all (soft).
- **Meet** (meet): Constraint conjunction. Applying two constraints produces a constraint at least as tight as either input.

For hard domains, meet is set intersection of allowed token sets. For soft domains, meet is pointwise minimum of scores.

The meet operation satisfies four properties:

1. **Commutativity**: `a meet b = b meet a`. The order in which constraints are applied does not matter. In the implementation, `intersectHardMasks` processes masks sequentially, but the sorted merge-intersect of sorted sets is commutative -- `{1,3,5} intersect {3,5,9}` produces the same `{3,5}` regardless of order.

2. **Associativity**: `(a meet b) meet c = a meet (b meet c)`. Grouping does not matter. This holds because set intersection is associative.

3. **Idempotency**: `a meet a = a`. Applying the same constraint twice is harmless. Intersecting a set with itself produces the same set.

4. **Bottom propagation**: `a meet bot = bot`. If any hard domain reaches bottom (empty mask), the entire hard feasible set is empty.

The product lattice Omega inherits these properties component-wise. The overall constraint set is unsatisfiable if and only if at least one hard domain reaches bottom.

For soft domains, bottom means zero score everywhere -- but this is benign. A soft domain at bottom contributes zero logit adjustments. The feasible set (defined by hard domains) is unaffected. Tokens still get generated; they just lose the guidance that soft domain would have provided.

---

## Cross-Domain Morphisms

Domains are not independent. Information propagates between them through monotonic morphisms: functions that can only tighten constraints, never loosen them. The directionality is fixed.

### Morphism topology

**Bidirectional (Hard <-> Hard)**:
- **Types <-> Imports**: Using a type `HashMap<K,V>` implies `import std::collections::HashMap` (or the language equivalent). Conversely, importing a module makes its exported types available for type checking. This is the only bidirectional pair.

**One-way (Hard -> Soft)**:
- **Types -> ControlFlow**: A return type of `Result<T,E>` implies an error handling pattern (match/unwrap/? operator). This is a soft expectation -- the ControlFlow domain scores continuations that follow the expected pattern higher, but does not reject those that don't.
- **Types -> Semantics**: A function signature `fn sort(v: &mut Vec<T>) where T: Ord` implies an ordering postcondition. The Semantics domain scores continuations that establish ordering guarantees higher.
- **Imports -> Semantics**: `import logging` implies log calls should appear in the function body. The Semantics domain scores continuations containing log statements higher.

**Structurally forbidden (Soft -> Hard)**:
No morphism, no code path, no configuration may cause a soft constraint to restrict the hard feasible set. This is the load-bearing consequence of ADR-002 and SPEC-01.04: if soft constraints could tighten hard masks, then adding a coding convention could make a previously satisfiable constraint set unsatisfiable. The prohibition preserves the structural guarantee.

The implementation in `base.zig` demonstrates this in practice. The `deriveSemanticConstraints` function implements the Types -> Semantics morphism: it inspects function signatures and produces semantic score expectations. The output is a score vector, never a mask.

### Termination

Morphisms are monotonic over finite lattices. Monotonicity means tightening a source constraint can only tighten (never loosen) the target. Finite lattice height means there are bounded steps before fixpoint. Together, these guarantee convergence without cycle detection or iteration limits.

For the bidirectional Types <-> Imports morphism, convergence is fast in practice because import resolution is deterministic: a type either is or is not importable. The fixpoint is typically reached in one or two iterations. The theoretical bound is `|type_refs| + |imports|` iterations.

Morphism-generated constraints are tagged with their source morphism and carry strictly lower priority than explicitly extracted constraints. This means that if a human or an extractor says "this import is needed," that takes precedence over a morphism-inferred import.

---

## Adaptive Intensity

Not every generation needs every domain. A one-line expression completion does not warrant the same analysis as generating a new module. CLaSH defines six intensity levels that control which domains are active.

### Intensity levels

| Level | Active Domains | Count | Latency Budget |
|-------|---------------|-------|----------------|
| `NONE` | -- | 0 | 0us |
| `SYNTAX_ONLY` | Syntax | 1 | ~50us/token |
| `STANDARD` | Syntax + Types | 2 | ~200us/token |
| `FULL_HARD` | Syntax + Types + Imports | 3 | ~500us/token |
| `FULL` | All 5 domains | 5 | ~2ms/token |
| `EXHAUSTIVE` | All 5 + verification hooks | 5 | ~5ms/token |

These are defined by the `IntensityLevel` enum in `salience.zig` and the `selectActiveDomains` function in `domain_fusion.zig`. The mapping is explicit -- `STANDARD` activates exactly `.syntax` and `.types`, not "syntax plus whatever else fits in the budget."

### Selection criteria

Intensity is selected based on four inputs, in priority order:

1. **User override**: Always wins. The `--intensity` flag or per-project `.ananke.toml` setting directly sets the level.

2. **Homer four-quadrant salience**: The `SalienceScore` in `salience.zig` classifies code entities by centrality and churn:
   - **FoundationalStable** (high centrality, low churn) -> `FULL_HARD`. Load-bearing, stable code. Get the types and imports right.
   - **ActiveHotspot** (high centrality, high churn) -> `FULL`. Frequently modified core code. Bring all domains to bear, but with a confidence penalty (0.8x multiplier) because high-churn code may change again.
   - **PeripheralActive** (low centrality, high churn) -> `STANDARD`. Peripheral code in flux. Syntax and types are sufficient.
   - **QuietLeaf** (low centrality, low churn) -> `SYNTAX_ONLY`. Stable leaf code. Grammar conformance is enough (upgraded to `STANDARD` if the entity has tests).

3. **Hole scale**: Larger holes warrant more domains. Expression-level holes get `SYNTAX_ONLY`. Statement/block-level get `STANDARD`. Function-level get `FULL_HARD`. Module-level get `FULL`.

4. **Latency budget**: Under pressure, domains are shed in reverse priority order: Semantics first, then ControlFlow, then Imports. Syntax is the floor -- it is never shed. The `latencyBudgetUs` method on `IntensityLevel` returns the per-token budget for each level.

### CRANE-style adaptive switching

During generation, constraint intensity adapts to the phase of output (per CRANE, ICML 2025). The `GenerationPhase` enum in `domain_fusion.zig` defines three phases:

- **Reasoning**: Chain-of-thought, planning, `<thinking>` tags. Constraints relax to syntax-only regardless of configured intensity. This prevents constraint interference with the LLM's reasoning -- CRANE showed that strict constraints during reasoning degrades quality by up to 10 percentage points.
- **Structured output**: Code fences, JSON, formal content. Full configured intensity applies.
- **Transition**: Phase boundary markers (e.g., triple-backtick). Treated as structured output.

The implementation is in `selectActiveDomains`:

```zig
if (adaptive and phase == .reasoning) {
    return .{ .syntax = intensity != .none };
}
```

If the configured intensity is `NONE`, reasoning gets zero domains. Otherwise, reasoning always gets exactly syntax. The conservative default: when the phase is uncertain, classify as structured output and apply full intensity.

---

## Worked Example

Consider generating a Python function body:

```python
def process_payment(amount: float, user: User) -> PaymentResult:
    # cursor is here, generating the body
```

At `FULL` intensity, all five domains are active. Walk through several token positions.

### Token position: first token of the body

The model's top candidates (by raw logit) might be: `if`, `result`, `payment`, `return`, `try`, `for`, `amount`.

**Syntax domain** (hard mask): Produces a mask of tokens that are valid as the first token of a function body statement. Allows `if`, `result`, `payment`, `return`, `try`, `for`, `amount`, `raise`, `with`, `while`, etc. Rejects tokens like `)`, `]`, `+`, `,` -- these cannot start a statement.

**Types domain** (hard mask): The return type is `PaymentResult`. At the first token, many paths can eventually return a `PaymentResult`, so the type mask is broad. Most statement-starting tokens are allowed. But bare literals like `42` or `"hello"` that could only produce `int` or `str` are excluded if no path from them leads to `PaymentResult`.

**Imports domain** (hard mask): `User` and `PaymentResult` are available (in scope). If the model tries to generate `TransactionLog` and that name is not imported, the imports mask blocks it. At the first token position, this mainly constrains identifier tokens.

**Hard intersection**: `feasible_tokens = syntax_mask AND type_mask AND import_mask`. Suppose the intersection yields: `{if, result, try, return, amount, payment, user, raise, with}`. The token `TransactionLog` was in the syntax and type masks but not the import mask -- eliminated.

**ControlFlow domain** (soft score): The function has no explicit error handling yet, and `PaymentResult` suggests a result-type pattern. The ControlFlow domain scores `try` at 0.8 (implies error handling), `if` at 0.5 (neutral), `return` at 0.2 (early return without logic is suspicious). These are the Types -> ControlFlow morphism at work: the `PaymentResult` return type created a soft expectation for error-handling patterns.

**Semantics domain** (soft score): Processing a payment implies validation before execution. The Semantics domain scores `if` at 0.7 (likely a validation check), `amount` at 0.6 (checking the input), `try` at 0.5.

**Fusion**: Logit adjustments are computed for each feasible token:

```
adjustment[try]    = 1.0 * 0.8 + 1.0 * 0.5 = 1.3
adjustment[if]     = 1.0 * 0.5 + 1.0 * 0.7 = 1.2
adjustment[amount] = 1.0 * 0.3 + 1.0 * 0.6 = 0.9
adjustment[return] = 1.0 * 0.2 + 1.0 * 0.1 = 0.3
...
```

These adjustments are added to the base logits (within the feasible set only), then the distribution is renormalized. The model's own preference is preserved but tilted toward `try` and `if` -- tokens that align with both control flow conventions and semantic expectations.

### What happens when hard domains disagree

Suppose at a later position the model wants to generate the identifier `validate_card`. The syntax domain allows it (valid identifier token). The types domain allows it (a function call can return something compatible). But the imports domain rejects it -- `validate_card` is not in scope.

Hard intersection eliminates `validate_card`. There is no negotiation. The syntax and types domains may have been enthusiastic, but the imports domain said no, and `syntax AND types AND imports = {}` for that token. The model must choose a different continuation.

If instead only the ControlFlow domain (soft) had objected -- say, disliking the naming convention -- `validate_card` would remain in the feasible set. Its logit would be adjusted downward, but it could still be sampled. This is the tier separation in action: hard constraints define what is possible, soft constraints define what is preferred.

### Phase transition

If the model enters a `<thinking>` tag to plan its approach before generating code, CRANE-style adaptive switching activates. Only the syntax domain remains active (ensuring the thinking-tag syntax is valid). The types, imports, ControlFlow, and Semantics domains are suspended. The model reasons freely without constraint interference. When it exits the thinking tag and begins emitting code, all five domains reactivate.

---

## Summary of Guarantees

1. **Satisfiability preservation**: Adding or modifying soft constraints cannot make a satisfiable constraint set unsatisfiable.
2. **Order independence**: Constraints compose identically regardless of application order (commutativity + associativity).
3. **Monotonic convergence**: Cross-domain propagation terminates in bounded steps without cycle detection.
4. **Graceful degradation**: Under latency pressure, domains shed in a defined order. Syntax is always the floor.
5. **Phase awareness**: Constraints adapt to reasoning vs. structured output, preventing quality degradation during chain-of-thought.

---

## References

- **SPEC-01**: CLaSH Constraint Algebra specification (`docs/spec/SPEC-01-clash-algebra.md`)
- **ADR-002**: Hard/Soft Constraint Tier Separation (`docs/adr/ADR-002-hard-soft-constraint-tiers.md`)
- **ADR-004**: Cross-Domain Morphism Monotonicity (`docs/adr/ADR-004-cross-domain-morphism-monotonicity.md`)
- **Source**: `src/braid/domain_fusion.zig` -- fusion strategy, hard mask intersection, soft score application, CRANE switching
- **Source**: `src/braid/salience.zig` -- intensity levels, salience classification, four-quadrant mapping
- **Source**: `src/clew/extractors/base.zig` -- morphism implementation (Types -> Semantics)
- **Source**: `src/braid/feasibility.zig` -- constraint feasibility analysis, community-aware relaxation
- ASAp (NeurIPS 2024) -- distribution-preserving constrained decoding
- Type-Constrained Code Generation (PLDI 2025, ETH Zurich) -- prefix automata for well-typedness
- CRANE (ICML 2025) -- adaptive constraint switching for reasoning vs. structured output
- Cousot & Cousot (1977) -- monotonic operators on finite lattices converge
