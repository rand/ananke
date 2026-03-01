// Temporal Confidence for Constraints
//
// Maps Homer's temporal analysis (stability classification, centrality trends,
// co-change patterns) to constraint confidence adjustments.
//
// Stability classifications:
//   StableCore   → High confidence, strict constraints
//   ActiveCore   → Medium confidence, allow_relaxation: true
//   StableLeaf   → Medium confidence, standard constraints
//   ActiveLeaf   → Low confidence, prefer grammar/regex over type constraints
//
// Co-change patterns via Jaccard similarity:
//   If file A and file B always change together, generating code in A
//   should include B's current exports in the scope context.

const std = @import("std");
const salience = @import("salience.zig");

/// Homer's stability classification for a code entity.
/// Combines structural importance (centrality) with temporal behavior (churn).
pub const StabilityClass = enum {
    /// High centrality + low churn: core, load-bearing, stable code
    stable_core,
    /// High centrality + high churn: core code under active development
    active_core,
    /// Low centrality + low churn: stable utility/helper code
    stable_leaf,
    /// Low centrality + high churn: peripheral code in flux
    active_leaf,

    /// Derive from a salience score
    pub fn fromSalience(score: salience.SalienceScore) StabilityClass {
        const high_centrality = score.composite >= 0.5;
        const high_churn = score.churn_rate >= 0.5;

        if (high_centrality and !high_churn) return .stable_core;
        if (high_centrality and high_churn) return .active_core;
        if (!high_centrality and !high_churn) return .stable_leaf;
        return .active_leaf;
    }
};

/// Temporal analysis result for a code entity from Homer.
pub const TemporalAnalysis = struct {
    /// Stability classification
    stability: StabilityClass,
    /// Days since last modification
    days_since_modified: u32 = 0,
    /// Number of modifications in the last 90 days
    recent_change_count: u32 = 0,
    /// Centrality trend over time (-1.0 = declining, 0 = stable, +1.0 = increasing)
    centrality_trend: f32 = 0.0,
    /// Co-change partners (file paths that change together, sorted by Jaccard similarity)
    co_change_partners: []const CoChangePartner = &.{},
};

/// A file that frequently changes together with the target file.
pub const CoChangePartner = struct {
    /// Path of the co-changing file
    path: []const u8,
    /// Jaccard similarity coefficient (0.0–1.0)
    jaccard_similarity: f32,
    /// Number of commits where both files changed together
    co_change_count: u32,
};

/// Confidence adjustment based on temporal analysis.
pub const TemporalAdjustment = struct {
    /// Confidence multiplier (0.0–1.0). Applied to constraint confidence.
    confidence_multiplier: f32,
    /// Whether to prefer looser constraint types (grammar/regex vs type constraints)
    prefer_loose_constraints: bool,
    /// Whether constraints should be marked as allowing relaxation
    allow_relaxation: bool,
    /// Additional file paths to include in scope context (from co-change analysis)
    context_partners: []const []const u8,
    /// Source classification for diagnostics
    stability: StabilityClass,
};

/// Map a stability classification to a confidence adjustment.
pub fn adjustConfidence(analysis: TemporalAnalysis) TemporalAdjustment {
    return adjustFromStability(analysis.stability, analysis);
}

/// Map stability class + temporal data to a confidence adjustment.
fn adjustFromStability(stability: StabilityClass, analysis: TemporalAnalysis) TemporalAdjustment {
    // Extract high-similarity co-change partners for context inclusion
    var partner_count: usize = 0;
    for (analysis.co_change_partners) |partner| {
        if (partner.jaccard_similarity >= 0.5) {
            partner_count += 1;
        }
    }
    // We can't allocate here, so we return pointers into the existing slice.
    // Caller must ensure the TemporalAnalysis outlives the TemporalAdjustment.
    var context_paths: [16][]const u8 = undefined;
    var ctx_count: usize = 0;
    for (analysis.co_change_partners) |partner| {
        if (partner.jaccard_similarity >= 0.5 and ctx_count < context_paths.len) {
            context_paths[ctx_count] = partner.path;
            ctx_count += 1;
        }
    }

    const base = switch (stability) {
        .stable_core => TemporalAdjustment{
            .confidence_multiplier = 1.0,
            .prefer_loose_constraints = false,
            .allow_relaxation = false,
            .context_partners = &.{},
            .stability = stability,
        },
        .active_core => TemporalAdjustment{
            .confidence_multiplier = 0.75,
            .prefer_loose_constraints = false,
            .allow_relaxation = true,
            .context_partners = &.{},
            .stability = stability,
        },
        .stable_leaf => TemporalAdjustment{
            .confidence_multiplier = 0.8,
            .prefer_loose_constraints = false,
            .allow_relaxation = false,
            .context_partners = &.{},
            .stability = stability,
        },
        .active_leaf => TemporalAdjustment{
            .confidence_multiplier = 0.5,
            .prefer_loose_constraints = true,
            .allow_relaxation = true,
            .context_partners = &.{},
            .stability = stability,
        },
    };

    // Adjust confidence further based on centrality trend
    var multiplier = base.confidence_multiplier;

    // Declining centrality → code is becoming less important → lower confidence
    if (analysis.centrality_trend < -0.3) {
        multiplier *= 0.9;
    }
    // Increasing centrality → code is becoming more important → raise confidence
    if (analysis.centrality_trend > 0.3) {
        multiplier = @min(multiplier * 1.1, 1.0);
    }

    // Very recently modified code gets a small confidence boost
    // (the developer is actively thinking about it)
    if (analysis.days_since_modified < 7 and analysis.recent_change_count > 0) {
        multiplier = @min(multiplier * 1.05, 1.0);
    }

    return TemporalAdjustment{
        .confidence_multiplier = multiplier,
        .prefer_loose_constraints = base.prefer_loose_constraints,
        .allow_relaxation = base.allow_relaxation,
        .context_partners = base.context_partners,
        .stability = stability,
    };
}

/// Select appropriate constraint strategy based on temporal analysis.
/// Returns whether type constraints should be preferred over grammar/regex.
pub fn shouldPreferTypeConstraints(analysis: TemporalAnalysis) bool {
    return switch (analysis.stability) {
        .stable_core, .stable_leaf => true,
        .active_core => true, // Still important enough
        .active_leaf => false, // Prefer looser constraints
    };
}

/// Check if a file should be included in context based on co-change patterns.
/// Returns the Jaccard similarity if the file is a co-change partner, null otherwise.
pub fn coChangeSimilarity(
    analysis: TemporalAnalysis,
    file_path: []const u8,
) ?f32 {
    for (analysis.co_change_partners) |partner| {
        if (std.mem.eql(u8, partner.path, file_path)) {
            return partner.jaccard_similarity;
        }
    }
    return null;
}

// ---------- Tests ----------

test "stability classification from salience" {
    const stable_core = salience.SalienceScore{
        .composite = 0.8,
        .churn_rate = 0.1,
    };
    try std.testing.expectEqual(StabilityClass.stable_core, StabilityClass.fromSalience(stable_core));

    const active_core = salience.SalienceScore{
        .composite = 0.7,
        .churn_rate = 0.8,
    };
    try std.testing.expectEqual(StabilityClass.active_core, StabilityClass.fromSalience(active_core));

    const stable_leaf = salience.SalienceScore{
        .composite = 0.2,
        .churn_rate = 0.1,
    };
    try std.testing.expectEqual(StabilityClass.stable_leaf, StabilityClass.fromSalience(stable_leaf));

    const active_leaf = salience.SalienceScore{
        .composite = 0.2,
        .churn_rate = 0.9,
    };
    try std.testing.expectEqual(StabilityClass.active_leaf, StabilityClass.fromSalience(active_leaf));
}

test "temporal adjustment: stable core gets full confidence" {
    const analysis = TemporalAnalysis{
        .stability = .stable_core,
        .days_since_modified = 90,
        .recent_change_count = 0,
    };
    const adj = adjustConfidence(analysis);
    try std.testing.expectEqual(@as(f32, 1.0), adj.confidence_multiplier);
    try std.testing.expect(!adj.prefer_loose_constraints);
    try std.testing.expect(!adj.allow_relaxation);
}

test "temporal adjustment: active leaf gets low confidence" {
    const analysis = TemporalAnalysis{
        .stability = .active_leaf,
        .days_since_modified = 2,
        .recent_change_count = 5,
    };
    const adj = adjustConfidence(analysis);
    try std.testing.expect(adj.confidence_multiplier < 0.6);
    try std.testing.expect(adj.prefer_loose_constraints);
    try std.testing.expect(adj.allow_relaxation);
}

test "temporal adjustment: declining centrality lowers confidence" {
    const analysis = TemporalAnalysis{
        .stability = .stable_core,
        .centrality_trend = -0.5,
    };
    const adj = adjustConfidence(analysis);
    try std.testing.expect(adj.confidence_multiplier < 1.0);
}

test "temporal adjustment: increasing centrality raises confidence" {
    const analysis = TemporalAnalysis{
        .stability = .active_core,
        .centrality_trend = 0.5,
    };
    const adj = adjustConfidence(analysis);
    // active_core base is 0.75, * 1.1 = 0.825
    try std.testing.expect(adj.confidence_multiplier > 0.75);
}

test "type constraint preference" {
    try std.testing.expect(shouldPreferTypeConstraints(.{ .stability = .stable_core }));
    try std.testing.expect(shouldPreferTypeConstraints(.{ .stability = .active_core }));
    try std.testing.expect(shouldPreferTypeConstraints(.{ .stability = .stable_leaf }));
    try std.testing.expect(!shouldPreferTypeConstraints(.{ .stability = .active_leaf }));
}

test "co-change similarity lookup" {
    const partners = [_]CoChangePartner{
        .{ .path = "src/auth.py", .jaccard_similarity = 0.8, .co_change_count = 12 },
        .{ .path = "src/models.py", .jaccard_similarity = 0.6, .co_change_count = 8 },
    };
    const analysis = TemporalAnalysis{
        .stability = .stable_core,
        .co_change_partners = &partners,
    };

    const sim = coChangeSimilarity(analysis, "src/auth.py");
    try std.testing.expect(sim != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), sim.?, 0.01);

    const no_sim = coChangeSimilarity(analysis, "src/other.py");
    try std.testing.expect(no_sim == null);
}
