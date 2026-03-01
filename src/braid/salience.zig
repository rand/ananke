// Salience-Informed Constraint Priority
//
// Maps Homer's composite salience scoring and four-quadrant classification
// to constraint priority adjustments and adaptive intensity levels.
//
// The four quadrants (from Homer):
//   High Centrality + Low Churn  = FoundationalStable → FULL_HARD, high confidence
//   High Centrality + High Churn = ActiveHotspot       → FULL, medium confidence
//   Low Centrality  + High Churn = PeripheralActive    → STANDARD
//   Low Centrality  + Low Churn  = QuietLeaf           → SYNTAX_ONLY
//
// This module does NOT query Homer directly. It transforms Homer's analysis
// results into constraint priority adjustments that Braid uses during compilation.

const std = @import("std");

/// Homer's composite salience score for a code entity.
/// Weights: PageRank 30%, Betweenness 15%, HITS 15%, Churn 15%,
///          Bus Factor 10%, Code Size 5%, Test Presence 10%.
pub const SalienceScore = struct {
    /// Composite score (0.0–1.0)
    composite: f32 = 0.0,

    /// Individual components (optional, for debugging)
    pagerank: f32 = 0.0,
    betweenness: f32 = 0.0,
    churn_rate: f32 = 0.0,
    bus_factor: f32 = 0.0,
    has_tests: bool = false,

    /// Derive the four-quadrant classification
    pub fn classify(self: SalienceScore) Quadrant {
        const high_centrality = self.composite >= 0.5;
        const high_churn = self.churn_rate >= 0.5;

        if (high_centrality and !high_churn) return .foundational_stable;
        if (high_centrality and high_churn) return .active_hotspot;
        if (!high_centrality and high_churn) return .peripheral_active;
        return .quiet_leaf;
    }
};

/// Four-quadrant classification from Homer's analysis.
pub const Quadrant = enum {
    /// High centrality, low churn: load-bearing, stable code.
    /// Behavioral analysis misses this; graph centrality catches it.
    foundational_stable,

    /// High centrality, high churn: frequently modified core code.
    active_hotspot,

    /// Low centrality, high churn: peripheral code in flux.
    peripheral_active,

    /// Low centrality, low churn: stable leaf code.
    quiet_leaf,
};

/// Adaptive constraint intensity levels from CLaSH.
pub const IntensityLevel = enum {
    /// No constraints active
    none,
    /// Only syntax domain (grammar conformance)
    syntax_only,
    /// Syntax + Types
    standard,
    /// Syntax + Types + Imports (all hard domains)
    full_hard,
    /// All 5 domains
    full,
    /// All domains + verification hooks
    exhaustive,

    /// Approximate per-token latency budget
    pub fn latencyBudgetUs(self: IntensityLevel) u32 {
        return switch (self) {
            .none => 0,
            .syntax_only => 50,
            .standard => 200,
            .full_hard => 500,
            .full => 2000,
            .exhaustive => 5000,
        };
    }
};

/// Priority adjustment to apply to constraints based on salience.
pub const PriorityAdjustment = struct {
    /// Intensity level for constraint enforcement
    intensity: IntensityLevel,
    /// Confidence multiplier (0.0–1.0). Applied to constraint confidence.
    confidence_multiplier: f32,
    /// Whether constraints on this entity should allow relaxation during conflicts.
    allow_relaxation: bool,
    /// Source quadrant for diagnostics
    quadrant: Quadrant,
};

/// Map a salience score to a priority adjustment.
pub fn adjustPriority(score: SalienceScore) PriorityAdjustment {
    const quadrant = score.classify();
    return adjustFromQuadrant(quadrant, score);
}

/// Map a quadrant classification to a priority adjustment.
pub fn adjustFromQuadrant(quadrant: Quadrant, score: SalienceScore) PriorityAdjustment {
    return switch (quadrant) {
        .foundational_stable => .{
            .intensity = .full_hard,
            .confidence_multiplier = 1.0,
            .allow_relaxation = false,
            .quadrant = quadrant,
        },
        .active_hotspot => .{
            .intensity = .full,
            // Lower confidence for high-churn code — it may change again
            .confidence_multiplier = 0.8,
            .allow_relaxation = false,
            .quadrant = quadrant,
        },
        .peripheral_active => .{
            .intensity = .standard,
            .confidence_multiplier = 0.6,
            .allow_relaxation = true,
            .quadrant = quadrant,
        },
        .quiet_leaf => .{
            // Low centrality + low churn → minimal constraints
            .intensity = if (score.has_tests) .standard else .syntax_only,
            .confidence_multiplier = 0.7,
            .allow_relaxation = true,
            .quadrant = quadrant,
        },
    };
}

/// Apply a priority adjustment to a set of constraint confidence values.
/// Returns adjusted confidences (caller owns returned slice).
pub fn applyConfidenceAdjustment(
    allocator: std.mem.Allocator,
    confidences: []const f32,
    adjustment: PriorityAdjustment,
) ![]f32 {
    const result = try allocator.alloc(f32, confidences.len);
    for (confidences, 0..) |conf, i| {
        result[i] = @min(conf * adjustment.confidence_multiplier, 1.0);
    }
    return result;
}

/// Select the appropriate intensity level for a generation context.
/// Considers: hole scale, salience of surrounding entities, and user override.
pub fn selectIntensity(
    salience_scores: []const SalienceScore,
    user_override: ?IntensityLevel,
) IntensityLevel {
    // User override takes precedence
    if (user_override) |level| return level;

    if (salience_scores.len == 0) return .standard;

    // Use the maximum salience score to determine intensity
    var max_composite: f32 = 0.0;
    var any_foundational = false;
    for (salience_scores) |score| {
        max_composite = @max(max_composite, score.composite);
        if (score.classify() == .foundational_stable) {
            any_foundational = true;
        }
    }

    // If any referenced entity is foundational, use at least full_hard
    if (any_foundational) return .full_hard;

    // Scale intensity with salience
    if (max_composite >= 0.8) return .full;
    if (max_composite >= 0.5) return .full_hard;
    if (max_composite >= 0.2) return .standard;
    return .syntax_only;
}

// ---------- Tests ----------

test "salience classification: foundational stable" {
    const score = SalienceScore{
        .composite = 0.8,
        .pagerank = 0.9,
        .betweenness = 0.7,
        .churn_rate = 0.1,
        .bus_factor = 0.3,
        .has_tests = true,
    };
    try std.testing.expectEqual(Quadrant.foundational_stable, score.classify());

    const adj = adjustPriority(score);
    try std.testing.expectEqual(IntensityLevel.full_hard, adj.intensity);
    try std.testing.expectEqual(@as(f32, 1.0), adj.confidence_multiplier);
    try std.testing.expect(!adj.allow_relaxation);
}

test "salience classification: active hotspot" {
    const score = SalienceScore{
        .composite = 0.7,
        .churn_rate = 0.8,
    };
    try std.testing.expectEqual(Quadrant.active_hotspot, score.classify());

    const adj = adjustPriority(score);
    try std.testing.expectEqual(IntensityLevel.full, adj.intensity);
    try std.testing.expect(!adj.allow_relaxation);
}

test "salience classification: peripheral active" {
    const score = SalienceScore{
        .composite = 0.3,
        .churn_rate = 0.7,
    };
    try std.testing.expectEqual(Quadrant.peripheral_active, score.classify());

    const adj = adjustPriority(score);
    try std.testing.expectEqual(IntensityLevel.standard, adj.intensity);
    try std.testing.expect(adj.allow_relaxation);
}

test "salience classification: quiet leaf" {
    const score = SalienceScore{
        .composite = 0.1,
        .churn_rate = 0.1,
        .has_tests = false,
    };
    try std.testing.expectEqual(Quadrant.quiet_leaf, score.classify());

    const adj = adjustPriority(score);
    try std.testing.expectEqual(IntensityLevel.syntax_only, adj.intensity);
    try std.testing.expect(adj.allow_relaxation);
}

test "quiet leaf with tests gets standard intensity" {
    const score = SalienceScore{
        .composite = 0.1,
        .churn_rate = 0.1,
        .has_tests = true,
    };
    const adj = adjustPriority(score);
    try std.testing.expectEqual(IntensityLevel.standard, adj.intensity);
}

test "confidence adjustment" {
    const confidences = [_]f32{ 0.9, 0.7, 0.5 };
    const adj = PriorityAdjustment{
        .intensity = .standard,
        .confidence_multiplier = 0.6,
        .allow_relaxation = true,
        .quadrant = .peripheral_active,
    };

    const adjusted = try applyConfidenceAdjustment(
        std.testing.allocator,
        &confidences,
        adj,
    );
    defer std.testing.allocator.free(adjusted);

    try std.testing.expectApproxEqAbs(@as(f32, 0.54), adjusted[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.42), adjusted[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), adjusted[2], 0.01);
}

test "intensity selection: foundational entity forces full_hard" {
    const scores = [_]SalienceScore{
        .{ .composite = 0.1, .churn_rate = 0.1 }, // quiet leaf
        .{ .composite = 0.8, .churn_rate = 0.1 }, // foundational stable
    };
    try std.testing.expectEqual(IntensityLevel.full_hard, selectIntensity(&scores, null));
}

test "intensity selection: user override" {
    const scores = [_]SalienceScore{
        .{ .composite = 0.9, .churn_rate = 0.0 },
    };
    try std.testing.expectEqual(IntensityLevel.exhaustive, selectIntensity(&scores, .exhaustive));
}

test "intensity selection: no scores defaults to standard" {
    try std.testing.expectEqual(IntensityLevel.standard, selectIntensity(&.{}, null));
}

test "intensity latency budgets" {
    try std.testing.expect(IntensityLevel.syntax_only.latencyBudgetUs() < IntensityLevel.standard.latencyBudgetUs());
    try std.testing.expect(IntensityLevel.standard.latencyBudgetUs() < IntensityLevel.full.latencyBudgetUs());
}
