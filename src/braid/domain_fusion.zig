// Distribution-Preserving Domain Fusion
//
// Composes multiple constraint domains into a unified per-token decision
// while preserving the LLM's conditional distribution.
//
// Architecture (from CLaSH algebra and ASAp, NeurIPS 2024):
//
// Hard domains compose by INTERSECTION (exact, binary):
//   valid_tokens = syntax_mask ∩ type_mask ∩ import_mask
//   A token invalid in ANY hard domain is impossible to generate.
//
// Soft domains compose by WEIGHTED REWEIGHTING within the feasible set:
//   logits[t] = base_logits[t] + α·controlflow_score[t] + β·semantic_score[t]
//   for all t in valid_tokens only. Never block — only bias.
//
// CRANE-style adaptive switching (ICML 2025):
//   During chain-of-thought/reasoning tokens: relax to SYNTAX_ONLY
//   During structured output tokens: apply FULL intensity
//   This prevents constraint interference with the LLM's reasoning.
//
// This module defines the fusion strategy. The actual per-token mask
// application happens in the sglang backend (ananke-sglang).

const std = @import("std");
const salience = @import("salience.zig");

/// CLaSH domain tiers.
pub const DomainTier = enum {
    /// Hard constraints define the feasible set. Binary pass/fail.
    hard,
    /// Soft constraints rank within the feasible set. Graded 0.0–1.0.
    soft,
};

/// Individual constraint domains from the CLaSH algebra.
pub const Domain = enum {
    /// Grammar conformance. Compiled to Earley parser / PDA.
    syntax,
    /// Well-typedness of partial program. Compiled to prefix automata.
    types,
    /// Symbol availability from scope graph. Compiled to vocabulary subset.
    imports,
    /// Error handling, async/await, loop structure patterns.
    control_flow,
    /// Behavioral intent: pre/postconditions, invariants.
    semantics,

    pub fn tier(self: Domain) DomainTier {
        return switch (self) {
            .syntax, .types, .imports => .hard,
            .control_flow, .semantics => .soft,
        };
    }
};

/// A per-token mask from a single hard domain.
/// In production, this would be a bitmask over the vocabulary.
/// Here we model it as a set of allowed token indices.
pub const DomainMask = struct {
    domain: Domain,
    /// Allowed token indices (sorted for efficient intersection)
    allowed_tokens: []const u32,
};

/// A per-token score from a single soft domain.
pub const DomainScore = struct {
    domain: Domain,
    /// Score for each candidate token (indexed by position in feasible set)
    scores: []const f32,
    /// Weight for this domain in the final composition
    weight: f32,
};

/// CRANE-style generation phase.
/// Determines which constraint intensity to apply.
pub const GenerationPhase = enum {
    /// Chain-of-thought, planning, reasoning tokens.
    /// Constraints relaxed to avoid interfering with LLM reasoning.
    reasoning,
    /// Structured output: code, JSON, formal content.
    /// Full constraint enforcement.
    structured_output,
    /// Transition between phases (e.g., "```" markers).
    transition,
};

/// Configuration for domain fusion.
pub const FusionConfig = struct {
    /// Base intensity level (from salience analysis)
    intensity: salience.IntensityLevel = .standard,
    /// Weight for ControlFlow domain scores
    control_flow_weight: f32 = 1.0,
    /// Weight for Semantics domain scores
    semantics_weight: f32 = 1.0,
    /// Whether to use CRANE-style adaptive switching
    adaptive_switching: bool = true,
    /// Temperature for soft domain score application (higher = more uniform)
    soft_temperature: f32 = 1.0,
};

/// Result of fusing all domain constraints for a single token position.
pub const FusionResult = struct {
    /// Tokens that survive all hard domain intersections.
    /// Empty means no valid tokens (should trigger relaxation).
    feasible_tokens: []const u32,
    /// Logit adjustments for feasible tokens (from soft domains).
    /// Same length as feasible_tokens.
    logit_adjustments: []const f32,
    /// Which domains were active for this token.
    active_domains: DomainSet,
    /// Whether the feasible set was empty before relaxation.
    required_relaxation: bool,
};

/// Bitset of active domains.
pub const DomainSet = packed struct {
    syntax: bool = false,
    types: bool = false,
    imports: bool = false,
    control_flow: bool = false,
    semantics: bool = false,

    pub fn count(self: DomainSet) u8 {
        var c: u8 = 0;
        if (self.syntax) c += 1;
        if (self.types) c += 1;
        if (self.imports) c += 1;
        if (self.control_flow) c += 1;
        if (self.semantics) c += 1;
        return c;
    }

    pub fn hasHardDomains(self: DomainSet) bool {
        return self.syntax or self.types or self.imports;
    }

    pub fn hasSoftDomains(self: DomainSet) bool {
        return self.control_flow or self.semantics;
    }
};

/// Select which domains are active based on intensity level and generation phase.
pub fn selectActiveDomains(
    intensity: salience.IntensityLevel,
    phase: GenerationPhase,
    adaptive: bool,
) DomainSet {
    // CRANE-style: during reasoning, relax to syntax-only
    if (adaptive and phase == .reasoning) {
        return .{ .syntax = intensity != .none };
    }

    return switch (intensity) {
        .none => .{},
        .syntax_only => .{ .syntax = true },
        .standard => .{ .syntax = true, .types = true },
        .full_hard => .{ .syntax = true, .types = true, .imports = true },
        .full => .{
            .syntax = true,
            .types = true,
            .imports = true,
            .control_flow = true,
            .semantics = true,
        },
        .exhaustive => .{
            .syntax = true,
            .types = true,
            .imports = true,
            .control_flow = true,
            .semantics = true,
        },
    };
}

/// Intersect hard domain masks.
/// Returns the set of token indices valid in ALL hard domains.
/// Caller owns the returned slice.
pub fn intersectHardMasks(
    allocator: std.mem.Allocator,
    masks: []const DomainMask,
) ![]u32 {
    if (masks.len == 0) return &.{};

    // Start with the first mask as the candidate set
    var current = std.ArrayList(u32){};
    errdefer current.deinit(allocator);
    try current.appendSlice(allocator, masks[0].allowed_tokens);

    // Intersect with each subsequent mask
    for (masks[1..]) |mask| {
        var next = std.ArrayList(u32){};
        errdefer next.deinit(allocator);

        // Since both are sorted, use merge-intersect (O(n+m))
        var i: usize = 0;
        var j: usize = 0;
        while (i < current.items.len and j < mask.allowed_tokens.len) {
            if (current.items[i] == mask.allowed_tokens[j]) {
                try next.append(allocator, current.items[i]);
                i += 1;
                j += 1;
            } else if (current.items[i] < mask.allowed_tokens[j]) {
                i += 1;
            } else {
                j += 1;
            }
        }

        current.deinit(allocator);
        current = next;
    }

    return try current.toOwnedSlice(allocator);
}

/// Apply soft domain scores as logit adjustments within the feasible set.
/// Returns logit deltas (same length as feasible_tokens).
/// Caller owns the returned slice.
///
/// Formula: adjustment[i] = Σ (weight_d × score_d[i] / temperature)
///
/// This preserves the LLM's conditional distribution (ASAp insight)
/// while biasing toward convention/semantic conformance.
pub fn applySoftScores(
    allocator: std.mem.Allocator,
    feasible_count: usize,
    scores: []const DomainScore,
    config: FusionConfig,
) ![]f32 {
    const adjustments = try allocator.alloc(f32, feasible_count);
    @memset(adjustments, 0.0);

    for (scores) |score| {
        if (score.scores.len != feasible_count) continue;

        const domain_weight = switch (score.domain) {
            .control_flow => config.control_flow_weight * score.weight,
            .semantics => config.semantics_weight * score.weight,
            else => score.weight,
        };

        for (score.scores, 0..) |s, i| {
            adjustments[i] += domain_weight * s / config.soft_temperature;
        }
    }

    return adjustments;
}

/// Full domain fusion for a single token position.
/// Composes hard masks (intersection) and soft scores (additive reweighting).
/// Caller owns the returned FusionResult's slices.
pub fn fuse(
    allocator: std.mem.Allocator,
    hard_masks: []const DomainMask,
    soft_scores: []const DomainScore,
    config: FusionConfig,
    phase: GenerationPhase,
) !FusionResult {
    const active = selectActiveDomains(config.intensity, phase, config.adaptive_switching);

    // Filter to active hard masks
    var active_hard = std.ArrayList(DomainMask){};
    defer active_hard.deinit(allocator);
    for (hard_masks) |mask| {
        const is_active = switch (mask.domain) {
            .syntax => active.syntax,
            .types => active.types,
            .imports => active.imports,
            else => false,
        };
        if (is_active) try active_hard.append(allocator, mask);
    }

    // Intersect hard masks
    const feasible = try intersectHardMasks(allocator, active_hard.items);
    errdefer allocator.free(feasible);

    const required_relaxation = feasible.len == 0 and active_hard.items.len > 0;

    // Filter to active soft scores
    var active_soft = std.ArrayList(DomainScore){};
    defer active_soft.deinit(allocator);
    for (soft_scores) |score| {
        const is_active = switch (score.domain) {
            .control_flow => active.control_flow,
            .semantics => active.semantics,
            else => false,
        };
        if (is_active) try active_soft.append(allocator, score);
    }

    // Apply soft scores within feasible set
    const adjustments = if (feasible.len > 0 and active_soft.items.len > 0)
        try applySoftScores(allocator, feasible.len, active_soft.items, config)
    else
        try allocator.alloc(f32, feasible.len);

    if (feasible.len > 0 and active_soft.items.len == 0) {
        @memset(adjustments, 0.0);
    }

    return .{
        .feasible_tokens = feasible,
        .logit_adjustments = adjustments,
        .active_domains = active,
        .required_relaxation = required_relaxation,
    };
}

/// Free a FusionResult's owned slices.
pub fn deinitResult(allocator: std.mem.Allocator, result: FusionResult) void {
    allocator.free(result.feasible_tokens);
    allocator.free(result.logit_adjustments);
}

/// Serialize a FusionConfig to JSON for the sglang constraint_spec.
pub fn serializeConfigJson(
    allocator: std.mem.Allocator,
    config: FusionConfig,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("{");
    try writer.print("\"intensity\": \"{s}\"", .{@tagName(config.intensity)});
    try writer.print(", \"control_flow_weight\": {d:.2}", .{config.control_flow_weight});
    try writer.print(", \"semantics_weight\": {d:.2}", .{config.semantics_weight});
    try writer.print(", \"adaptive_switching\": {}", .{config.adaptive_switching});
    try writer.print(", \"soft_temperature\": {d:.2}", .{config.soft_temperature});
    try writer.writeAll("}");

    return try buf.toOwnedSlice(allocator);
}

// ---------- Tests ----------

test "domain tier classification" {
    try std.testing.expectEqual(DomainTier.hard, Domain.syntax.tier());
    try std.testing.expectEqual(DomainTier.hard, Domain.types.tier());
    try std.testing.expectEqual(DomainTier.hard, Domain.imports.tier());
    try std.testing.expectEqual(DomainTier.soft, Domain.control_flow.tier());
    try std.testing.expectEqual(DomainTier.soft, Domain.semantics.tier());
}

test "domain set counting" {
    const full = DomainSet{
        .syntax = true,
        .types = true,
        .imports = true,
        .control_flow = true,
        .semantics = true,
    };
    try std.testing.expectEqual(@as(u8, 5), full.count());
    try std.testing.expect(full.hasHardDomains());
    try std.testing.expect(full.hasSoftDomains());

    const empty = DomainSet{};
    try std.testing.expectEqual(@as(u8, 0), empty.count());
    try std.testing.expect(!empty.hasHardDomains());
    try std.testing.expect(!empty.hasSoftDomains());
}

test "active domain selection: intensity levels" {
    const none = selectActiveDomains(.none, .structured_output, false);
    try std.testing.expectEqual(@as(u8, 0), none.count());

    const syntax = selectActiveDomains(.syntax_only, .structured_output, false);
    try std.testing.expectEqual(@as(u8, 1), syntax.count());
    try std.testing.expect(syntax.syntax);

    const standard = selectActiveDomains(.standard, .structured_output, false);
    try std.testing.expectEqual(@as(u8, 2), standard.count());

    const full_hard = selectActiveDomains(.full_hard, .structured_output, false);
    try std.testing.expectEqual(@as(u8, 3), full_hard.count());

    const full = selectActiveDomains(.full, .structured_output, false);
    try std.testing.expectEqual(@as(u8, 5), full.count());
}

test "CRANE-style adaptive switching: reasoning relaxes to syntax-only" {
    const reasoning = selectActiveDomains(.full, .reasoning, true);
    try std.testing.expectEqual(@as(u8, 1), reasoning.count());
    try std.testing.expect(reasoning.syntax);
    try std.testing.expect(!reasoning.types);
    try std.testing.expect(!reasoning.control_flow);

    // Without adaptive switching, reasoning gets full intensity
    const no_adapt = selectActiveDomains(.full, .reasoning, false);
    try std.testing.expectEqual(@as(u8, 5), no_adapt.count());
}

test "hard mask intersection: two masks" {
    const mask1 = DomainMask{
        .domain = .syntax,
        .allowed_tokens = &[_]u32{ 1, 3, 5, 7, 9 },
    };
    const mask2 = DomainMask{
        .domain = .types,
        .allowed_tokens = &[_]u32{ 2, 3, 5, 8, 9, 10 },
    };

    const result = try intersectHardMasks(std.testing.allocator, &[_]DomainMask{ mask1, mask2 });
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(u32, 3), result[0]);
    try std.testing.expectEqual(@as(u32, 5), result[1]);
    try std.testing.expectEqual(@as(u32, 9), result[2]);
}

test "hard mask intersection: three masks" {
    const masks = [_]DomainMask{
        .{ .domain = .syntax, .allowed_tokens = &[_]u32{ 1, 2, 3, 4, 5 } },
        .{ .domain = .types, .allowed_tokens = &[_]u32{ 2, 3, 5, 7 } },
        .{ .domain = .imports, .allowed_tokens = &[_]u32{ 3, 5 } },
    };

    const result = try intersectHardMasks(std.testing.allocator, &masks);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(u32, 3), result[0]);
    try std.testing.expectEqual(@as(u32, 5), result[1]);
}

test "hard mask intersection: empty result" {
    const masks = [_]DomainMask{
        .{ .domain = .syntax, .allowed_tokens = &[_]u32{ 1, 2 } },
        .{ .domain = .types, .allowed_tokens = &[_]u32{ 3, 4 } },
    };

    const result = try intersectHardMasks(std.testing.allocator, &masks);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "soft score application: weighted additive" {
    const scores = [_]DomainScore{
        .{
            .domain = .control_flow,
            .scores = &[_]f32{ 0.5, -0.2, 0.8 },
            .weight = 1.0,
        },
        .{
            .domain = .semantics,
            .scores = &[_]f32{ 0.3, 0.1, -0.4 },
            .weight = 1.0,
        },
    };

    const config = FusionConfig{};
    const adjustments = try applySoftScores(std.testing.allocator, 3, &scores, config);
    defer std.testing.allocator.free(adjustments);

    // controlflow[0] * 1.0 + semantics[0] * 1.0 = 0.5 + 0.3 = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), adjustments[0], 0.01);
    // 0.0 + (-0.2 + 0.1) = -0.1
    try std.testing.expectApproxEqAbs(@as(f32, -0.1), adjustments[1], 0.01);
    // 0.8 + (-0.4) = 0.4
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), adjustments[2], 0.01);
}

test "soft score application: custom weights" {
    const scores = [_]DomainScore{
        .{
            .domain = .control_flow,
            .scores = &[_]f32{ 1.0, 1.0 },
            .weight = 1.0,
        },
        .{
            .domain = .semantics,
            .scores = &[_]f32{ 1.0, 1.0 },
            .weight = 1.0,
        },
    };

    const config = FusionConfig{
        .control_flow_weight = 0.8,
        .semantics_weight = 0.4,
    };
    const adjustments = try applySoftScores(std.testing.allocator, 2, &scores, config);
    defer std.testing.allocator.free(adjustments);

    // controlflow: 0.8 * 1.0 * 1.0 = 0.8, semantics: 0.4 * 1.0 * 1.0 = 0.4, total = 1.2
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), adjustments[0], 0.01);
}

test "full fusion: hard + soft" {
    const hard_masks = [_]DomainMask{
        .{ .domain = .syntax, .allowed_tokens = &[_]u32{ 1, 3, 5, 7 } },
        .{ .domain = .types, .allowed_tokens = &[_]u32{ 3, 5, 9 } },
    };
    const soft_scores = [_]DomainScore{
        .{
            .domain = .control_flow,
            .scores = &[_]f32{ 0.5, -0.3 }, // 2 scores for 2 feasible tokens
            .weight = 1.0,
        },
    };

    const config = FusionConfig{ .intensity = .full };
    const result = try fuse(std.testing.allocator, &hard_masks, &soft_scores, config, .structured_output);
    defer deinitResult(std.testing.allocator, result);

    // Feasible: intersection of {1,3,5,7} ∩ {3,5,9} = {3,5}
    try std.testing.expectEqual(@as(usize, 2), result.feasible_tokens.len);
    try std.testing.expectEqual(@as(u32, 3), result.feasible_tokens[0]);
    try std.testing.expectEqual(@as(u32, 5), result.feasible_tokens[1]);

    // Soft adjustments applied
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.logit_adjustments[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -0.3), result.logit_adjustments[1], 0.01);

    try std.testing.expect(!result.required_relaxation);
    try std.testing.expectEqual(@as(u8, 5), result.active_domains.count());
}

test "fusion: reasoning phase relaxes to syntax-only" {
    const hard_masks = [_]DomainMask{
        .{ .domain = .syntax, .allowed_tokens = &[_]u32{ 1, 2, 3 } },
        .{ .domain = .types, .allowed_tokens = &[_]u32{2} },
    };
    const soft_scores = [_]DomainScore{
        .{ .domain = .control_flow, .scores = &[_]f32{ 0.5, 0.5, 0.5 }, .weight = 1.0 },
    };

    const config = FusionConfig{ .intensity = .full, .adaptive_switching = true };
    const result = try fuse(std.testing.allocator, &hard_masks, &soft_scores, config, .reasoning);
    defer deinitResult(std.testing.allocator, result);

    // In reasoning mode with adaptive switching:
    // Only syntax is active → feasible = {1, 2, 3} (type mask ignored)
    try std.testing.expectEqual(@as(usize, 3), result.feasible_tokens.len);
    // Soft domains not active in reasoning mode
    try std.testing.expectEqual(@as(u8, 1), result.active_domains.count());
    try std.testing.expect(result.active_domains.syntax);
    try std.testing.expect(!result.active_domains.types);
    try std.testing.expect(!result.active_domains.control_flow);
}

test "fusion: empty feasible set signals relaxation needed" {
    const hard_masks = [_]DomainMask{
        .{ .domain = .syntax, .allowed_tokens = &[_]u32{ 1, 2 } },
        .{ .domain = .types, .allowed_tokens = &[_]u32{ 3, 4 } },
    };

    const config = FusionConfig{ .intensity = .full };
    const result = try fuse(std.testing.allocator, &hard_masks, &[_]DomainScore{}, config, .structured_output);
    defer deinitResult(std.testing.allocator, result);

    try std.testing.expectEqual(@as(usize, 0), result.feasible_tokens.len);
    try std.testing.expect(result.required_relaxation);
}

test "serialize fusion config" {
    const config = FusionConfig{
        .intensity = .full,
        .control_flow_weight = 0.8,
        .semantics_weight = 0.4,
        .adaptive_switching = true,
        .soft_temperature = 1.5,
    };

    const json = try serializeConfigJson(std.testing.allocator, config);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"intensity\": \"full\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"adaptive_switching\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"soft_temperature\": 1.50") != null);
}
