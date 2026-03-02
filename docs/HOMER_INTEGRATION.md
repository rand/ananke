# Homer Repository Intelligence in Ananke

Ananke generates constrained code completions. Clew extracts constraints from the
current file's AST. Homer provides the rest: cross-file name resolution, structural
importance scoring, temporal stability analysis, convention mining, and call graph
context. Together they let Ananke enforce constraints that no single-file analysis
could derive.

All Homer data is optional. Without it, Ananke constrains against the local AST and
falls back to `standard` intensity. With it, the Imports and Types CLaSH domains gain
cross-file bindings, salience drives constraint intensity up or down, temporal signals
modulate confidence, and mined conventions enter as soft-tier biases. The system never
fails when Homer is absent -- it just knows less.

Homer exposes four MCP tools: `homer_graph` (~100ms), `homer_risk` (~50ms),
`homer_co_changes` (~50ms), `homer_conventions` (~100ms). Each is queried once per
generation request, not per token. Total Homer overhead is under 5% of inference time.
See [ADR-003](adr/ADR-003-homer-mcp-communication.md) for why MCP, not Rust FFI.


## Scope Context

**Source**: `src/clew/scope_context.zig` (11 tests)
**Spec**: [SPEC-04.01](spec/SPEC-04-homer-integration.md)
**ADR**: [ADR-006](adr/ADR-006-scope-graph-resolution-from-homer.md)

Homer's path-stitching scope graphs resolve name bindings across file boundaries.
Clew sees the current file. Homer sees the repository. Scope context bridges the two.

The core data types:

**ScopeBinding** -- a name reachable at the generation hole through cross-file
resolution:

| Field | Type | Purpose |
|-------|------|---------|
| `name` | `[]const u8` | The binding name (`"HashMap"`, `"User"`) |
| `qualified_type` | `?[]const u8` | Fully-qualified type, if known (`"std::collections::HashMap<K,V>"`) |
| `kind` | `BindingKind` | One of: `type_definition`, `function`, `variable`, `module`, `type_alias` |
| `definition_file` | `?[]const u8` | Source file where the binding is defined |
| `definition_line` | `?u32` | Line number of the definition |
| `is_reexport` | `bool` | Whether the binding is accessible through multiple import paths |

**CanonicalImport** -- the import statement the codebase actually uses (not what is
theoretically available):

| Field | Type | Purpose |
|-------|------|---------|
| `module_path` | `[]const u8` | Module path (`"models.user"`, `"std::collections"`) |
| `items` | `[]const []const u8` | Specific imported names (`["User", "UserRole"]`) |
| `is_wildcard` | `bool` | Wildcard import (`from models import *`) |

**EnclosingScope** -- the scope surrounding the generation hole:

| Field | Type | Purpose |
|-------|------|---------|
| `name` | `[]const u8` | Scope name (`"UserService"`, `"process_request"`) |
| `kind` | `ScopeKind` | One of: `function`, `method`, `class`, `module`, `block` |
| `file` | `[]const u8` | File containing the scope |

These compose into a **ScopeContext**: bindings + enclosing scope + canonical imports
+ language tag.

Key functions:

- `serializeBindingsJson()` -- JSON array for `ConstraintSpec.type_bindings`
- `serializeImportsJson()` -- JSON array for `ConstraintSpec.imports`
- `filterTypeBindings()` -- filters to `type_definition` and `type_alias` entries only
- `canActivateCrossFileTypeChecking()` -- returns true when at least one type binding
  carries a non-null `qualified_type`. This is the gate for the PLDI 2025 prefix
  automata approach to cross-file type checking: without a qualified type, there is
  nothing to build automata from.

Design principle: data-in, JSON-out. This module never queries Homer. The CLI/MCP
layer fetches scope graph data from Homer, constructs `ScopeContext`, and scope_context
serializes it for downstream consumption. The boundary is deliberate -- it keeps Clew
testable without a running Homer instance.


## Call Graph Context

**Source**: `src/clew/call_graph_context.zig` (7 tests)

InlineCoder (January 2026) demonstrated that upstream callers and downstream callees
around a generation hole improve completion quality by 49% on the RepoExec benchmark.
Ananke adopts this approach via Homer's call graph.

**Caller** -- how the hole's function is invoked:

| Field | Type | Purpose |
|-------|------|---------|
| `name` | `[]const u8` | Calling function name |
| `file` | `?[]const u8` | Caller's source file |
| `call_line` | `?u32` | Line number of the call site |
| `arguments` | `?[]const u8` | Arguments at the call site (`"user.id, options"`) |
| `result_usage` | `?[]const u8` | How the return value is consumed (`"const result = "`, `"if ("`) |

**Callee** -- what the hole's function depends on:

| Field | Type | Purpose |
|-------|------|---------|
| `name` | `[]const u8` | Called function name |
| `file` | `?[]const u8` | Callee's source file |
| `params` | `?[]const u8` | Parameter signature |
| `return_type` | `?[]const u8` | Return type |
| `is_async` | `bool` | Whether the callee is async |

**CallGraphContext** holds callers, callees, a target function/file, and a depth
(always 1 -- direct calls only).

Three query methods matter:

- `edgeCount()` -- total callers + callees. Used for budget checks.
- `hasUpstreamContext()` -- `callers.len > 0`. Per InlineCoder's findings, upstream
  context has the highest impact on completion quality. When this returns false, the
  call graph context provides diminished value.
- `hasDownstreamTypeContext()` -- true when any callee has `return_type` or `params`
  set. This gates whether callee type information is worth including in the prompt.

Context budget: up to 3 upstream callers (most recent) and 5 downstream callees
(direct only). Total call graph context is capped at 30% of the prompt token budget.
The rationale: callers show usage patterns and expected return types; callees show
available APIs and their signatures. Beyond these limits, additional context adds noise
faster than signal.


## Salience Scoring

**Source**: `src/braid/salience.zig` (10 tests)
**ADR**: [ADR-007](adr/ADR-007-salience-based-constraint-relaxation.md)

Homer computes a composite salience score per code entity. Ananke maps this to
constraint intensity and confidence.

**SalienceScore** fields: `composite` (f32), `pagerank`, `betweenness`, `churn_rate`,
`bus_factor`, `has_tests`.

Composite weights:

| Component | Weight |
|-----------|--------|
| PageRank | 30% |
| Betweenness centrality | 15% |
| HITS | 15% |
| Churn rate | 15% |
| Bus factor | 10% |
| Code size | 5% |
| Test presence | 10% |

### Four-Quadrant Classification

The `classify()` method on `SalienceScore` partitions entities into four quadrants
along two axes: centrality (composite >= 0.5) and churn (churn_rate >= 0.5).

| Quadrant | Centrality | Churn | Intensity | Confidence | Relaxation |
|----------|-----------|-------|-----------|------------|------------|
| `foundational_stable` | High | Low | `full_hard` | 1.0 | Never |
| `active_hotspot` | High | High | `full` | 0.8 | Never |
| `peripheral_active` | Low | High | `standard` | 0.6 | Allowed |
| `quiet_leaf` | Low | Low | `syntax_only`* | 0.7 | Allowed |

*`quiet_leaf` promotes to `standard` if `has_tests` is true.

`foundational_stable` is the critical quadrant. These are high-centrality, low-churn
entities -- the load-bearing walls of a codebase. Churn-based heuristics miss them
entirely because they rarely change. Only graph centrality catches them. They get the
strictest constraints and no relaxation, ever. If Ananke generates code that touches a
foundational-stable entity, every applicable hard constraint fires.

### Intensity Levels

`IntensityLevel` defines six tiers with associated per-token latency budgets:

| Level | Budget | Active Domains |
|-------|--------|----------------|
| `none` | 0 us | None |
| `syntax_only` | 50 us | Syntax |
| `standard` | 200 us | Syntax + Types |
| `full_hard` | 500 us | Syntax + Types + Imports |
| `full` | 2000 us | All 5 domains |
| `exhaustive` | 5000 us | All 5 domains + verification hooks |

`selectIntensity()` examines all salience scores for entities referenced by a
generation hole. If any entity is `foundational_stable`, intensity is at least
`full_hard` regardless of others. Otherwise, intensity scales with the maximum
composite score. A user override bypasses all of this.


## Temporal Analysis

**Source**: `src/braid/temporal.zig` (7 tests)

Homer's temporal signals answer the question: how much should we trust constraints
derived from this entity?

**StabilityClass** mirrors the salience quadrants but from a temporal perspective:
`stable_core`, `active_core`, `stable_leaf`, `active_leaf`. The `fromSalience()`
method derives stability from a `SalienceScore` using the same centrality/churn axes.

**TemporalAnalysis** adds time-series data:

| Field | Type | Purpose |
|-------|------|---------|
| `stability` | `StabilityClass` | Base classification |
| `days_since_modified` | `u32` | Recency |
| `recent_change_count` | `u32` | Changes in the last 90 days |
| `centrality_trend` | `f32` | -1.0 (declining) to +1.0 (increasing) |
| `co_change_partners` | `[]CoChangePartner` | Files that change together |

**CoChangePartner**: `path`, `jaccard_similarity` (f32), `co_change_count`.

### Confidence Multipliers

Base multipliers by stability class:

| Class | Base Multiplier | Loose Constraints | Relaxation |
|-------|----------------|-------------------|------------|
| `stable_core` | 1.0 | No | Never |
| `active_core` | 0.75 | No | Allowed |
| `stable_leaf` | 0.8 | No | Never |
| `active_leaf` | 0.5 | Yes | Allowed |

Additional modifiers applied on top of the base:

- Declining centrality trend (< -0.3): multiply by 0.9. The entity is losing
  structural importance; constraints derived from it are less trustworthy.
- Increasing centrality trend (> +0.3): multiply by 1.1, capped at 1.0. The entity
  is gaining importance; trust its constraints more.
- Recently modified (< 7 days, at least 1 change): multiply by 1.05, capped at 1.0.
  The developer is actively thinking about this code.

These stack multiplicatively. A `stable_core` entity with declining centrality gets
1.0 * 0.9 = 0.9. An `active_core` entity with increasing centrality and recent
modifications gets 0.75 * 1.1 * 1.05 = 0.866, capped at 1.0 -- so 0.866.

**Co-change partners** with Jaccard similarity >= 0.5 are collected as context
partners. Their exports get included in the scope context for the generation hole.
The logic: if files A and B always change together, generating code in A should see
B's current exports. This is not a heuristic -- it is an empirical signal from commit
history.

`shouldPreferTypeConstraints()` returns false only for `active_leaf`. Everything else
is stable enough or important enough that type constraints add value. Active leaves are
the most volatile and least reliable -- grammar and regex constraints are more
appropriate.


## Convention Mining

**Source**: `src/clew/conventions.zig` (5 tests)

Homer mines coding conventions empirically from repository history. Ananke converts
them to soft-tier CLaSH constraints -- never hard. This is a structural invariant
enforced at both the code level (the `toSoftConstraints()` function always sets
`domain` to a soft-tier domain) and the serialization level (`serializeToJson()`
hardcodes `"tier": "soft"`).

The reasoning: conventions are statistical observations about how a codebase is
written. They should bias generation toward consistency, not block it. A naming
convention observed in 80% of functions is a strong hint, not a law.

**ConventionKind** and their constraint mappings:

| Convention | Target Domain | Weight Formula | Rationale |
|-----------|--------------|---------------|-----------|
| `naming` | `syntax_guidance` | confidence * 0.7 | Suggestive, not critical |
| `import_ordering` | `syntax_guidance` | confidence * 0.5 | Cosmetic |
| `error_handling` | `control_flow` | confidence * 0.8 | Highest -- error patterns affect correctness |
| `documentation` | `semantics` | confidence * 0.4 | Lowest -- style, not substance |
| `code_organization` | `semantics` | confidence * 0.6 | Moderate -- structural preference |

Conventions with confidence below 0.6 are filtered out entirely. At that threshold,
fewer than 60% of instances in the codebase follow the pattern -- hardly a convention.

A convention with 0.9 confidence for error handling produces a soft constraint with
weight 0.72 (0.9 * 0.8). That same 0.9 confidence for import ordering yields 0.45
(0.9 * 0.5). The weighting reflects how much each convention category actually matters
for generated code quality. Getting error handling wrong produces bugs. Getting import
ordering wrong produces a style nit.


## Data Flow

Homer data enters through MCP, gets structured in Clew and Braid, and exits as JSON
fields in the ConstraintSpec sent to sglang.

```
Homer MCP Server
    |  JSON (one query per generation, <300ms total)
    v
Clew (constraint extraction)
    |-- scope_context.zig    --> ScopeContext     --> type_bindings + imports
    |                                                 (Hard domains: Types, Imports)
    |-- call_graph_context.zig --> CallGraphContext --> caller/callee context
    |                                                  (prompt enrichment)
    |-- conventions.zig      --> SoftConstraint[]  --> semantic guidance
    |                                                  (Soft domains only, always)
    v
Braid (constraint compilation)
    |-- salience.zig         --> PriorityAdjustment  (intensity + confidence)
    |-- temporal.zig         --> TemporalAdjustment  (confidence multiplier
    |                                                 + context partners)
    v
ConstraintSpec JSON --> sglang (via constraint_spec extension field)
```

The separation between Clew and Braid is deliberate. Clew modules (scope_context,
call_graph_context, conventions) transform Homer data into structured types and
serialize to JSON. They never evaluate constraint interactions -- that is Braid's job.
Braid modules (salience, temporal) adjust priorities and confidence without knowing
where the data came from. This keeps both layers testable in isolation: 40 tests
across the five Homer integration modules, none of which require a running Homer
instance.

When Homer is unavailable, the pipeline still runs. Scope context is empty (no
cross-file bindings). Salience defaults to `standard` intensity. Temporal analysis
is absent, so confidence multipliers are 1.0. Conventions produce no soft constraints.
The hard constraints from local AST analysis -- syntax, types from the current file,
control flow -- still fire. The generated code is correct; it just may not match the
repository's conventions or know about types defined in other files.


## References

### Source Files
- `src/clew/scope_context.zig` -- Cross-file name resolution (11 tests)
- `src/clew/call_graph_context.zig` -- InlineCoder-style call graph context (7 tests)
- `src/clew/conventions.zig` -- Convention mining to soft constraints (5 tests)
- `src/braid/salience.zig` -- Salience scoring and four-quadrant classification (10 tests)
- `src/braid/temporal.zig` -- Temporal confidence adjustment (7 tests)

### Specifications
- [SPEC-03: Rich Context Export](spec/SPEC-03-rich-context.md)
- [SPEC-04: Homer Repository Intelligence](spec/SPEC-04-homer-integration.md)

### Architecture Decision Records
- [ADR-003: Homer via MCP (Not Rust FFI)](adr/ADR-003-homer-mcp-communication.md)
- [ADR-006: Scope Graph Resolution from Homer](adr/ADR-006-scope-graph-resolution-from-homer.md)
- [ADR-007: Salience-Based Constraint Relaxation](adr/ADR-007-salience-based-constraint-relaxation.md)

### External
- InlineCoder (January 2026) -- upstream/downstream call graph context, 49% improvement on RepoExec
- PLDI 2025 prefix automata -- cross-file type checking via qualified type resolution
