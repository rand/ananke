// Typed holes for progressive code refinement
const std = @import("std");

/// Scale at which a hole operates
pub const HoleScale = enum(u8) {
    expression = 0,
    statement = 1,
    block = 2,
    function = 3,
    module = 4,
    specification = 5,

    pub fn complexity(self: HoleScale) u32 {
        const scale_val = @intFromEnum(self);
        return @as(u32, 1) << (@as(u5, @intCast(scale_val)) * 2);
    }

    pub fn requiresDecomposition(self: HoleScale) bool {
        return @intFromEnum(self) >= @intFromEnum(HoleScale.function);
    }
};

/// Origin of the hole
pub const HoleOrigin = enum {
    user_marked,
    generation_limit,
    constraint_conflict,
    uncertainty,
    structural,
    type_inference_failure,
    decomposition,
};

/// Resolution strategy
pub const ResolutionStrategy = enum {
    llm_complete,
    human_required,
    example_adapt,
    decompose,
    skip,
    template,
    diffusion_refine,
};

/// Confidence scoring
pub const Confidence = struct {
    score: f32,
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

/// Source location
pub const Location = struct {
    file_path: []const u8,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,
};

/// Binding in scope
pub const Binding = struct {
    name: []const u8,
    type_annotation: ?[]const u8,
    is_mutable: bool = false,
};

/// Fill attempt record
pub const FillAttempt = struct {
    fill: []const u8,
    timestamp: i64,
    model: []const u8,
    strategy: ResolutionStrategy,
    confidence: Confidence,
    rejected_reason: ?[]const u8 = null,
};

/// Provenance tracking
pub const Provenance = struct {
    created_at: i64,
    created_by: []const u8,
    source_artifact: ?[]const u8 = null,
    parent_hole_id: ?u64 = null,
};

/// Model generation hints
pub const ModelHints = struct {
    preferred_patterns: []const []const u8 = &.{},
    forbidden_patterns: []const []const u8 = &.{},
    example_fills: []const []const u8 = &.{},
    temperature: ?f32 = null,
    max_tokens: ?u32 = null,
    prefer_diffusion: bool = false,
};

/// A typed hole
pub const Hole = struct {
    id: u64,
    name: ?[]const u8 = null,
    scale: HoleScale,
    origin: HoleOrigin,
    expected_type: ?[]const u8 = null,
    context_type: ?[]const u8 = null,
    available_bindings: []const Binding = &.{},
    constraints: []const @import("constraint.zig").Constraint = &.{},
    resolution_strategy: ResolutionStrategy = .llm_complete,
    priority: u32 = 50,
    confidence: Confidence = .{ .score = 0.0 },
    depends_on: []const u64 = &.{},
    dependents: []const u64 = &.{},
    location: Location,
    current_fill: ?[]const u8 = null,
    fill_history: []const FillAttempt = &.{},
    provenance: Provenance,
    model_hints: ModelHints = .{},

    pub fn isResolved(self: *const Hole) bool {
        return self.current_fill != null and self.confidence.isHighConfidence();
    }

    pub fn canAutoResolve(self: *const Hole) bool {
        return self.resolution_strategy != .human_required and
            self.scale != .specification;
    }
};

/// Collection of holes
pub const HoleSet = struct {
    holes: std.ArrayList(Hole),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HoleSet {
        return .{
            .holes = std.ArrayList(Hole){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HoleSet) void {
        self.holes.deinit(self.allocator);
    }

    pub fn add(self: *HoleSet, hole: Hole) !void {
        try self.holes.append(self.allocator, hole);
    }

    pub fn getUnresolved(self: *const HoleSet) []const *const Hole {
        var unresolved = std.ArrayList(*const Hole){};
        defer unresolved.deinit(self.allocator);

        for (self.holes.items) |*hole| {
            if (!hole.isResolved()) {
                unresolved.append(self.allocator, hole) catch continue;
            }
        }
        return unresolved.toOwnedSlice(self.allocator) catch &.{};
    }
};
