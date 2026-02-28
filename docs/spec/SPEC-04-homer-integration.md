# SPEC-04: Homer Repository Intelligence

## Rationale

Clew extracts constraints from the current file. Homer provides the repository-wide context that makes constraints repository-aware: which names are in scope across files, which code is structurally important, how stable entities are over time, and what conventions the codebase follows. This spec defines how Homer's analyses (scope graphs, salience, temporal, conventions) integrate into the constraint pipeline. All Homer data is optional -- the system degrades gracefully without it.

---

## [SPEC-04.01] Scope-Graph-Informed Name Resolution

Homer provides path-stitching scope graphs for 13 languages that resolve name bindings across files, including push/pop nodes for context-sensitive resolution.

**ScopeContext struct**:

```zig
pub const ScopeContext = struct {
    bindings: []ScopeBinding,
    enclosing_scope: ?[]const u8,
    resolution_depth: u32,
};

pub const ScopeBinding = struct {
    name: []const u8,
    type_expr: ?[]const u8,
    resolution_path: []const u8,   // e.g., "models/__init__.py -> models/user.py"
    source_file: []const u8,
    kind: BindingKind,              // function, type, variable, module
    is_reexport: bool,
};

pub const BindingKind = enum { function, type_decl, variable, module, constant };
```

When generating code at a hole position, Ananke queries Homer for all names reachable through the scope graph at that position. This includes:

- Direct imports from the current file
- Transitive re-exports through package `__init__` files or barrel exports
- Wildcard imports (expanded to concrete names)
- Implicit scope (builtins, prelude, globals)

The `resolution_path` field captures how the binding is reached, enabling ImportDomain to generate the import statement the codebase actually uses (e.g., `from models import User` rather than `from models.user import User` if the codebase re-exports through `__init__`).

ScopeBindings are serialized to `scope_bindings_json` in RichContext ([SPEC-03.02]) and become `scope_bindings` in ConstraintSpec ([SPEC-02.01]).

**Acceptance criteria**: A query for a hole in a Python file that imports from a package must return bindings for all names reachable through that package's scope graph, including re-exports. Resolution paths must match the codebase's actual import conventions. Bindings must be deduplicated by (name, type_expr) -- multiple resolution paths to the same binding are collapsed, keeping the shortest path.

---

## [SPEC-04.02] Salience-Informed Constraint Priority

Homer computes a composite salience score for each code entity (function, type, module) using a weighted combination:

| Component | Weight | What It Measures |
|-----------|--------|-----------------|
| PageRank | 30% | Structural importance in the dependency graph |
| Betweenness centrality | 15% | Gateway role between subsystems |
| HITS authority/hub | 15% | Whether the entity is widely depended upon (authority) or depends on many (hub) |
| Code churn | 15% | Frequency of modification (high churn = actively evolving) |
| Bus factor risk | 10% | Concentration of authorship (low bus factor = single-author risk) |
| Code size | 5% | Lines of code (proxy for complexity) |
| Test presence | 10% | Whether the entity has associated tests |

Salience scores are normalized to [0.0, 1.0] within a repository.

**Constraint priority mapping**: When Braid must relax constraints due to unsatisfiability ([SPEC-01.02] bottom propagation), it relaxes constraints on low-salience entities first:

- Salience >= 0.8: constraints are never auto-relaxed (require explicit `allow_relaxation`)
- Salience 0.5-0.8: constraints are relaxed after all lower-salience constraints
- Salience 0.2-0.5: constraints are relaxed early
- Salience < 0.2: constraints are relaxed first

This ensures that structurally important, well-tested, single-author code retains strict constraints while peripheral utilities are relaxed.

**Acceptance criteria**: Given an unsatisfiable constraint set, Braid must relax constraints in ascending salience order. A test must demonstrate that a high-salience type constraint is preserved while a low-salience import constraint is relaxed to achieve satisfiability. Salience scores must be queryable from Braid's constraint metadata.

---

## [SPEC-04.03] Four-Quadrant Classification

Homer classifies code entities into four quadrants based on centrality and churn:

| | High Churn | Low Churn |
|---|---|---|
| **High Centrality** | ActiveHotspot | FoundationalStable |
| **Low Centrality** | PeripheralActive | QuietLeaf |

Each quadrant maps to a default constraint intensity level ([SPEC-01.06]):

- **ActiveHotspot** (high centrality, high churn): `FULL` intensity. Load-bearing code under active development -- apply all domains, expect conventions to be evolving.
- **FoundationalStable** (high centrality, low churn): `FULL_HARD` intensity, high confidence. Load-bearing code that rarely changes -- strict hard constraints, high confidence in type and import constraints. This is the critical quadrant: behavioral analysis (churn-only) misses these; graph centrality catches them.
- **PeripheralActive** (low centrality, high churn): `STANDARD` intensity. Actively changing but structurally unimportant -- types matter, full constraint suite is overkill.
- **QuietLeaf** (low centrality, low churn): `SYNTAX_ONLY` intensity. Private helpers, utilities, dead code candidates -- minimal constraint overhead.

The quadrant classification is a recommendation, not a mandate. User-specified `--intensity` overrides it ([SPEC-01.06]). The quadrant is included in generation metadata for observability.

**Acceptance criteria**: Each entity must be classifiable into exactly one quadrant. The quadrant must determine the default intensity level as specified. A user override must take precedence. The classification thresholds for "high" vs "low" centrality and churn must be configurable in `.ananke.toml` with sensible defaults (centrality: median, churn: median of non-zero values).

---

## [SPEC-04.04] Temporal Confidence

Homer's temporal analysis classifies entity stability and provides confidence levels for constraints:

| Classification | Centrality | Churn | Constraint Confidence |
|---------------|-----------|-------|----------------------|
| StableCore | High | Low | **High** -- strict constraints, low `allow_relaxation` likelihood |
| ActiveCore | High | High | **Medium** -- constraints apply but `allow_relaxation: true` because the entity is evolving |
| StableLeaf | Low | Low | **Medium** -- standard constraints, stable but not critical |
| ActiveLeaf | Low | High | **Low** -- prefer grammar/regex constraints over type constraints; the entity is volatile and peripheral |

Confidence levels affect constraint behavior:

- **High confidence**: hard constraints enforced strictly. Soft constraints weighted at full strength.
- **Medium confidence**: hard constraints enforced. Soft constraints weighted at 0.7x.
- **Low confidence**: hard constraints enforced with `allow_relaxation: true`. Soft constraints weighted at 0.3x.

Confidence is per-entity, not per-domain. A high-confidence entity has high-confidence constraints across all domains; a low-confidence entity has relaxed constraints across all domains.

Centrality trends over time (Homer's time-windowed analysis) detect drift: an entity whose centrality is increasing gets its confidence bumped up one level. An entity whose centrality is decreasing gets its confidence bumped down.

**Acceptance criteria**: Each referenced entity in the generation context must have a temporal classification. Confidence must modulate soft constraint weights as specified. Centrality trend detection must use at least 3 time windows (e.g., 30/90/180 days). An entity with increasing centrality must not be classified as StableLeaf.

---

## [SPEC-04.05] Community-Aware Feasibility

Homer's Louvain community detection partitions the codebase into cohesive modules. This informs constraint feasibility analysis in Braid.

**Cross-community coupling tension**: When a constraint would force importing across community boundaries where historical coupling is low, Braid flags this as architectural tension:

```zig
pub const FeasibilityResult = struct {
    satisfiable: bool,
    tension: ?ArchitecturalTension,
};

pub const ArchitecturalTension = struct {
    source_community: []const u8,
    target_community: []const u8,
    historical_coupling: f32,   // Jaccard similarity of co-changes
    constraint_source: []const u8,
    recommendation: TensionAction,
};

pub const TensionAction = enum {
    relax_import,    // prefer relaxing the import constraint
    relax_type,      // prefer relaxing the type constraint (rare)
    warn_only,       // coupling is low but not zero; proceed with warning
};
```

When tension is detected, Braid prefers relaxing the import constraint over the type constraint. Rationale: importing across community boundaries is an architectural decision that should be made by a human, not silently enforced by a constraint system.

Louvain community assignments are non-deterministic. Braid caches assignments per session (single `ananke generate` invocation) to ensure consistent behavior within a generation. Community data is always used as soft guidance, never hard constraint.

**Acceptance criteria**: A constraint requiring an import from a different community with < 0.1 historical coupling must flag tension. The tension recommendation must prefer relaxing the import constraint. Community assignments must be cached per session -- two calls within the same `ananke generate` invocation must use identical community assignments. Absent Homer data must produce `satisfiable: true, tension: null`.

---

## [SPEC-04.06] Convention Mining to Soft Constraints

Homer's convention analysis extracts empirically observed patterns from the codebase. These compile to soft-tier constraints:

| Convention Type | Source | Target Domain | Constraint Form |
|----------------|--------|---------------|----------------|
| Naming conventions | Identifier patterns (`snake_case`, `camelCase`, prefix conventions) | Syntax (enrichment) | Regex patterns on identifier tokens |
| Import ordering | Observed import group ordering (stdlib, third-party, local) | Imports | Ordering rules on import blocks |
| Error handling patterns | Predominant error handling style per language/module | ControlFlow | Soft pattern matching |
| Documentation style | Docstring format (Google, NumPy, reST) | Semantics | Docstring template constraints |

All convention-derived constraints are soft-tier. They guide generation toward repository-consistent code but never block tokens that violate conventions.

Convention constraints have the lowest priority among soft constraints -- explicitly extracted semantic constraints ([SPEC-03.04]) and morphism-derived constraints ([SPEC-03.05]) take precedence.

**Acceptance criteria**: Naming conventions must compile to regex patterns that the Syntax domain can apply during identifier generation. A repository using `snake_case` exclusively must produce a regex that penalizes `camelCase` identifiers (soft penalty, not hard block). Convention constraints must be tagged with their source convention for debugging. Empty convention data (no Homer, or Homer has insufficient data) must produce no convention constraints, not default constraints.

---

## [SPEC-04.07] Homer Communication Protocols

### Phase 4a: MCP Queries

In the initial integration, Ananke CLI queries Homer through its MCP tool interface:

| MCP Tool | Used For | Expected Latency |
|----------|----------|-----------------|
| `homer_graph` | Scope graph bindings, call graph edges, community membership | ~100ms |
| `homer_risk` | Salience scores, bus factor, churn metrics | ~50ms |
| `homer_co_changes` | Co-change partners, Jaccard similarity | ~50ms |
| `homer_conventions` | Naming patterns, import ordering, error handling style | ~100ms |

MCP queries happen once per generation request (not per token). For a 100-token generation taking ~1 second on GPU, Homer overhead is < 5% of total latency.

All MCP queries are optional. If Homer is unavailable (MCP connection fails, timeout), the pipeline continues without repository context. A warning is emitted but generation proceeds.

### Phase 4b: Rust FFI (Future)

If profiling shows MCP latency is a bottleneck (unlikely given inference dominates), `homer-core` and `homer-graphs` can be linked as library crates into Maze:

- Eliminates MCP serialization overhead
- Enables per-token scope graph queries (needed for streaming type checking)
- Requires `homer-core` to expose a stable Rust API

Phase 4b is deferred until profiling data justifies it. The abstraction layer between Ananke and Homer must support both MCP and FFI backends without changing the constraint pipeline.

**Acceptance criteria**: Phase 4a: all four MCP queries must complete within 500ms total. MCP failures must not prevent generation. Phase 4b: the Homer abstraction must be backend-agnostic -- switching from MCP to FFI must not require changes outside `src/clew/scope_context.zig` and `src/braid/salience.zig`.

---

## [SPEC-04.08] Co-Change-Aware Context

Homer's co-change analysis (Jaccard similarity of commit histories) identifies files that historically change together. This informs context inclusion:

When generating code in file A, if file B has Jaccard similarity > 0.3 with A, file B's current exports are included in the scope context. This provides preemptive context: the generated code is more likely to be correct with respect to its co-change partners.

Co-change partners are ranked by Jaccard similarity and included in the generation context up to the context budget. They slot into the context hierarchy ([SPEC-03.06]) at priority level 4 (test files) if they are test files, or priority level 5 (similar code) otherwise.

The co-change threshold (default 0.3) is configurable in `.ananke.toml`:

```toml
[homer]
co_change_threshold = 0.3
max_co_change_partners = 5
```

**Acceptance criteria**: Files with Jaccard similarity above the threshold must be included in scope context. Co-change partners must be ranked by similarity (highest first). The maximum number of partners must be respected. A file with no co-change partners (new file, or Homer unavailable) must not cause errors.

---

## References

- Homer scope graphs: path-stitching resolution across 13 languages
- Homer salience: composite scoring from graph metrics + behavioral metrics
- Homer temporal analysis: time-windowed centrality trends, stability classification
- Homer conventions: empirical pattern extraction from codebase
- Louvain community detection: modularity-based graph clustering
- InlineCoder (January 2026): call graph context inlining
- Homer MCP tools: `homer_graph`, `homer_risk`, `homer_co_changes`, `homer_conventions`
