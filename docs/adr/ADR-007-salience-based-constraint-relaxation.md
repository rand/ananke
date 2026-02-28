# ADR-007: Salience-Based Constraint Relaxation

## Status
Proposed

## Context
When the full constraint set is unsatisfiable, Braid must relax some constraints to restore feasibility. Today this relaxation is arbitrary: constraints are dropped in lowest-priority-first order, but all priorities are equal, so the relaxation order is effectively random. This means a constraint on a critical public API function is as likely to be relaxed as a constraint on a private helper, leading to inconsistent generation quality.

The problem is deciding which constraints matter most. Manual priority assignment does not scale -- developers would need to annotate every constraint source, and priorities would go stale as the codebase evolves. What is needed is an empirical signal that reflects the actual importance hierarchy of the repository.

Homer's composite salience scoring provides exactly this signal. It combines structural, behavioral, and social metrics into a single score per entity:
- PageRank (30%): structural importance in the dependency graph.
- Betweenness centrality (15%): gateway role between modules.
- HITS authority/hub (15%): whether the entity is widely depended-on or widely-depending.
- Code churn (15%): how frequently the entity changes.
- Bus factor risk (10%): how concentrated authorship knowledge is.
- Code size (5%): complexity proxy.
- Test presence (10%): whether the entity has test coverage.

## Decision
Use Homer's composite salience scoring to weight constraint priority. When Braid must relax constraints to restore satisfiability, it relaxes constraints on low-salience entities first and preserves constraints on high-salience entities.

Homer's four-quadrant classification maps to constraint intensity levels:

| | High Churn | Low Churn |
|---|---|---|
| **High Centrality** | ActiveHotspot: FULL intensity | FoundationalStable: FULL_HARD intensity, high confidence |
| **Low Centrality** | PeripheralActive: STANDARD intensity | QuietLeaf: SYNTAX_ONLY intensity |

**FoundationalStable** is the critical category: load-bearing code that has not changed in months. Behavioral analysis (churn-only) misses it entirely because it has no recent activity. Graph centrality catches it because its structural importance is visible regardless of temporal activity.

Implementation in `src/braid/salience.zig`:
1. Query Homer for salience scores of entities referenced by constraints.
2. Map salience scores to constraint priority adjustments.
3. During feasibility resolution, relax lowest-salience constraints first.
4. Use community-aware feasibility (`src/braid/feasibility.zig`): if a constraint would force importing across community boundaries where coupling is historically low, flag as architectural tension and prefer relaxing the import constraint over the type constraint.

## Consequences

**Positive:**
- Constraint relaxation aligns with the repository's actual importance hierarchy. Public API contracts on high-centrality entities are preserved; private helpers in peripheral modules are relaxed first.
- FoundationalStable entities (high centrality, low churn) receive appropriate protection. These are the entities most likely to cause widespread breakage if their constraints are violated, yet they are invisible to churn-based heuristics.
- No manual annotation required. Salience scores are computed from repository structure and history, evolving automatically as the codebase changes.
- Community-aware feasibility catches architectural violations: generating code that imports across module boundaries where coupling is historically absent is flagged rather than silently allowed.

**Negative:**
- Homer dependency: salience-based relaxation is only available when Homer is running. Without Homer, fallback is equal-weight relaxation (current behavior).
- Salience scoring reflects the repository's past, not its future. A newly created module that will become critical has zero salience initially.
- Composite score weights (30% PageRank, 15% betweenness, etc.) are design choices that may not be optimal for all repositories. Different codebases might benefit from different weightings.
- Louvain community detection is non-deterministic. Community boundaries can shift between runs, leading to inconsistent feasibility decisions. Mitigated by caching community assignments per session and using them as soft guidance, not hard constraints.

## Alternatives Considered

**Manual priority assignment:** Developers annotate constraint sources with explicit priorities (e.g., `@constraint(priority=HIGH)`). Rejected because it does not scale -- priorities must be maintained across the entire codebase and go stale as code evolves. Also places burden on developers to understand the constraint system's internals.

**Equal-weight relaxation:** When constraints must be relaxed, drop them in arbitrary order (current behavior). Rejected because it treats all code as equally important, violating the empirical reality that some entities are structurally critical and others are peripheral.

**LLM-based constraint negotiation:** When constraints conflict, ask the LLM to decide which to relax based on its understanding of the code. Rejected because: (a) it adds inference cost to what should be a fast constraint-resolution step; (b) the LLM's judgment about code importance is less reliable than graph-structural signals; (c) it creates a circular dependency where the constraint system depends on the system it is constraining.

## References
- Zimmermann & Nagappan, "Predicting Defects using Network Analysis on Dependency Graphs," ICSE 2008 -- graph centrality predicts change propagation scope
- Homer composite salience scoring documentation
- Louvain community detection (Blondel et al., 2008)
- Integration plan Phase 4B: Salience-Informed Constraint Priority
- Integration plan: Adaptive Intensity section
