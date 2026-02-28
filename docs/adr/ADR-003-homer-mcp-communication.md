# ADR-003: Homer Communication via MCP (Not Direct Rust FFI)

## Status
Proposed

## Context
Homer provides repository intelligence needed for constraint generation in Phases 4A-4D: scope graphs for cross-file name resolution, composite salience scoring for constraint priority, temporal analysis for constraint confidence, and convention mining for soft constraints.

Two integration approaches are viable:

1. **MCP protocol**: Ananke CLI invokes Homer's existing MCP tools over the standard Model Context Protocol. Homer already exposes 6 MCP tools: `homer_graph`, `homer_risk`, `homer_co_changes`, `homer_conventions`, `homer_query`, and `homer_risk`.

2. **Direct Rust FFI**: Link `homer-core` and `homer-graphs` as library crates into Ananke's Maze (Rust) component. Call Homer functions directly in-process, eliminating network overhead.

Homer queries happen once per generation request (not per token). For a 100-token generation taking several seconds, Homer query overhead is <1% of total latency regardless of approach.

## Decision
Start with MCP (Phase 4a). Consider Rust FFI (Phase 4b) only if profiling demonstrates that MCP latency is a bottleneck in practice.

The MCP integration is implemented in new Zig modules that query Homer tools:
- `src/clew/scope_context.zig`: Queries Homer for scope graph bindings at a hole location.
- `src/braid/salience.zig`: Queries Homer for composite salience scores.
- `src/braid/temporal.zig`: Queries Homer for stability classification and co-change patterns.
- `src/clew/conventions.zig`: Queries Homer for empirically derived coding conventions.

All Homer data is optional (`--homer` flag). The system gracefully degrades to Phases 1-3 when Homer is unavailable.

## Consequences

**Positive:**
- Loose coupling: Ananke and Homer evolve independently. Homer API changes are absorbed at the MCP tool boundary, not throughout Ananke's codebase.
- Zero build coupling: Ananke's Zig/Rust build does not depend on Homer's crate graph, which includes multiple graph analysis libraries.
- Homer already works: The 6 MCP tools are tested and deployed. No new Homer code is needed.
- Independent deployability: Homer can be upgraded, restarted, or replaced without touching Ananke.
- Testability: MCP responses can be mocked with static JSON fixtures for deterministic testing.

**Negative:**
- ~100ms per MCP query adds latency vs in-process function calls (~1ms). Multiple queries per request could add 200-400ms total. This is acceptable given multi-second inference times but is not zero.
- Process management: Homer MCP server must be running alongside Ananke. Adds operational complexity.
- Serialization overhead for MCP request/response encoding (negligible at the data sizes involved).

## Alternatives Considered

**Direct Rust FFI:** Link homer-core and homer-graphs as library crates into Maze. Eliminates MCP overhead entirely (~100ms -> ~1ms per query). Rejected as the initial approach because: (a) it couples Ananke's Rust build to Homer's crate graph, which is substantial; (b) Homer's MCP tools already exist and work; (c) the ~100ms overhead is negligible vs inference time. Reserved as Phase 4b optimization if profiling justifies it.

**Shared SQLite database:** Homer writes analysis results to SQLite; Ananke reads directly. Avoids process communication overhead. Rejected because it couples both systems to a specific storage schema, loses the abstraction boundary that MCP provides, and requires careful concurrent access handling.

**File-based exchange:** Homer exports analysis as JSON files; Ananke reads them. Simplest integration. Rejected because it requires a separate "export" step in the workflow, analysis data goes stale, and there is no way to query for specific entities -- Ananke would need to load and filter entire analysis outputs.

## References
- Model Context Protocol (MCP) specification
- Homer MCP tool documentation: homer_graph, homer_risk, homer_co_changes, homer_conventions, homer_query
- Integration plan Phase 4: Homer Repository Intelligence
- Integration plan: Homer Communication section
