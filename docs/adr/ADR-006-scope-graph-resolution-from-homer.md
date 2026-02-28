# ADR-006: Scope Graph Resolution from Homer (Not Built in Clew)

## Status
Proposed

## Context
Clew extracts single-file ASTs via tree-sitter, producing `SyntaxStructure` with function declarations, type declarations, and import declarations. This is sufficient for single-file constraint generation but inadequate for cross-file name resolution.

Cross-file name resolution -- knowing which names are in scope at a given program point, their types, and their resolution paths through the module system -- requires scope graphs. Scope graphs model lexical scoping as a graph problem: nodes represent scopes, edges represent visibility relationships (parent, import, export), and name resolution is path finding with well-formedness constraints.

This capability is critical for Phase 4A (Scope-Graph-Informed Name Resolution). When generating code at a hole, the system needs to know which names are transitively in scope -- not just from the current file's imports, but through the entire scope graph. If `User` is defined in `models/user.py` and re-exported through `models/__init__.py`, the Import domain should constrain the import to match the resolution path the codebase actually uses.

## Decision
Use Homer's existing scope graph implementation rather than building scope graphs in Clew.

Homer already has:
- Scope graph construction for 13 languages.
- Push/pop nodes for context-sensitive resolution (e.g., Python's conditional imports, Rust's cfg-gated modules).
- Path-stitching resolution that handles complex re-export chains.
- Incremental updates that avoid full re-analysis on file changes.
- Cross-file binding resolution through module boundaries.

Clew continues to provide local AST structure (single-file function signatures, type declarations, import statements). Homer provides cross-file binding context (what names are reachable, through which paths, with what types). These are complementary: Clew for the local view, Homer for the global view.

The integration point is `src/clew/scope_context.zig`, which queries Homer via MCP for a specific file location and returns `ScopeContext`: names in scope, their types, their resolution paths, and the enclosing scope structure. This enriches `RichContext` with `scope_bindings_json`.

## Consequences

**Positive:**
- Avoids duplicating a substantial, solved problem. Scope graph construction and path-stitching resolution for 13 languages is a large engineering effort. Homer has already done this work.
- Clew stays focused on its core competency: fast, single-file tree-sitter extraction. Adding scope graphs would significantly increase Clew's complexity and maintenance burden.
- Homer's scope graphs are already tested against real repositories. Building new scope graph infrastructure would require extensive validation.
- Incremental updates are already handled by Homer. Building this in Clew would require additional infrastructure for file watching and graph maintenance.
- The MCP boundary provides a clean abstraction: Clew does not need to know how scope graphs are implemented, only what bindings are in scope at a given location.

**Negative:**
- Homer becomes a required dependency for cross-file constraint generation (Phases 4A+). Without Homer, the system falls back to single-file constraints only.
- MCP query latency (~100ms) for scope resolution. Acceptable for CLI usage but could matter for real-time IDE integration at scale.
- Homer's scope graph may not perfectly align with what the constraint system needs. Some adapter logic in `scope_context.zig` will be required to transform Homer's scope binding format into ConstraintSpec-compatible fields.
- Testing cross-file constraints requires running Homer, adding integration test complexity.

## Alternatives Considered

**Build scope graphs in Clew using tree-sitter-graph DSL:** tree-sitter provides a graph DSL for defining scope graph construction rules per language. Clew could use this to build scope graphs natively in Zig. Rejected because: (a) the tree-sitter-graph DSL rules for 13 languages are substantial to write and maintain; (b) path-stitching resolution with push/pop nodes requires significant algorithmic implementation beyond what the DSL provides; (c) Homer has already built and validated this.

**Use GitHub's stack-graphs Rust crate directly:** stack-graphs is the Rust library underlying GitHub's code navigation. It could be linked into Maze (Ananke's Rust component). Rejected because: (a) stack-graphs requires per-language graph construction rules that Homer has already defined; (b) linking stack-graphs couples Ananke's build to a large external crate with its own dependency tree; (c) Homer wraps stack-graphs concepts with additional features (incremental updates, centrality analysis) that would be lost.

**Rely on LSP servers for name resolution:** Language Server Protocol servers (rust-analyzer, pyright, gopls) provide name resolution as part of their hover/completion APIs. Rejected because: (a) LSP servers are language-specific -- would need separate server management per language; (b) LSP APIs are designed for IDE interaction, not batch constraint extraction; (c) LSP servers have heavy startup costs and memory footprints; (d) Homer provides a unified interface across all 13 languages.

## References
- Scope graphs: A fresh look at name resolution (Neron et al., 2015)
- Homer scope graph documentation
- stack-graphs (GitHub)
- Integration plan Phase 4A: Scope-Graph-Informed Name Resolution
- Integration plan: The Context Hierarchy section
