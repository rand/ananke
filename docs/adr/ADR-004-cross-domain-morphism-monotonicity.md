# ADR-004: Cross-Domain Morphism Monotonicity

## Status
Proposed

## Context
The CLaSH algebra's five constraint domains are not independent. Information must propagate between them: a `Result<T,E>` return type (Types domain) implies an error handling pattern (ControlFlow domain); an `import logging` statement (Imports domain) implies log calls in the function body (Semantics domain); a `HashMap<K,V>` type binding (Types domain) requires `import std::collections::HashMap` (Imports domain).

Without propagation rules, each domain operates in isolation, missing these cross-domain implications. With unconstrained propagation, there is a risk of constraint explosion (unbounded growth) or satisfiability violations (soft preferences breaking hard constraints).

Rules are needed for:
1. **Direction**: Which domains can propagate to which.
2. **Safety**: Propagation must never make a satisfiable constraint set unsatisfiable.
3. **Termination**: Propagation must converge in bounded steps.

## Decision
Morphisms are **monotonic** (can only tighten constraints, never loosen) and **directional** (follow a fixed topology):

**Hard <-> Hard (bidirectional):**
- Types <-> Imports: `HashMap<K,V>` implies `import std::collections::HashMap`. Conversely, `import X` makes X available for type checking.

**Hard -> Soft (one-way):**
- Types -> ControlFlow: `Result<T,E>` implies error handling pattern (scored, not required).
- Types -> Semantics: `fn sort(v: &mut Vec<T>) where T: Ord` implies ordering postcondition (scored).
- Imports -> Semantics: `import logging` implies log calls in function body (scored).

**Soft -> Hard (structurally forbidden):**
No soft domain constraint may propagate to tighten a hard domain constraint. A coding convention (ControlFlow) or behavioral expectation (Semantics) cannot restrict the set of syntactically valid, well-typed, or importable tokens.

**Termination guarantee:** Morphisms are bounded by domain lattice height. Each domain's constraint set forms a finite lattice. Monotonic tightening can only move up the lattice, so propagation converges in at most `sum(lattice_heights)` steps.

## Consequences

**Positive:**
- Structural guarantee: adding soft constraints (conventions, semantic preferences) can never break satisfiability of the hard constraint set. This is a direct consequence of forbidding Soft -> Hard propagation.
- Termination is guaranteed by monotonicity + finite lattice height, without needing cycle detection or iteration limits.
- The propagation topology is simple and auditable: 2 bidirectional edges among hard domains, 3 one-way edges from hard to soft. No complex dependency graphs.
- Each morphism is independently testable: given input constraints in the source domain, verify the output constraints in the target domain.

**Negative:**
- One-way Hard -> Soft means that strong soft-domain signals (e.g., "this function MUST handle errors") cannot promote themselves to hard constraints. If a user wants hard error-handling enforcement, they must express it as a type constraint (e.g., `Result<T,E>` return type), not as a ControlFlow pattern.
- Bidirectional Hard <-> Hard morphisms (Types <-> Imports) require careful implementation to avoid oscillation. In practice, convergence is fast because import resolution is deterministic: a type either is or is not importable.
- The fixed topology may not capture all useful propagation paths. For example, ControlFlow -> Semantics propagation (loop structure implies iteration semantics) is not modeled. Adding new morphism edges requires updating this ADR.

## Alternatives Considered

**Bidirectional all domains:** Allow any domain to propagate to any other. Rejected because bidirectional Soft <-> Hard propagation breaks the structural guarantee -- a soft convention could tighten the hard feasible set, causing generation failure. Additionally, unconstrained bidirectional propagation risks oscillation and makes termination analysis difficult.

**No propagation (independent domains):** Each domain operates in complete isolation. Rejected because it misses valuable cross-domain information: a `Result<T,E>` type should inform ControlFlow about error handling expectations; an import should inform the type checker about available symbols. Independent domains produce weaker constraints and miss obvious implications.

## References
- CLaSH algebra formalization (RFLX)
- Lattice-theoretic foundations for abstract interpretation (Cousot & Cousot, 1977) -- monotonic operators on finite lattices converge
- Integration plan: Cross-Domain Morphisms section
- Integration plan Phase 3: Control Flow + Semantic Constraints
