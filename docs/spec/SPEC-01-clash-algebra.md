# SPEC-01: CLaSH Constraint Algebra

## Rationale

CLaSH (Coordinated Logical and Semantic Holes) is the algebraic foundation for constraint-shaped code synthesis. It defines five constraint domains in two tiers, their composition properties, cross-domain information flow, and compilation targets. This algebra is shared with the RFLX architecture (io-rflx) -- the same lattice structure governs both constraint extraction (Ananke) and constraint enforcement (ananke-sglang). All downstream specs depend on these definitions.

---

## [SPEC-01.01] Five Constraint Domains in Two Tiers

The constraint space over a generation context Gamma is the product of five domains partitioned into two tiers:

```
Omega(Gamma) = Syntax(Gamma) x Types(Gamma) x Imports(Gamma) x ControlFlow(Gamma) x Semantics(Gamma)
               |____________ Hard Tier _____________|   |____________ Soft Tier ______________|
```

**Hard Tier** (binary pass/fail -- invalid tokens are structurally impossible):

- **Syntax**: Grammar conformance of the partial program. Compiled to Earley parser state (via llguidance/derivre) or PDA (via XGrammar). The token mask is exact: every allowed token leads to a grammatically valid continuation.
- **Types**: Well-typedness of the partial program at the hole position. Compiled to prefix automata (per PLDI 2025). Ensures generated expressions inhabit the expected type.
- **Imports**: Symbol availability. Only identifiers reachable through the scope graph (local file or cross-file via Homer) are valid. Compiled to vocabulary subset masks.

**Soft Tier** (graded scores in [0.0, 1.0] -- guide sampling, never block):

- **ControlFlow**: Pattern conformance. Error handling conventions, async/await structure, loop patterns. Scores candidate continuations against repository conventions.
- **Semantics**: Behavioral intent. Preconditions, postconditions, invariants derived from docstrings, assertions, and test files. Scored via learned surrogates or lightweight verification.

**Acceptance criteria**: The implementation must represent exactly five domains. Hard domains produce binary masks (token is valid or not). Soft domains produce floating-point scores. No sixth domain may be added without revising this spec.

---

## [SPEC-01.02] Bounded Meet-Semilattice Properties

Each domain D forms a bounded meet-semilattice (D, meet, top, bottom) where:

- **top** = unconstrained (all tokens allowed / score 1.0 for all)
- **bottom** = unsatisfiable (no tokens allowed / score 0.0 for all)
- **meet** = constraint conjunction (tighten)

The meet operation satisfies:

1. **Commutativity**: `meet(a, b) = meet(b, a)` -- constraint order does not matter.
2. **Associativity**: `meet(a, meet(b, c)) = meet(meet(a, b), c)` -- grouping does not matter.
3. **Idempotency**: `meet(a, a) = a` -- applying the same constraint twice is a no-op.
4. **Bottom propagation**: `meet(a, bottom) = bottom` -- any unsatisfiable constraint poisons the entire domain.

For hard domains, meet is set intersection of allowed token sets. For soft domains, meet is pointwise minimum of scores.

The product lattice Omega inherits these properties component-wise. The overall constraint set is unsatisfiable if and only if at least one hard domain reaches bottom. Soft domain bottoms reduce score to zero but do not block generation.

**Acceptance criteria**: Braid's constraint composition must be verified against all four properties. A unit test must demonstrate that composing constraints in any order produces identical results (commutativity + associativity). An unsatisfiable hard constraint must propagate to overall failure. An unsatisfiable soft constraint must not.

---

## [SPEC-01.03] Cross-Domain Morphisms

Information propagates between domains through monotonic morphisms (functions that can only tighten constraints, never loosen them):

**Hard <-> Hard (bidirectional)**:

- **Types <-> Imports**: Using a type `HashMap<K,V>` implies `import std::collections::HashMap` (or language equivalent). Conversely, importing a module makes its exported types available for type checking.

**Hard -> Soft (one-way)**:

- **Types -> ControlFlow**: A return type of `Result<T,E>` implies an error handling pattern (match/unwrap/? operator). This is a soft expectation, not a hard requirement.
- **Types -> Semantics**: A function signature `fn sort(v: &mut Vec<T>) where T: Ord` implies an ordering postcondition. The semantics domain scores continuations that establish ordering guarantees higher.
- **Imports -> Semantics**: `import logging` implies log calls should appear in the function body. The semantics domain scores continuations containing log statements higher.

Morphisms are monotonic: if constraint `a` is tighter than `a'` in the source domain, then `morphism(a)` is at least as tight as `morphism(a')` in the target domain.

**Acceptance criteria**: Each morphism must be implemented as a named function in Braid with explicit source and target domains. Morphism composition must be tested: applying Types->Imports then Imports->Semantics must produce the same result as applying Types->Semantics directly (where both paths exist). Morphisms must be monotonic -- a test must verify that tightening a source constraint never loosens the target.

---

## [SPEC-01.04] Soft-to-Hard Propagation Prohibition

**Architectural invariant**: Soft -> Hard propagation is structurally forbidden. No morphism, no code path, no configuration may cause a soft constraint to restrict the hard feasible set.

This guarantees: adding or modifying soft constraints (ControlFlow, Semantics) can never make a previously satisfiable constraint set unsatisfiable. Generation may become lower-quality (soft scores drop) but never impossible.

The prohibition is enforced structurally, not by convention:

- Soft domain outputs are score vectors, not masks.
- The fusion layer ([SPEC-05.02]) applies soft scores only within the feasible set defined by hard domains.
- No API accepts a soft constraint in a hard domain slot.

**Acceptance criteria**: A compile-time or type-level enforcement must prevent soft constraint values from appearing in hard mask computation. An integration test must demonstrate that setting all soft constraints to bottom (score 0.0 everywhere) does not reduce the set of tokens allowed by hard domains.

---

## [SPEC-01.05] Constraint Compilation Targets

The same constraint compiles to different representations depending on the generation backend:

| Target | Produced By | Consumed By | When |
|--------|-------------|-------------|------|
| Token masks (bitmask over vocabulary) | All hard domains | All backends | Always -- the universal constraint interface |
| Prefix automata (DFA/NFA states) | Types domain | Type-constrained decoding | STANDARD+ intensity (PLDI 2025) |
| GBNF/EBNF grammars | Syntax domain | llguidance, XGrammar | Syntax-constrained decoding |
| Regex patterns | Imports domain (identifier names) | Vocabulary filtering | Fast scope-limited name completion |
| Verification predicates | Soft domains | Post-generation validation | Generate-then-verify workflows |

Future targets (not in current scope):

- Energy functions for diffusion/EBM backends
- Attention bias matrices for graph-augmented generation (NeurIPS 2025)

Each domain must implement a `compile(target: CompilationTarget) -> CompiledConstraint` method. Unsupported target/domain combinations return `top` (unconstrained) rather than failing.

**Acceptance criteria**: Each hard domain must produce a token mask. Syntax domain must additionally produce GBNF. Types domain must additionally produce prefix automata state. Imports domain must additionally produce regex patterns. Unsupported combinations must return top, verified by test.

---

## [SPEC-01.06] Adaptive Intensity Levels

Not every generation activates every domain. Intensity adapts to the generation context:

| Level | Active Domains | Latency Budget | Activation Trigger |
|-------|---------------|----------------|-------------------|
| `NONE` | -- | 0 | Unconstrained fallback, error recovery |
| `SYNTAX_ONLY` | Syntax | ~50us/token | Simple token completion, QuietLeaf code |
| `STANDARD` | Syntax + Types | ~200us/token | Function body generation, PeripheralActive code |
| `FULL_HARD` | Syntax + Types + Imports | ~500us/token | New file generation, FoundationalStable code |
| `FULL` | All 5 domains | ~2ms/token | High-stakes generation, ActiveHotspot code |
| `EXHAUSTIVE` | All 5 + verification hooks | ~5ms/token | CI/batch pipelines, formal verification contexts |

Intensity is selected based on:

1. **Hole scale**: expression < statement < block < function < module (larger holes warrant more domains).
2. **Salience**: Homer's four-quadrant classification maps to intensity levels ([SPEC-04.03]).
3. **User override**: `--intensity` flag or per-project `.ananke.toml` setting.
4. **Latency budget**: If per-token constraint time exceeds the budget, Braid must shed domains in reverse priority order (Semantics first, then ControlFlow, then Imports).

**Acceptance criteria**: Each intensity level must activate exactly the domains listed. Domain shedding under latency pressure must follow the specified order. The system must expose the active intensity level in its output metadata. A user override must take precedence over automatic selection.

---

## References

- CLaSH algebra: RFLX architecture (io-rflx), rflx-clash module
- Grammar-Aligned Decoding (ASAp): NeurIPS 2024 -- distribution-preserving constraint composition
- Type-Constrained Code Generation: PLDI 2025 (ETH Zurich) -- prefix automata for well-typedness
- SMC for Constraint Composition: ICLR 2025 Oral -- multiplicative constraint factors
- llguidance: Microsoft/OpenAI (May 2025) -- derivre + Earley, ~50us/token
- CRANE: ICML 2025 -- adaptive constraint switching for reasoning vs. structured output
