# Typed Holes Implementation Plan

**Version**: 0.2.0
**Status**: Draft
**Created**: 2025-12-08
**Author**: Architecture Team

## Executive Summary

This document provides a comprehensive implementation plan for typed holes in Ananke - a constraint-driven code generation system. Typed holes transform incomplete code from an error state into a **structured, actionable representation** that enables progressive refinement through both autoregressive (vLLM + llguidance) and diffusion (DiffuCoder) models.

### Core Philosophy

> **Incompleteness is information, not failure.**

Traditional code generation treats gaps as errors. Ananke embraces structured incompleteness through typed holes - explicit markers of ambiguity that carry:
- **Type information**: Expected types, available bindings, context types
- **Semantic constraints**: What must be true of any valid fill
- **Resolution strategies**: How the hole should be filled
- **Provenance**: Where the hole came from and why

---

## Table of Contents

1. [Development Environment Setup](#1-development-environment-setup)
2. [Phase 1: Core Type System](#2-phase-1-core-type-system-zig)
3. [Phase 2: Hole Detection (Clew)](#3-phase-2-hole-detection-clew)
4. [Phase 3: Hole Compilation (Braid)](#4-phase-3-hole-compilation-braid)
5. [Phase 4: Progressive Refinement (Maze)](#5-phase-4-progressive-refinement-maze)
6. [Phase 5: Dual-Model Generation](#6-phase-5-dual-model-generation)
7. [Phase 6: VSCode Extension](#7-phase-6-vscode-extension)
8. [Phase 7: Integration Testing](#8-phase-7-integration-testing)
9. [Risk Mitigation](#9-risk-mitigation)
10. [Appendix: Technical Specifications](#10-appendix-technical-specifications)

---

## 1. Development Environment Setup

### 1.1 Git Worktree Strategy

All typed holes development happens in an **isolated feature branch** using git worktrees. This ensures:
- Main branch remains stable and deployable
- Parallel development without merge conflicts
- Easy rollback if implementation fails
- Clean history for code review

```bash
# Create feature branch and worktree
cd /Users/rand/src/ananke
git checkout main
git pull origin main

# Create the feature branch
git checkout -b feature/typed-holes-v0.2.0

# Create isolated worktree for development
git worktree add ../ananke-typed-holes feature/typed-holes-v0.2.0

# Work in the isolated worktree
cd ../ananke-typed-holes
```

### 1.2 Branch Protection Rules

```
feature/typed-holes-v0.2.0
  └── Must pass: zig build test
  └── Must pass: cargo test (maze/)
  └── Must pass: npm test (ananke-vscode/)
  └── Requires: Code review from 1+ maintainer
```

### 1.3 VSCode Extension Worktree

```bash
# Similarly for VSCode extension
cd /Users/rand/src/ananke-vscode
git checkout main
git checkout -b feature/typed-holes-v0.2.0
git worktree add ../ananke-vscode-typed-holes feature/typed-holes-v0.2.0
```

### 1.4 Commit Strategy

- **Atomic commits**: Each commit is a single logical change
- **Commit message format**: `[component] description` (e.g., `[clew] Add hole detection for Python todo comments`)
- **Squash on merge**: Feature branch squashed to single commit on main

---

## 2. Phase 1: Core Type System (Zig)

### 2.1 New File: `src/types/hole.zig`

This is the foundational type system for holes. Every other component depends on these types.

```zig
// src/types/hole.zig
// Typed holes for progressive code refinement
const std = @import("std");
const constraint = @import("constraint.zig");

/// Scale at which a hole operates - determines resolution complexity
pub const HoleScale = enum(u8) {
    /// Single expression: `_ + 1`, `foo(_)`
    expression = 0,

    /// Single statement: `_ = compute();`
    statement = 1,

    /// Block of statements: `if (cond) { _ }`
    block = 2,

    /// Entire function body: `fn foo() { _ }`
    function = 3,

    /// Module-level: missing imports, types
    module = 4,

    /// Specification-level: architectural holes
    specification = 5,

    pub fn complexity(self: HoleScale) u32 {
        return @as(u32, 1) << (@as(u5, @intFromEnum(self)) * 2);
    }

    pub fn requiresDecomposition(self: HoleScale) bool {
        return @intFromEnum(self) >= @intFromEnum(HoleScale.function);
    }
};

/// Origin of the hole - why does this incompleteness exist?
pub const HoleOrigin = enum {
    /// User explicitly marked: `_`, `todo!()`, `@panic("TODO")`
    user_marked,

    /// Generation hit token/time limit
    generation_limit,

    /// Conflicting constraints couldn't be satisfied
    constraint_conflict,

    /// Model expressed uncertainty
    uncertainty,

    /// Structural requirement: unhandled match arm, empty impl
    structural,

    /// Type inference couldn't determine type
    type_inference_failure,

    /// Decomposed from larger hole
    decomposition,
};

/// Strategy for resolving the hole
pub const ResolutionStrategy = enum {
    /// Use LLM to complete (autoregressive or diffusion)
    llm_complete,

    /// Requires human input - can't be automated
    human_required,

    /// Adapt from similar example in codebase
    example_adapt,

    /// Break into smaller holes
    decompose,

    /// Skip and continue (low priority)
    skip,

    /// Apply template/boilerplate
    template,

    /// Use diffusion model for iterative refinement
    diffusion_refine,
};

/// Confidence level for hole fills
pub const Confidence = struct {
    /// Overall confidence 0.0-1.0
    score: f32,

    /// Factors contributing to confidence
    type_match: f32 = 1.0,
    constraint_satisfaction: f32 = 1.0,
    context_coherence: f32 = 1.0,
    example_similarity: f32 = 0.0,

    pub fn isHighConfidence(self: Confidence) bool {
        return self.score >= 0.8;
    }

    pub fn compute(self: *Confidence) void {
        self.score = (self.type_match * 0.3 +
                     self.constraint_satisfaction * 0.4 +
                     self.context_coherence * 0.2 +
                     self.example_similarity * 0.1);
    }
};

/// A typed hole representing structured incompleteness
pub const Hole = struct {
    /// Unique identifier
    id: u64,

    /// Human-readable name (optional)
    name: ?[]const u8 = null,

    /// Scale of the hole
    scale: HoleScale,

    /// Why this hole exists
    origin: HoleOrigin,

    /// Expected type (as string for now, later: proper Type)
    expected_type: ?[]const u8 = null,

    /// Type of the enclosing context
    context_type: ?[]const u8 = null,

    /// Available bindings in scope
    available_bindings: []const Binding = &.{},

    /// Constraints that any fill must satisfy
    constraints: []const constraint.Constraint = &.{},

    /// How to resolve this hole
    resolution_strategy: ResolutionStrategy = .llm_complete,

    /// Priority (higher = fill first)
    priority: u32 = 50,

    /// Confidence in current fill (if any)
    confidence: Confidence = .{ .score = 0.0 },

    /// Holes this depends on (must be filled first)
    depends_on: []const u64 = &.{},

    /// Holes that depend on this
    dependents: []const u64 = &.{},

    /// Location in source
    location: Location,

    /// Current fill (if partially resolved)
    current_fill: ?[]const u8 = null,

    /// Fill history for iterative refinement
    fill_history: []const FillAttempt = &.{},

    /// Provenance tracking
    provenance: Provenance,

    /// Model hints for generation
    model_hints: ModelHints = .{},

    pub fn isResolved(self: *const Hole) bool {
        return self.current_fill != null and self.confidence.isHighConfidence();
    }

    pub fn canAutoResolve(self: *const Hole) bool {
        return self.resolution_strategy != .human_required and
               self.scale != .specification;
    }

    pub fn getEffectivePriority(self: *const Hole) u32 {
        // Boost priority for holes that block others
        const dependency_boost = @as(u32, @intCast(self.dependents.len)) * 10;
        return self.priority + dependency_boost;
    }
};

/// A binding available in scope
pub const Binding = struct {
    name: []const u8,
    type_annotation: ?[]const u8,
    is_mutable: bool = false,
    declared_at: ?Location = null,
};

/// Source location
pub const Location = struct {
    file_path: []const u8,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,

    pub fn contains(self: Location, line: u32, col: u32) bool {
        if (line < self.start_line or line > self.end_line) return false;
        if (line == self.start_line and col < self.start_column) return false;
        if (line == self.end_line and col > self.end_column) return false;
        return true;
    }
};

/// Record of a fill attempt
pub const FillAttempt = struct {
    fill: []const u8,
    timestamp: i64,
    model: []const u8,
    strategy: ResolutionStrategy,
    confidence: Confidence,
    rejected_reason: ?[]const u8 = null,
};

/// Provenance for tracking hole origins
pub const Provenance = struct {
    created_at: i64,
    created_by: []const u8, // "clew", "user", "decomposition"
    source_artifact: ?[]const u8 = null,
    parent_hole_id: ?u64 = null,
};

/// Hints for model generation
pub const ModelHints = struct {
    /// Prefer certain token patterns
    preferred_patterns: []const []const u8 = &.{},

    /// Avoid certain patterns
    forbidden_patterns: []const []const u8 = &.{},

    /// Example fills from codebase
    example_fills: []const []const u8 = &.{},

    /// Temperature override (null = use default)
    temperature: ?f32 = null,

    /// Max tokens for this hole
    max_tokens: ?u32 = null,

    /// Prefer diffusion model for this hole
    prefer_diffusion: bool = false,
};

/// Collection of holes for a file/module
pub const HoleSet = struct {
    holes: std.ArrayList(Hole),
    allocator: std.mem.Allocator,

    /// Index by location for fast lookup
    location_index: std.AutoHashMap(u64, usize),

    pub fn init(allocator: std.mem.Allocator) HoleSet {
        return .{
            .holes = std.ArrayList(Hole).init(allocator),
            .allocator = allocator,
            .location_index = std.AutoHashMap(u64, usize).init(allocator),
        };
    }

    pub fn deinit(self: *HoleSet) void {
        self.holes.deinit();
        self.location_index.deinit();
    }

    pub fn add(self: *HoleSet, hole: Hole) !void {
        const index = self.holes.items.len;
        try self.holes.append(hole);
        try self.location_index.put(hole.id, index);
    }

    /// Get holes in resolution order (dependencies first)
    pub fn getResolutionOrder(self: *HoleSet, allocator: std.mem.Allocator) ![]const *Hole {
        // Topological sort based on depends_on
        var result = std.ArrayList(*Hole).init(allocator);
        var visited = std.AutoHashMap(u64, bool).init(allocator);
        defer visited.deinit();

        for (self.holes.items) |*hole| {
            try self.topoVisit(hole, &visited, &result);
        }

        return result.toOwnedSlice();
    }

    fn topoVisit(
        self: *HoleSet,
        hole: *Hole,
        visited: *std.AutoHashMap(u64, bool),
        result: *std.ArrayList(*Hole),
    ) !void {
        if (visited.get(hole.id)) |_| return;
        try visited.put(hole.id, true);

        // Visit dependencies first
        for (hole.depends_on) |dep_id| {
            if (self.location_index.get(dep_id)) |idx| {
                try self.topoVisit(&self.holes.items[idx], visited, result);
            }
        }

        try result.append(hole);
    }

    /// Get unresolved holes
    pub fn getUnresolved(self: *HoleSet) []const *Hole {
        var unresolved = std.ArrayList(*Hole).init(self.allocator);
        for (self.holes.items) |*hole| {
            if (!hole.isResolved()) {
                unresolved.append(hole) catch continue;
            }
        }
        return unresolved.toOwnedSlice() catch &.{};
    }
};
```

### 2.2 Extend `src/types/constraint.zig`

Add hole-related constraint types:

```zig
// Add to src/types/constraint.zig

/// Specification for filling a hole
pub const HoleSpec = struct {
    /// Reference to the hole
    hole_id: u64,

    /// JSON Schema for valid fills
    fill_schema: ?JsonSchema = null,

    /// Grammar for syntactic constraints
    fill_grammar: ?Grammar = null,

    /// Regex patterns the fill must match
    fill_patterns: []const Regex = &.{},

    /// Constraints the fill must satisfy
    fill_constraints: []const FillConstraint = &.{},

    /// llguidance grammar reference for cross-hole constraints
    grammar_ref: ?[]const u8 = null, // e.g., "@function_body"
};

/// Constraint on a hole fill
pub const FillConstraint = struct {
    kind: FillConstraintKind,
    value: []const u8,
    error_message: ?[]const u8 = null,
};

pub const FillConstraintKind = enum {
    /// Fill must have this type
    must_have_type,

    /// Fill must reference this binding
    must_use_binding,

    /// Fill must not reference this binding
    must_not_use_binding,

    /// Fill must satisfy this predicate (as code)
    must_satisfy_predicate,

    /// Fill must match AST pattern
    must_match_pattern,

    /// Fill must be pure (no side effects)
    must_be_pure,

    /// Fill must terminate
    must_terminate,
};

// Extend ConstraintIR
pub const ConstraintIR = struct {
    // ... existing fields ...

    /// Hole specifications for progressive refinement
    hole_specs: []const HoleSpec = &.{},

    /// Whether this IR supports iterative refinement
    supports_refinement: bool = false,
};
```

### 2.3 Testing Strategy for Phase 1

```zig
// src/types/hole_test.zig
test "HoleScale complexity increases exponentially" {
    try std.testing.expectEqual(@as(u32, 1), HoleScale.expression.complexity());
    try std.testing.expectEqual(@as(u32, 4), HoleScale.statement.complexity());
    try std.testing.expectEqual(@as(u32, 16), HoleScale.block.complexity());
    try std.testing.expectEqual(@as(u32, 64), HoleScale.function.complexity());
}

test "HoleSet topological sort respects dependencies" {
    var set = HoleSet.init(std.testing.allocator);
    defer set.deinit();

    // Hole B depends on Hole A
    try set.add(.{ .id = 1, .depends_on = &.{}, ... });
    try set.add(.{ .id = 2, .depends_on = &.{1}, ... });

    const order = try set.getResolutionOrder(std.testing.allocator);
    defer std.testing.allocator.free(order);

    try std.testing.expectEqual(@as(u64, 1), order[0].id);
    try std.testing.expectEqual(@as(u64, 2), order[1].id);
}
```

---

## 3. Phase 2: Hole Detection (Clew)

### 3.1 New File: `src/clew/hole_detector.zig`

```zig
// src/clew/hole_detector.zig
const std = @import("std");
const Hole = @import("../types/hole.zig").Hole;
const HoleScale = @import("../types/hole.zig").HoleScale;
const HoleOrigin = @import("../types/hole.zig").HoleOrigin;
const HoleSet = @import("../types/hole.zig").HoleSet;

pub const HoleDetector = struct {
    allocator: std.mem.Allocator,
    language: Language,

    pub const Language = enum {
        python,
        typescript,
        zig,
        rust,
    };

    /// Explicit hole markers by language
    const ExplicitMarkers = struct {
        python: []const []const u8 = &.{
            "...",           // Ellipsis
            "pass",          // Empty pass
            "TODO",          // Comment marker
            "FIXME",         // Comment marker
            "NotImplementedError",
            "raise NotImplementedError",
        },
        typescript: []const []const u8 = &.{
            "// TODO",
            "// FIXME",
            "throw new Error('TODO')",
            "throw new Error('Not implemented')",
            "undefined as any",  // Type escape hatch
        },
        zig: []const []const u8 = &.{
            "@panic(\"TODO\")",
            "@panic(\"not implemented\")",
            "unreachable", // Often indicates incomplete
            "// TODO",
            "// FIXME",
        },
        rust: []const []const u8 = &.{
            "todo!()",
            "unimplemented!()",
            "panic!(\"TODO\")",
            "// TODO",
            "// FIXME",
        },
    };

    pub fn init(allocator: std.mem.Allocator, language: Language) HoleDetector {
        return .{
            .allocator = allocator,
            .language = language,
        };
    }

    /// Detect all holes in source code
    pub fn detectHoles(self: *HoleDetector, source: []const u8, file_path: []const u8) !HoleSet {
        var holes = HoleSet.init(self.allocator);

        // 1. Detect explicit markers
        try self.detectExplicitHoles(source, file_path, &holes);

        // 2. Detect structural holes (empty bodies, unhandled cases)
        try self.detectStructuralHoles(source, file_path, &holes);

        // 3. Detect type inference failures
        try self.detectTypeHoles(source, file_path, &holes);

        // 4. Build dependency graph between holes
        try self.buildDependencyGraph(&holes);

        return holes;
    }

    fn detectExplicitHoles(
        self: *HoleDetector,
        source: []const u8,
        file_path: []const u8,
        holes: *HoleSet,
    ) !void {
        const markers = switch (self.language) {
            .python => ExplicitMarkers.python,
            .typescript => ExplicitMarkers.typescript,
            .zig => ExplicitMarkers.zig,
            .rust => ExplicitMarkers.rust,
        };

        var line_num: u32 = 1;
        var col_num: u32 = 1;
        var i: usize = 0;

        while (i < source.len) {
            for (markers) |marker| {
                if (i + marker.len <= source.len and
                    std.mem.eql(u8, source[i..i + marker.len], marker))
                {
                    const hole = Hole{
                        .id = generateHoleId(file_path, line_num, col_num),
                        .scale = inferScale(source, i),
                        .origin = .user_marked,
                        .location = .{
                            .file_path = file_path,
                            .start_line = line_num,
                            .start_column = col_num,
                            .end_line = line_num,
                            .end_column = col_num + @as(u32, @intCast(marker.len)),
                        },
                        .provenance = .{
                            .created_at = std.time.timestamp(),
                            .created_by = "clew",
                            .source_artifact = file_path,
                        },
                    };
                    try holes.add(hole);
                }
            }

            if (source[i] == '\n') {
                line_num += 1;
                col_num = 1;
            } else {
                col_num += 1;
            }
            i += 1;
        }
    }

    fn detectStructuralHoles(
        self: *HoleDetector,
        source: []const u8,
        file_path: []const u8,
        holes: *HoleSet,
    ) !void {
        // Use tree-sitter to find:
        // - Empty function bodies
        // - Unhandled match/switch arms
        // - Abstract methods without implementation
        // - Incomplete pattern matches

        // This integrates with existing Clew tree-sitter infrastructure
        _ = self;
        _ = source;
        _ = file_path;
        _ = holes;
        // TODO: Implement using existing traversal.zig
    }

    fn detectTypeHoles(
        self: *HoleDetector,
        source: []const u8,
        file_path: []const u8,
        holes: *HoleSet,
    ) !void {
        // Detect places where type inference failed:
        // - Explicit `any` in TypeScript
        // - `# type: ignore` in Python
        // - `@as(anyopaque, ...)` in Zig
        _ = self;
        _ = source;
        _ = file_path;
        _ = holes;
        // TODO: Implement
    }

    fn buildDependencyGraph(self: *HoleDetector, holes: *HoleSet) !void {
        // Analyze data flow to determine:
        // - Which holes must be filled before others
        // - Which holes are independent (can be filled in parallel)
        _ = self;
        _ = holes;
        // TODO: Implement using data flow analysis
    }

    fn generateHoleId(file_path: []const u8, line: u32, col: u32) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(file_path);
        hasher.update(std.mem.asBytes(&line));
        hasher.update(std.mem.asBytes(&col));
        return hasher.final();
    }

    fn inferScale(source: []const u8, pos: usize) HoleScale {
        // Simple heuristic: look at surrounding context
        // TODO: Use AST for accurate scale inference
        _ = source;
        _ = pos;
        return .expression;
    }
};
```

### 3.2 Integration with Existing Clew

Modify `src/clew/clew.zig` to expose hole detection:

```zig
// Add to src/clew/clew.zig

const HoleDetector = @import("hole_detector.zig").HoleDetector;
const HoleSet = @import("../types/hole.zig").HoleSet;

pub const Clew = struct {
    // ... existing fields ...

    /// Detect typed holes in source code
    pub fn detectHoles(self: *Clew, source: []const u8, language: []const u8) !HoleSet {
        const lang = try parseLanguage(language);
        var detector = HoleDetector.init(self.allocator, lang);
        return try detector.detectHoles(source, "unknown");
    }

    fn parseLanguage(language: []const u8) !HoleDetector.Language {
        if (std.mem.eql(u8, language, "python")) return .python;
        if (std.mem.eql(u8, language, "typescript")) return .typescript;
        if (std.mem.eql(u8, language, "zig")) return .zig;
        if (std.mem.eql(u8, language, "rust")) return .rust;
        return error.UnsupportedLanguage;
    }
};
```

---

## 4. Phase 3: Hole Compilation (Braid)

### 4.1 New File: `src/braid/hole_compiler.zig`

```zig
// src/braid/hole_compiler.zig
const std = @import("std");
const Hole = @import("../types/hole.zig").Hole;
const HoleSet = @import("../types/hole.zig").HoleSet;
const HoleSpec = @import("../types/constraint.zig").HoleSpec;
const ConstraintIR = @import("../types/constraint.zig").ConstraintIR;

pub const HoleCompiler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HoleCompiler {
        return .{ .allocator = allocator };
    }

    /// Compile holes to ConstraintIR with HoleSpecs
    pub fn compile(self: *HoleCompiler, holes: *HoleSet) !ConstraintIR {
        var ir = ConstraintIR{};

        var hole_specs = std.ArrayList(HoleSpec).init(self.allocator);
        defer hole_specs.deinit();

        for (holes.holes.items) |hole| {
            const spec = try self.compileHole(&hole);
            try hole_specs.append(spec);
        }

        ir.hole_specs = try hole_specs.toOwnedSlice();
        ir.supports_refinement = true;

        return ir;
    }

    fn compileHole(self: *HoleCompiler, hole: *const Hole) !HoleSpec {
        var spec = HoleSpec{
            .hole_id = hole.id,
        };

        // Generate JSON Schema from expected type
        if (hole.expected_type) |expected| {
            spec.fill_schema = try self.typeToJsonSchema(expected);
        }

        // Generate grammar for syntactic constraints
        spec.fill_grammar = try self.generateGrammar(hole);

        // Add fill constraints from hole constraints
        var fill_constraints = std.ArrayList(@import("../types/constraint.zig").FillConstraint).init(self.allocator);
        for (hole.constraints) |c| {
            try fill_constraints.append(try self.constraintToFillConstraint(c));
        }
        spec.fill_constraints = try fill_constraints.toOwnedSlice();

        // Generate grammar reference for llguidance cross-hole constraints
        spec.grammar_ref = try self.generateGrammarRef(hole);

        return spec;
    }

    fn typeToJsonSchema(self: *HoleCompiler, type_str: []const u8) !@import("../types/constraint.zig").JsonSchema {
        // Map type strings to JSON Schema
        // This is a simplified version - full implementation would use type system
        _ = self;

        if (std.mem.eql(u8, type_str, "string") or std.mem.eql(u8, type_str, "str")) {
            return .{ .type = "string" };
        } else if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "number")) {
            return .{ .type = "integer" };
        } else if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) {
            return .{ .type = "boolean" };
        } else if (std.mem.startsWith(u8, type_str, "list") or std.mem.startsWith(u8, type_str, "array")) {
            return .{ .type = "array" };
        }

        // Default: object for complex types
        return .{ .type = "object" };
    }

    fn generateGrammar(self: *HoleCompiler, hole: *const Hole) !?@import("../types/constraint.zig").Grammar {
        // Generate CFG grammar based on hole scale and context
        _ = self;

        return switch (hole.scale) {
            .expression => @import("../types/constraint.zig").Grammar{
                .start_symbol = "expr",
                .rules = &.{
                    .{ .lhs = "expr", .rhs = &.{ "term", "op", "term" } },
                    .{ .lhs = "term", .rhs = &.{"identifier"} },
                    .{ .lhs = "term", .rhs = &.{"literal"} },
                },
            },
            .statement => @import("../types/constraint.zig").Grammar{
                .start_symbol = "stmt",
                .rules = &.{
                    .{ .lhs = "stmt", .rhs = &.{ "let", "identifier", "=", "expr", ";" } },
                    .{ .lhs = "stmt", .rhs = &.{ "return", "expr", ";" } },
                },
            },
            else => null,
        };
    }

    fn constraintToFillConstraint(
        self: *HoleCompiler,
        constraint: @import("../types/constraint.zig").Constraint,
    ) !@import("../types/constraint.zig").FillConstraint {
        _ = self;
        // Map general constraints to fill-specific constraints
        return .{
            .kind = .must_satisfy_predicate,
            .value = constraint.description,
        };
    }

    fn generateGrammarRef(self: *HoleCompiler, hole: *const Hole) !?[]const u8 {
        // Generate llguidance grammar reference for cross-hole constraints
        // Format: @hole_<id> or @<semantic_name>
        _ = self;

        if (hole.name) |name| {
            return name;
        }

        // Generate reference based on scale
        return switch (hole.scale) {
            .expression => "@expr",
            .statement => "@stmt",
            .block => "@block",
            .function => "@function_body",
            else => null,
        };
    }
};
```

---

## 5. Phase 4: Progressive Refinement (Maze)

### 5.1 New File: `maze/src/progressive_refinement.rs`

This is the core innovation - an iterative loop that progressively fills holes while respecting dependencies and constraints.

```rust
// maze/src/progressive_refinement.rs
use std::collections::{HashMap, VecDeque};
use serde::{Deserialize, Serialize};
use anyhow::{Result, Context};

use crate::ffi::{ConstraintIR, GenerationResult};
use crate::modal_client::ModalClient;

/// Configuration for progressive refinement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementConfig {
    /// Maximum iterations before giving up
    pub max_iterations: usize,

    /// Minimum confidence to accept a fill
    pub min_confidence: f32,

    /// Enable parallel hole filling for independent holes
    pub parallel_fill: bool,

    /// Temperature schedule for refinement (decreasing over iterations)
    pub temperature_schedule: Vec<f32>,

    /// Strategy for handling failed fills
    pub failure_strategy: FailureStrategy,

    /// Whether to use diffusion model for complex holes
    pub enable_diffusion: bool,
}

impl Default for RefinementConfig {
    fn default() -> Self {
        Self {
            max_iterations: 10,
            min_confidence: 0.8,
            parallel_fill: true,
            temperature_schedule: vec![0.9, 0.7, 0.5, 0.3, 0.1],
            failure_strategy: FailureStrategy::Decompose,
            enable_diffusion: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FailureStrategy {
    /// Skip the hole and continue
    Skip,
    /// Decompose into smaller holes
    Decompose,
    /// Mark for human review
    HumanReview,
    /// Retry with different strategy
    RetryAlternate,
}

/// State of a hole during refinement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoleState {
    pub id: u64,
    pub scale: String,
    pub origin: String,
    pub expected_type: Option<String>,
    pub constraints: Vec<String>,
    pub current_fill: Option<String>,
    pub confidence: f32,
    pub attempts: Vec<FillAttempt>,
    pub status: HoleStatus,
    pub depends_on: Vec<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum HoleStatus {
    Pending,
    InProgress,
    Filled,
    Failed,
    Skipped,
    NeedsHuman,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FillAttempt {
    pub fill: String,
    pub confidence: f32,
    pub iteration: usize,
    pub model: String,
    pub strategy: String,
    pub rejected_reason: Option<String>,
}

/// Result of the refinement process
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementResult {
    /// Final generated code with holes filled
    pub code: String,

    /// State of each hole after refinement
    pub holes: Vec<HoleState>,

    /// Whether all holes were successfully filled
    pub complete: bool,

    /// Holes that need human review
    pub needs_review: Vec<u64>,

    /// Total iterations performed
    pub iterations: usize,

    /// Refinement metadata
    pub metadata: RefinementMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementMetadata {
    pub total_time_ms: u64,
    pub tokens_generated: usize,
    pub model_calls: usize,
    pub cache_hits: usize,
}

/// Progressive refinement engine
pub struct ProgressiveRefiner {
    modal_client: ModalClient,
    config: RefinementConfig,
}

impl ProgressiveRefiner {
    pub fn new(modal_client: ModalClient, config: RefinementConfig) -> Self {
        Self { modal_client, config }
    }

    /// Execute progressive refinement on code with holes
    pub async fn refine(
        &self,
        code: &str,
        holes: Vec<HoleState>,
        constraints_ir: &ConstraintIR,
    ) -> Result<RefinementResult> {
        let start_time = std::time::Instant::now();

        let mut current_code = code.to_string();
        let mut hole_states: HashMap<u64, HoleState> =
            holes.into_iter().map(|h| (h.id, h)).collect();

        let mut iteration = 0;
        let mut total_tokens = 0;
        let mut model_calls = 0;
        let mut cache_hits = 0;

        // Main refinement loop
        while iteration < self.config.max_iterations {
            let temperature = self.config.temperature_schedule
                .get(iteration)
                .copied()
                .unwrap_or(0.1);

            // Get holes ready to fill (dependencies satisfied)
            let ready_holes = self.get_ready_holes(&hole_states);

            if ready_holes.is_empty() {
                // Check if we're done or stuck
                if self.all_holes_resolved(&hole_states) {
                    break;
                } else {
                    // Handle deadlock - break a cycle
                    self.handle_deadlock(&mut hole_states)?;
                }
            }

            // Fill holes (parallel if configured)
            if self.config.parallel_fill && ready_holes.len() > 1 {
                let results = self.fill_holes_parallel(
                    &ready_holes,
                    &current_code,
                    constraints_ir,
                    temperature,
                ).await?;

                for (hole_id, result) in results {
                    self.apply_fill_result(
                        &mut hole_states,
                        &mut current_code,
                        hole_id,
                        result,
                        iteration,
                    )?;
                    model_calls += 1;
                }
            } else {
                for hole_id in ready_holes {
                    let result = self.fill_hole(
                        hole_id,
                        &current_code,
                        constraints_ir,
                        temperature,
                    ).await?;

                    total_tokens += result.tokens_generated;
                    model_calls += 1;

                    self.apply_fill_result(
                        &mut hole_states,
                        &mut current_code,
                        hole_id,
                        result,
                        iteration,
                    )?;
                }
            }

            iteration += 1;
        }

        // Collect results
        let holes: Vec<HoleState> = hole_states.into_values().collect();
        let needs_review: Vec<u64> = holes.iter()
            .filter(|h| h.status == HoleStatus::NeedsHuman)
            .map(|h| h.id)
            .collect();

        let complete = holes.iter().all(|h|
            h.status == HoleStatus::Filled || h.status == HoleStatus::Skipped
        );

        Ok(RefinementResult {
            code: current_code,
            holes,
            complete,
            needs_review,
            iterations: iteration,
            metadata: RefinementMetadata {
                total_time_ms: start_time.elapsed().as_millis() as u64,
                tokens_generated: total_tokens,
                model_calls,
                cache_hits,
            },
        })
    }

    /// Get holes that are ready to fill (all dependencies satisfied)
    fn get_ready_holes(&self, states: &HashMap<u64, HoleState>) -> Vec<u64> {
        states.values()
            .filter(|h| {
                h.status == HoleStatus::Pending &&
                h.depends_on.iter().all(|dep| {
                    states.get(dep)
                        .map(|d| d.status == HoleStatus::Filled)
                        .unwrap_or(true)
                })
            })
            .map(|h| h.id)
            .collect()
    }

    /// Check if all holes are resolved
    fn all_holes_resolved(&self, states: &HashMap<u64, HoleState>) -> bool {
        states.values().all(|h| {
            matches!(h.status,
                HoleStatus::Filled |
                HoleStatus::Skipped |
                HoleStatus::NeedsHuman
            )
        })
    }

    /// Handle dependency deadlock
    fn handle_deadlock(&self, states: &mut HashMap<u64, HoleState>) -> Result<()> {
        // Find a cycle and break it by marking lowest-priority hole for decomposition
        // For now, simple heuristic: mark first pending hole
        for state in states.values_mut() {
            if state.status == HoleStatus::Pending {
                match self.config.failure_strategy {
                    FailureStrategy::Skip => state.status = HoleStatus::Skipped,
                    FailureStrategy::HumanReview => state.status = HoleStatus::NeedsHuman,
                    FailureStrategy::Decompose => {
                        // TODO: Decompose into smaller holes
                        state.status = HoleStatus::NeedsHuman;
                    }
                    FailureStrategy::RetryAlternate => {
                        // Clear dependencies to break cycle
                        state.depends_on.clear();
                    }
                }
                return Ok(());
            }
        }
        Ok(())
    }

    /// Fill a single hole using LLM
    async fn fill_hole(
        &self,
        hole_id: u64,
        code: &str,
        constraints_ir: &ConstraintIR,
        temperature: f32,
    ) -> Result<FillResult> {
        // Build prompt with hole context
        let prompt = self.build_fill_prompt(hole_id, code)?;

        // Call Modal inference with constraints
        let request = crate::modal_client::InferenceRequest {
            prompt,
            constraints: serde_json::to_value(constraints_ir)?,
            max_tokens: 512, // Reasonable limit for single hole
            temperature,
            context: None,
        };

        let response = self.modal_client.generate_constrained(request).await?;

        // Validate fill against constraints
        let confidence = self.compute_fill_confidence(&response.generated_text, constraints_ir);

        Ok(FillResult {
            fill: response.generated_text,
            confidence,
            tokens_generated: response.tokens_generated,
            model: response.model,
        })
    }

    /// Fill multiple holes in parallel
    async fn fill_holes_parallel(
        &self,
        hole_ids: &[u64],
        code: &str,
        constraints_ir: &ConstraintIR,
        temperature: f32,
    ) -> Result<Vec<(u64, FillResult)>> {
        use futures::future::join_all;

        let futures: Vec<_> = hole_ids.iter()
            .map(|&id| self.fill_hole(id, code, constraints_ir, temperature))
            .collect();

        let results = join_all(futures).await;

        hole_ids.iter()
            .copied()
            .zip(results.into_iter())
            .map(|(id, r)| r.map(|fill| (id, fill)))
            .collect()
    }

    fn build_fill_prompt(&self, _hole_id: u64, code: &str) -> Result<String> {
        // Build a focused prompt for filling the specific hole
        Ok(format!(
            "Complete the TODO/placeholder in the following code. \
             Output ONLY the code that should replace the placeholder:\n\n{}",
            code
        ))
    }

    fn compute_fill_confidence(&self, fill: &str, _constraints_ir: &ConstraintIR) -> f32 {
        // Heuristic confidence based on:
        // - Fill length (too short = suspicious)
        // - Syntax validity
        // - Constraint satisfaction

        if fill.is_empty() {
            return 0.0;
        }

        // Basic heuristics
        let length_score = (fill.len() as f32 / 100.0).min(1.0);
        let has_code = fill.contains(|c: char| c.is_alphanumeric());

        if has_code {
            0.5 + length_score * 0.5
        } else {
            0.3
        }
    }

    fn apply_fill_result(
        &self,
        states: &mut HashMap<u64, HoleState>,
        code: &mut String,
        hole_id: u64,
        result: FillResult,
        iteration: usize,
    ) -> Result<()> {
        let state = states.get_mut(&hole_id)
            .context("Hole not found")?;

        let attempt = FillAttempt {
            fill: result.fill.clone(),
            confidence: result.confidence,
            iteration,
            model: result.model,
            strategy: "llm_complete".to_string(),
            rejected_reason: None,
        };

        state.attempts.push(attempt);

        if result.confidence >= self.config.min_confidence {
            state.current_fill = Some(result.fill.clone());
            state.confidence = result.confidence;
            state.status = HoleStatus::Filled;

            // TODO: Actually replace hole in code
            // This requires tracking hole locations
        } else {
            // Handle low confidence fill
            match self.config.failure_strategy {
                FailureStrategy::Skip => state.status = HoleStatus::Skipped,
                FailureStrategy::HumanReview => state.status = HoleStatus::NeedsHuman,
                FailureStrategy::Decompose => {
                    // Keep as pending for decomposition in next iteration
                }
                FailureStrategy::RetryAlternate => {
                    // Will retry with different parameters
                }
            }
        }

        Ok(())
    }
}

struct FillResult {
    fill: String,
    confidence: f32,
    tokens_generated: usize,
    model: String,
}
```

---

## 6. Phase 5: Dual-Model Generation

### 6.1 Diffusion Model Integration

Support for DiffuCoder and other diffusion-based code generation models:

```rust
// maze/src/diffusion.rs
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Configuration for diffusion-based generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiffusionConfig {
    /// Number of denoising steps
    pub num_steps: usize,

    /// Noise schedule type
    pub noise_schedule: NoiseSchedule,

    /// Guidance scale for constraint steering
    pub guidance_scale: f32,

    /// Whether to use classifier-free guidance
    pub use_cfg: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum NoiseSchedule {
    Linear,
    Cosine,
    Sqrt,
}

impl Default for DiffusionConfig {
    fn default() -> Self {
        Self {
            num_steps: 50,
            noise_schedule: NoiseSchedule::Cosine,
            guidance_scale: 7.5,
            use_cfg: true,
        }
    }
}

/// Diffusion-based code generator for complex holes
pub struct DiffusionGenerator {
    config: DiffusionConfig,
    // Model client would go here
}

impl DiffusionGenerator {
    pub fn new(config: DiffusionConfig) -> Self {
        Self { config }
    }

    /// Generate code using iterative denoising
    ///
    /// Diffusion models are particularly good for:
    /// - Large holes (function/module scale)
    /// - Holes with many constraints (better for satisfying all)
    /// - Iterative refinement (natural fit)
    pub async fn generate(
        &self,
        prompt: &str,
        constraints: &[String],
        _context: Option<&str>,
    ) -> Result<DiffusionResult> {
        // Diffusion generation process:
        // 1. Start with noise (random tokens)
        // 2. Iteratively denoise while respecting constraints
        // 3. Apply guidance at each step to steer toward constraint satisfaction

        // For now, stub implementation
        // Full implementation would use DiffuCoder or similar model

        Ok(DiffusionResult {
            code: format!("// Generated for: {}\n// Constraints: {:?}", prompt, constraints),
            confidence: 0.5,
            steps_used: self.config.num_steps,
            constraint_scores: constraints.iter()
                .map(|c| (c.clone(), 0.5))
                .collect(),
        })
    }

    /// Refine existing code using diffusion
    ///
    /// This is the key advantage of diffusion models:
    /// They can naturally refine partial programs
    pub async fn refine(
        &self,
        code: &str,
        holes: &[HoleLocation],
        constraints: &[String],
    ) -> Result<DiffusionResult> {
        // Refinement process:
        // 1. Encode existing code
        // 2. Add noise only to hole regions
        // 3. Denoise while preserving non-hole regions
        // 4. Apply constraints during denoising

        // Stub implementation
        Ok(DiffusionResult {
            code: code.to_string(),
            confidence: 0.5,
            steps_used: self.config.num_steps / 2, // Refinement uses fewer steps
            constraint_scores: constraints.iter()
                .map(|c| (c.clone(), 0.5))
                .collect(),
        })
    }
}

#[derive(Debug, Clone)]
pub struct HoleLocation {
    pub start_byte: usize,
    pub end_byte: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiffusionResult {
    pub code: String,
    pub confidence: f32,
    pub steps_used: usize,
    pub constraint_scores: Vec<(String, f32)>,
}
```

### 6.2 Model Selection Strategy

```rust
// maze/src/model_selector.rs
use crate::ffi::HoleSpec;

/// Strategy for selecting between autoregressive and diffusion models
pub struct ModelSelector {
    /// Threshold for preferring diffusion (hole complexity)
    pub diffusion_complexity_threshold: u32,

    /// Threshold for preferring diffusion (constraint count)
    pub diffusion_constraint_threshold: usize,
}

impl ModelSelector {
    /// Select the best model for filling a hole
    pub fn select(&self, hole_spec: &HoleSpec) -> ModelChoice {
        // Heuristics for model selection:
        // 1. Large holes (function+) benefit from diffusion's global coherence
        // 2. Many constraints benefit from diffusion's parallel satisfaction
        // 3. Simple expressions are faster with autoregressive

        let complexity = self.estimate_complexity(hole_spec);
        let constraint_count = hole_spec.fill_constraints.len();

        if complexity >= self.diffusion_complexity_threshold ||
           constraint_count >= self.diffusion_constraint_threshold {
            ModelChoice::Diffusion {
                num_steps: 50,
                guidance_scale: 7.5,
            }
        } else {
            ModelChoice::Autoregressive {
                temperature: 0.7,
                max_tokens: 256,
            }
        }
    }

    fn estimate_complexity(&self, _hole_spec: &HoleSpec) -> u32 {
        // Estimate based on hole scale, type complexity, etc.
        // Stub for now
        1
    }
}

pub enum ModelChoice {
    Autoregressive {
        temperature: f32,
        max_tokens: usize,
    },
    Diffusion {
        num_steps: usize,
        guidance_scale: f32,
    },
}
```

---

## 7. Phase 6: VSCode Extension

### 7.1 New File: `src/providers/holeProvider.ts`

```typescript
// ananke-vscode/src/providers/holeProvider.ts
import * as vscode from 'vscode';

export interface Hole {
    id: string;
    scale: 'expression' | 'statement' | 'block' | 'function' | 'module' | 'specification';
    origin: 'user_marked' | 'generation_limit' | 'constraint_conflict' | 'uncertainty' | 'structural';
    expectedType?: string;
    contextType?: string;
    constraints: string[];
    confidence: number;
    currentFill?: string;
    location: {
        startLine: number;
        startColumn: number;
        endLine: number;
        endColumn: number;
    };
    dependsOn: string[];
    resolutionStrategy: 'llm_complete' | 'human_required' | 'example_adapt' | 'decompose' | 'skip';
}

export interface FillPreview {
    fill: string;
    confidence: number;
    model: string;
    constraints_satisfied: string[];
    constraints_violated: string[];
}

export class HoleProvider implements vscode.CodeLensProvider, vscode.HoverProvider {
    private _onDidChangeCodeLenses = new vscode.EventEmitter<void>();
    public readonly onDidChangeCodeLenses = this._onDidChangeCodeLenses.event;

    private holes: Map<string, Hole[]> = new Map();
    private decorationType: vscode.TextEditorDecorationType;

    constructor() {
        this.decorationType = vscode.window.createTextEditorDecorationType({
            backgroundColor: new vscode.ThemeColor('editorWarning.background'),
            border: '1px dashed',
            borderColor: new vscode.ThemeColor('editorWarning.foreground'),
        });
    }

    public async detectHoles(document: vscode.TextDocument): Promise<Hole[]> {
        // Call Ananke backend to detect holes
        const response = await this.callAnanke('detect_holes', {
            content: document.getText(),
            language: document.languageId,
            filePath: document.uri.fsPath,
        });

        const holes = response.holes as Hole[];
        this.holes.set(document.uri.toString(), holes);
        this._onDidChangeCodeLenses.fire();

        // Update decorations
        this.updateDecorations(document, holes);

        return holes;
    }

    public provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] {
        const holes = this.holes.get(document.uri.toString()) || [];

        return holes.map(hole => {
            const range = new vscode.Range(
                hole.location.startLine - 1,
                hole.location.startColumn - 1,
                hole.location.endLine - 1,
                hole.location.endColumn - 1
            );

            return new vscode.CodeLens(range, {
                title: `$(lightbulb) Fill ${hole.scale} hole`,
                command: 'ananke.fillHole',
                arguments: [hole],
            });
        });
    }

    public provideHover(
        document: vscode.TextDocument,
        position: vscode.Position
    ): vscode.Hover | undefined {
        const holes = this.holes.get(document.uri.toString()) || [];

        for (const hole of holes) {
            const range = new vscode.Range(
                hole.location.startLine - 1,
                hole.location.startColumn - 1,
                hole.location.endLine - 1,
                hole.location.endColumn - 1
            );

            if (range.contains(position)) {
                return new vscode.Hover(
                    this.formatHoleInfo(hole),
                    range
                );
            }
        }

        return undefined;
    }

    private formatHoleInfo(hole: Hole): vscode.MarkdownString {
        const md = new vscode.MarkdownString();
        md.isTrusted = true;

        md.appendMarkdown(`### Typed Hole\n\n`);
        md.appendMarkdown(`**Scale:** ${hole.scale}\n\n`);
        md.appendMarkdown(`**Origin:** ${hole.origin}\n\n`);

        if (hole.expectedType) {
            md.appendMarkdown(`**Expected Type:** \`${hole.expectedType}\`\n\n`);
        }

        if (hole.constraints.length > 0) {
            md.appendMarkdown(`**Constraints:**\n`);
            for (const c of hole.constraints) {
                md.appendMarkdown(`- ${c}\n`);
            }
            md.appendMarkdown('\n');
        }

        md.appendMarkdown(`**Confidence:** ${(hole.confidence * 100).toFixed(0)}%\n\n`);
        md.appendMarkdown(`**Strategy:** ${hole.resolutionStrategy}\n\n`);

        md.appendMarkdown(`[Fill Hole](command:ananke.fillHole?${encodeURIComponent(JSON.stringify(hole))})`);

        return md;
    }

    private updateDecorations(document: vscode.TextDocument, holes: Hole[]): void {
        const editor = vscode.window.visibleTextEditors.find(
            e => e.document.uri.toString() === document.uri.toString()
        );

        if (!editor) return;

        const decorations = holes.map(hole => {
            return {
                range: new vscode.Range(
                    hole.location.startLine - 1,
                    hole.location.startColumn - 1,
                    hole.location.endLine - 1,
                    hole.location.endColumn - 1
                ),
                hoverMessage: this.formatHoleInfo(hole),
            };
        });

        editor.setDecorations(this.decorationType, decorations);
    }

    public async fillHole(hole: Hole): Promise<FillPreview[]> {
        // Get fill previews from backend
        const response = await this.callAnanke('fill_hole', {
            holeId: hole.id,
            strategy: hole.resolutionStrategy,
        });

        return response.previews as FillPreview[];
    }

    public async applyFill(hole: Hole, fill: FillPreview): Promise<void> {
        const document = vscode.window.activeTextEditor?.document;
        if (!document) return;

        const edit = new vscode.WorkspaceEdit();
        const range = new vscode.Range(
            hole.location.startLine - 1,
            hole.location.startColumn - 1,
            hole.location.endLine - 1,
            hole.location.endColumn - 1
        );

        edit.replace(document.uri, range, fill.fill);
        await vscode.workspace.applyEdit(edit);

        // Re-detect holes after applying fill
        await this.detectHoles(document);
    }

    private async callAnanke(method: string, params: object): Promise<any> {
        // Implementation would call the Ananke binary or language server
        // Stub for now
        return { holes: [], previews: [] };
    }
}
```

### 7.2 Commands for Hole Management

```typescript
// ananke-vscode/src/commands/holeCommands.ts
import * as vscode from 'vscode';
import { HoleProvider, Hole, FillPreview } from '../providers/holeProvider';

export function registerHoleCommands(
    context: vscode.ExtensionContext,
    holeProvider: HoleProvider
): void {
    // Fill Hole Command
    context.subscriptions.push(
        vscode.commands.registerCommand('ananke.fillHole', async (hole: Hole) => {
            const previews = await holeProvider.fillHole(hole);

            if (previews.length === 0) {
                vscode.window.showWarningMessage('No fill suggestions available');
                return;
            }

            // Show quick pick with previews
            const items = previews.map(p => ({
                label: `$(lightbulb) ${p.fill.split('\n')[0]}`,
                description: `${(p.confidence * 100).toFixed(0)}% confidence`,
                detail: p.fill.length > 100 ? p.fill.substring(0, 100) + '...' : p.fill,
                preview: p,
            }));

            const selected = await vscode.window.showQuickPick(items, {
                title: `Fill ${hole.scale} hole`,
                placeHolder: 'Select a fill option',
            });

            if (selected) {
                await holeProvider.applyFill(hole, selected.preview);
            }
        })
    );

    // Detect Holes Command
    context.subscriptions.push(
        vscode.commands.registerCommand('ananke.detectHoles', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            const holes = await holeProvider.detectHoles(editor.document);
            vscode.window.showInformationMessage(
                `Found ${holes.length} typed holes`
            );
        })
    );

    // Fill All Holes Command
    context.subscriptions.push(
        vscode.commands.registerCommand('ananke.fillAllHoles', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            const holes = await holeProvider.detectHoles(editor.document);

            // Progressive refinement UI
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: 'Filling holes',
                cancellable: true,
            }, async (progress, token) => {
                const total = holes.length;
                let filled = 0;

                for (const hole of holes) {
                    if (token.isCancellationRequested) break;
                    if (hole.resolutionStrategy === 'human_required') continue;

                    progress.report({
                        message: `${filled}/${total}: ${hole.scale} hole`,
                        increment: 100 / total,
                    });

                    const previews = await holeProvider.fillHole(hole);
                    if (previews.length > 0 && previews[0].confidence > 0.8) {
                        await holeProvider.applyFill(hole, previews[0]);
                        filled++;
                    }
                }

                vscode.window.showInformationMessage(
                    `Filled ${filled}/${total} holes`
                );
            });
        })
    );

    // Decompose Hole Command
    context.subscriptions.push(
        vscode.commands.registerCommand('ananke.decomposeHole', async (hole: Hole) => {
            // TODO: Implement hole decomposition
            vscode.window.showInformationMessage(
                `Decomposing ${hole.scale} hole into smaller holes...`
            );
        })
    );
}
```

### 7.3 Language Server Extension

Add hole support to the existing LSP server:

```typescript
// ananke-vscode/src/language-server/services/holes.ts
import { TextDocument } from 'vscode-languageserver-textdocument';
import {
    CodeAction,
    CodeActionKind,
    Diagnostic,
    DiagnosticSeverity,
} from 'vscode-languageserver/node';

export interface HoleDiagnosticData {
    holeId: string;
    scale: string;
    strategy: string;
}

export function getHoleDiagnostics(document: TextDocument): Diagnostic[] {
    const text = document.getText();
    const diagnostics: Diagnostic[] = [];

    // Detect hole markers
    const holePatterns = [
        /\b(TODO|FIXME|XXX)\b/g,
        /\.\.\./g,
        /\b(pass)\s*$/gm,
        /@panic\s*\(\s*"(TODO|not implemented)"\s*\)/g,
        /todo!\(\)/g,
        /unimplemented!\(\)/g,
    ];

    for (const pattern of holePatterns) {
        let match;
        while ((match = pattern.exec(text)) !== null) {
            const startPos = document.positionAt(match.index);
            const endPos = document.positionAt(match.index + match[0].length);

            diagnostics.push({
                severity: DiagnosticSeverity.Information,
                range: { start: startPos, end: endPos },
                message: `Typed hole: ${match[0]}`,
                source: 'ananke',
                data: {
                    holeId: `${document.uri}:${startPos.line}:${startPos.character}`,
                    scale: 'expression',
                    strategy: 'llm_complete',
                } as HoleDiagnosticData,
            });
        }
    }

    return diagnostics;
}

export function getHoleCodeActions(
    document: TextDocument,
    diagnostic: Diagnostic
): CodeAction[] {
    const data = diagnostic.data as HoleDiagnosticData;

    return [
        {
            title: 'Fill hole with AI',
            kind: CodeActionKind.QuickFix,
            command: {
                title: 'Fill Hole',
                command: 'ananke.fillHole',
                arguments: [data],
            },
            diagnostics: [diagnostic],
            isPreferred: true,
        },
        {
            title: 'Decompose hole',
            kind: CodeActionKind.Refactor,
            command: {
                title: 'Decompose Hole',
                command: 'ananke.decomposeHole',
                arguments: [data],
            },
            diagnostics: [diagnostic],
        },
    ];
}
```

---

## 8. Phase 7: Integration Testing

### 8.1 End-to-End Test Suite

```zig
// test/integration/typed_holes_test.zig
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

test "end-to-end: detect and fill Python hole" {
    const source =
        \\def calculate_area(width, height):
        \\    # TODO: implement area calculation
        \\    pass
        \\
    ;

    var engine = try ananke.Ananke.init(testing.allocator);
    defer engine.deinit();

    // Detect holes
    var holes = try engine.clew_engine.detectHoles(source, "python");
    defer holes.deinit();

    try testing.expectEqual(@as(usize, 2), holes.holes.items.len);

    // First hole: TODO comment
    const todo_hole = holes.holes.items[0];
    try testing.expectEqual(ananke.types.hole.HoleOrigin.user_marked, todo_hole.origin);

    // Second hole: pass statement
    const pass_hole = holes.holes.items[1];
    try testing.expectEqual(ananke.types.hole.HoleScale.statement, pass_hole.scale);
}

test "end-to-end: constraint satisfaction during fill" {
    // Test that fills satisfy constraints
    // Would require mocked Modal inference
}

test "end-to-end: dependency ordering" {
    // Test that holes are filled in correct order
}
```

### 8.2 VSCode Extension Tests

```typescript
// ananke-vscode/test/suite/holes.test.ts
import * as assert from 'assert';
import * as vscode from 'vscode';

suite('Hole Detection', () => {
    test('Detects Python TODO markers', async () => {
        const doc = await vscode.workspace.openTextDocument({
            content: 'def foo():\n    # TODO: implement\n    pass',
            language: 'python',
        });

        // Trigger hole detection
        await vscode.commands.executeCommand('ananke.detectHoles');

        // Verify diagnostics
        const diagnostics = vscode.languages.getDiagnostics(doc.uri);
        assert.strictEqual(diagnostics.length, 2);
    });

    test('Provides fill code actions', async () => {
        // Test that code actions are provided for holes
    });
});
```

---

## 9. Risk Mitigation

### 9.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| llguidance grammar complexity | Medium | High | Start with simple JSON Schema, add CFG incrementally |
| Modal cold start latency | High | Medium | Pre-warm in VSCode, show progress UI |
| Type inference accuracy | Medium | Medium | Fallback to `any` type, flag for human review |
| Dependency graph cycles | Low | High | Cycle detection and breaking algorithm |
| Diffusion model availability | High | Low | Optional feature, graceful fallback to autoregressive |

### 9.2 Fallback Strategies

1. **If hole detection fails**: Fall back to regex-based detection only
2. **If type inference fails**: Mark hole with `unknown` type, increase human review priority
3. **If fill fails constraints**: Retry with relaxed constraints, then mark for human
4. **If Modal is unavailable**: Queue requests, provide offline mode with cached examples
5. **If diffusion model unavailable**: Use autoregressive for all holes

### 9.3 Rollback Plan

```bash
# If typed holes causes issues in production:

# 1. Disable feature flag
echo "ANANKE_TYPED_HOLES=false" >> .env

# 2. Rollback VSCode extension
cd ananke-vscode
git checkout v0.1.0
npm run package

# 3. Rollback Ananke core
cd ananke
git checkout v0.1.0
zig build

# 4. Document issue and create fix branch
git checkout -b fix/typed-holes-regression
```

---

## 10. Appendix: Technical Specifications

### 10.1 llguidance Grammar Reference Syntax

For cross-hole constraints, use llguidance's grammar reference syntax:

```
# Define a reusable grammar
@expression := /[a-zA-Z_][a-zA-Z0-9_]*/

# Reference in hole spec
hole_1: {
    grammar_ref: "@expression",
    fill_schema: { "type": "string", "pattern": "[a-zA-Z_][a-zA-Z0-9_]*" }
}

# Capture groups for typed holes
foo[hole_type]: @expression  # Captures the fill with name "hole_type"
```

### 10.2 Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Hole detection | <100ms per file | `zig build test` benchmark |
| Hole compilation | <50ms per hole | `zig build test` benchmark |
| Fill generation (AR) | <5s per hole | Modal inference logs |
| Fill generation (Diffusion) | <15s per hole | Modal inference logs |
| VSCode response | <500ms | Extension performance tests |
| LSP hover | <100ms | Language server logs |

### 10.3 File Structure Summary

```
ananke/
├── src/
│   ├── types/
│   │   ├── constraint.zig    # Extended with HoleSpec
│   │   └── hole.zig          # NEW: Core hole types
│   ├── clew/
│   │   ├── clew.zig          # Extended with detectHoles
│   │   └── hole_detector.zig # NEW: Hole detection
│   └── braid/
│       ├── braid.zig         # Extended with compileHoles
│       └── hole_compiler.zig # NEW: Hole compilation
├── maze/
│   └── src/
│       ├── lib.rs            # Extended with refinement
│       ├── progressive_refinement.rs  # NEW: Core refinement loop
│       ├── diffusion.rs      # NEW: Diffusion model support
│       └── model_selector.rs # NEW: Model selection
└── docs/
    └── specs/
        └── TYPED_HOLES_IMPLEMENTATION_PLAN.md  # This document

ananke-vscode/
├── src/
│   ├── providers/
│   │   └── holeProvider.ts   # NEW: Hole visualization
│   ├── commands/
│   │   └── holeCommands.ts   # NEW: Fill commands
│   └── language-server/
│       └── services/
│           └── holes.ts      # NEW: LSP hole support
└── test/
    └── suite/
        └── holes.test.ts     # NEW: Hole tests
```

---

## Approval and Sign-off

- [ ] Architecture review completed
- [ ] Security review (no secrets, safe FFI)
- [ ] Performance benchmarks defined
- [ ] Testing strategy approved
- [ ] VSCode extension guidelines followed

---

*End of Implementation Plan*
