# ADR-002: Hard/Soft Constraint Tier Separation

## Status
Proposed

## Context
The CLaSH algebra defines five constraint domains (Syntax, Types, Imports, ControlFlow, Semantics) that shape code generation at the token level. These domains can conflict -- a naming convention (soft) might prefer an identifier that violates the grammar (hard), or a semantic expectation might require a construct that is not well-typed. A principled resolution strategy is needed to compose multi-domain constraints without causing generation failure or silently dropping important constraints.

The core challenge is structural: if any constraint can block token generation, then adding more constraints (even well-intentioned ones like coding conventions) can make the constraint set unsatisfiable, causing the generator to produce no output or degenerate output.

## Decision
Adopt a two-tier architecture:

**Hard Tier** (binary pass/fail -- invalid tokens are impossible):
1. **Syntax**: Grammar conformance via Earley parser state (llguidance) or PDA (XGrammar). Token mask is exact.
2. **Types**: Well-typedness of partial program via prefix automata (PLDI 2025). Ensures generated expressions inhabit expected types.
3. **Imports**: Symbol availability via scope graph. Only names reachable through the scope graph are valid identifiers. Compiled to vocabulary subset masks.

Hard constraints compose by exact intersection: `valid_tokens = syntax_mask AND type_mask AND import_mask`. A token violating any hard domain IS invalid.

**Soft Tier** (graded 0.0-1.0 -- guide sampling, never block):
4. **ControlFlow**: Pattern conformance (error handling, async/await, loop structure). Scores candidate continuations.
5. **Semantics**: Behavioral intent (pre/postconditions, invariants, docstring-derived expectations). Scores via learned surrogates or SMT.

Soft constraints compose by additive logit reweighting within the feasible set: `logits[t] = base_logits[t] + alpha * controlflow_score[t] + beta * semantic_score[t]` for all t in valid_tokens.

**Architectural invariant**: Soft constraints NEVER cause generation failure. They reweight the distribution within the feasible set defined by hard constraints.

## Consequences

**Positive:**
- Structural guarantee that adding soft constraints (conventions, semantic preferences) can never make a previously satisfiable constraint set unsatisfiable.
- Clear composition semantics: hard domains use exact boolean intersection, soft domains use weighted reweighting.
- Preserves the LLM's conditional distribution shape within the feasible set (Grammar-Aligned Decoding insight).
- Soft domain noise is bounded: worst case is wasted generation quality, never generation failure.
- Enables independent development of hard and soft domain implementations.

**Negative:**
- Some constraints that "should" be hard (e.g., error handling in safety-critical code) are structurally soft. Users cannot promote a soft constraint to hard without changing its domain classification.
- Soft constraint weights (alpha, beta) require tuning or calibration.
- The tier boundary is a design choice, not derived from first principles -- reasonable people might disagree on which domains are hard vs soft.

## Alternatives Considered

**Single tier with priority ordering:** All constraints are hard, with a priority that determines relaxation order when unsatisfiable. Rejected because this does not provide the structural guarantee -- any constraint can block generation, and the interaction between priorities and satisfiability is complex. A "low priority" hard constraint on control flow could still cause generation failure in combination with other constraints.

**Probabilistic weighting for all domains:** All constraints are soft with different weights. Rejected because syntax and type constraints are genuinely binary -- a token either produces valid syntax or it does not. Making these soft would allow syntactically invalid code with low probability, defeating the purpose of constrained decoding.

## References
- CLaSH algebra formalization (RFLX)
- Grammar-Aligned Decoding (ASAp), NeurIPS 2024 -- shows naive mask intersection distorts LLM distributions
- CRANE: Adaptive Constraint Switching, ICML 2025 -- shows strict constraints during reasoning degrades quality by up to 10pp
- Type-Constrained Code Generation, PLDI 2025 (ETH Zurich) -- prefix automata for type domain
- Integration plan: The CLaSH Architecture section
