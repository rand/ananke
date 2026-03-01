// Constraint Feasibility Analyzer
// Analyzes constraint sets to detect:
// - Mutual exclusions (constraints that can't both be satisfied)
// - Ordering violations (circular dependencies)
// - Semantic conflicts (e.g., "must use X" vs "must not use X")
// - Overall tightness (how restrictive the constraint set is)

const std = @import("std");
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintID = root.types.constraint.ConstraintID;
const ConstraintKind = root.types.constraint.ConstraintKind;

/// Types of conflicts that can occur between constraints
pub const ConflictType = enum {
    /// Constraints are mutually exclusive - can't both be satisfied
    mutual_exclusion,
    /// Constraint A requires B but B requires A (circular)
    ordering_violation,
    /// Semantic contradiction: "must use X" vs "must not use X"
    semantic_conflict,
};

/// A pair of constraints that are in conflict
pub const ConflictPair = struct {
    constraint_a: ConstraintID,
    constraint_b: ConstraintID,
    conflict_type: ConflictType,
    description: []const u8,
};

/// Result of feasibility analysis
pub const FeasibilityResult = struct {
    /// Whether the constraint set can be satisfied
    is_feasible: bool,
    /// List of conflicting constraint pairs
    conflicts: []const ConflictPair,
    /// How restrictive the constraints are (0.0 = loose, 1.0 = very tight)
    tightness_score: f32,
    /// Estimated number of valid outputs that could satisfy constraints
    estimated_valid_outputs: u64,
    /// Warning messages about the constraint set
    warnings: []const []const u8,
};

/// Analyzer for constraint set feasibility
pub const FeasibilityAnalyzer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FeasibilityAnalyzer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FeasibilityAnalyzer) void {
        _ = self;
    }

    /// Analyze a constraint set for feasibility
    pub fn analyze(self: *FeasibilityAnalyzer, constraints: []const Constraint) FeasibilityResult {
        var conflicts = std.ArrayList(ConflictPair){};
        var warnings = std.ArrayList([]const u8){};

        // Find mutual exclusions and semantic conflicts
        self.findConflicts(constraints, &conflicts) catch {};

        // Calculate tightness score
        const tightness = estimateTightness(constraints);

        // Add warnings for tight constraints
        if (tightness > 0.9) {
            warnings.append(self.allocator, "Constraint set is very tight (>90%), generation may be slow or impossible") catch {};
        } else if (tightness > 0.7) {
            warnings.append(self.allocator, "Constraint set is moderately tight, consider relaxing some constraints") catch {};
        }

        // Check for potential issues
        if (constraints.len > 10) {
            warnings.append(self.allocator, "Large constraint set (>10 constraints) may cause slow generation") catch {};
        }

        const is_feasible = conflicts.items.len == 0;

        return FeasibilityResult{
            .is_feasible = is_feasible,
            .conflicts = conflicts.toOwnedSlice(self.allocator) catch &.{},
            .tightness_score = tightness,
            .estimated_valid_outputs = estimateValidOutputs(tightness),
            .warnings = warnings.toOwnedSlice(self.allocator) catch &.{},
        };
    }

    /// Find conflicting constraints in the set
    fn findConflicts(self: *FeasibilityAnalyzer, constraints: []const Constraint, conflicts: *std.ArrayList(ConflictPair)) !void {
        // Check each pair of constraints
        for (constraints, 0..) |a, i| {
            for (constraints[i + 1 ..]) |b| {
                if (areMutuallyExclusive(a, b)) {
                    try conflicts.append(self.allocator, ConflictPair{
                        .constraint_a = a.id,
                        .constraint_b = b.id,
                        .conflict_type = .mutual_exclusion,
                        .description = "Constraints are mutually exclusive",
                    });
                } else if (haveSemanticConflict(a, b)) {
                    try conflicts.append(self.allocator, ConflictPair{
                        .constraint_a = a.id,
                        .constraint_b = b.id,
                        .conflict_type = .semantic_conflict,
                        .description = "Constraints have semantic conflict (must use vs must not use)",
                    });
                }
            }
        }
    }

    /// Check if two constraints are mutually exclusive
    fn areMutuallyExclusive(a: Constraint, b: Constraint) bool {
        // Same kind constraints with conflicting requirements
        if (a.kind == b.kind) {
            // Check for direct negation in descriptions
            const a_must = std.mem.indexOf(u8, a.description, "must be") != null;
            const b_must_not = std.mem.indexOf(u8, b.description, "must not be") != null;

            if (a_must and b_must_not) {
                return referToSameTarget(a.description, b.description);
            }

            const b_must = std.mem.indexOf(u8, b.description, "must be") != null;
            const a_must_not = std.mem.indexOf(u8, a.description, "must not be") != null;

            if (b_must and a_must_not) {
                return referToSameTarget(a.description, b.description);
            }
        }

        return false;
    }

    /// Check if two constraints have a semantic conflict
    fn haveSemanticConflict(a: Constraint, b: Constraint) bool {
        // "must use X" vs "must not use X" patterns
        const patterns = [_]struct { positive: []const u8, negative: []const u8 }{
            .{ .positive = "must use", .negative = "must not use" },
            .{ .positive = "requires", .negative = "forbids" },
            .{ .positive = "must include", .negative = "must exclude" },
            .{ .positive = "must contain", .negative = "cannot contain" },
        };

        for (patterns) |pattern| {
            const a_positive = std.mem.indexOf(u8, a.description, pattern.positive) != null;
            const b_negative = std.mem.indexOf(u8, b.description, pattern.negative) != null;

            if (a_positive and b_negative) {
                return referToSameTarget(a.description, b.description);
            }

            const b_positive = std.mem.indexOf(u8, b.description, pattern.positive) != null;
            const a_negative = std.mem.indexOf(u8, a.description, pattern.negative) != null;

            if (b_positive and a_negative) {
                return referToSameTarget(a.description, b.description);
            }
        }

        return false;
    }

    /// Check if two constraint descriptions refer to the same target
    fn referToSameTarget(desc_a: []const u8, desc_b: []const u8) bool {
        const keywords = [_][]const u8{
            "async",  "await",     "return",    "throw",
            "try",    "catch",     "finally",   "class",
            "function", "const",   "let",       "var",
            "null",   "undefined", "error",     "Result",
            "Option",
        };

        for (keywords) |keyword| {
            const in_a = std.mem.indexOf(u8, desc_a, keyword) != null;
            const in_b = std.mem.indexOf(u8, desc_b, keyword) != null;

            if (in_a and in_b) {
                return true;
            }
        }

        return false;
    }
};

/// Estimate how tight/restrictive the constraint set is
fn estimateTightness(constraints: []const Constraint) f32 {
    if (constraints.len == 0) return 0.0;

    var total_tightness: f32 = 0.0;

    for (constraints) |c| {
        const base_tightness: f32 = switch (c.kind) {
            .syntactic => 0.1,
            .type_safety => 0.15,
            .semantic => 0.2,
            .architectural => 0.25,
            .operational => 0.2,
            .security => 0.3,
        };

        var modifier: f32 = 1.0;
        if (std.mem.indexOf(u8, c.description, "must") != null) modifier *= 1.2;
        if (std.mem.indexOf(u8, c.description, "exact") != null) modifier *= 1.5;
        if (std.mem.indexOf(u8, c.description, "only") != null) modifier *= 1.3;
        if (std.mem.indexOf(u8, c.description, "any") != null) modifier *= 0.7;

        total_tightness += base_tightness * modifier;
    }

    return @min(total_tightness, 1.0);
}

/// Estimate the number of valid outputs based on tightness
fn estimateValidOutputs(tightness: f32) u64 {
    const base: f64 = 1e12;
    const min_val: f64 = 1e3;
    const range = @log(base / min_val);
    const result = base / @exp(range * @as(f64, tightness));
    // Cap at a reasonable maximum (10^15) to avoid f64→u64 overflow
    return @intFromFloat(@min(result, 1e15));
}

// ---- Community-Aware Feasibility (Homer Integration) ----

/// Community membership of a code entity from Homer's Louvain analysis.
pub const EntityCommunity = struct {
    /// File path or entity identifier
    path: []const u8,
    /// Louvain community ID
    community_id: u32,
};

/// Coupling strength between two communities.
pub const CommunityCoupling = struct {
    community_a: u32,
    community_b: u32,
    /// Historical coupling strength (0.0 = independent, 1.0 = tightly coupled)
    coupling_strength: f32,
};

/// Community context from Homer's graph analysis.
pub const CommunityContext = struct {
    /// Community assignments for entities referenced by constraints
    entities: []const EntityCommunity,
    /// Inter-community coupling strengths
    couplings: []const CommunityCoupling,
};

/// A tension detected when constraints force coupling across communities.
pub const CommunityTension = struct {
    constraint_id: ConstraintID,
    source_community: u32,
    target_community: u32,
    coupling_strength: f32,
    description: []const u8,
};

/// Which constraint to relax first when the constraint set is infeasible.
/// Lower number = relax first. Import constraints relax before type constraints,
/// which relax before security constraints.
pub const RelaxationPriority = struct {
    constraint_id: ConstraintID,
    priority: u8,
    reason: []const u8,

    /// Lower priority = relax first
    pub fn lessThan(_: void, a: RelaxationPriority, b: RelaxationPriority) bool {
        return a.priority < b.priority;
    }
};

/// Result of community-aware feasibility analysis.
pub const CommunityFeasibilityResult = struct {
    /// Base feasibility result
    base: FeasibilityResult,
    /// Cross-community tensions detected
    tensions: []const CommunityTension,
    /// Suggested relaxation order (import → type → semantic → security)
    relaxation_order: []const RelaxationPriority,
};

/// Analyze constraints with community context from Homer.
/// Detects cross-community coupling tensions and provides relaxation ordering.
pub fn analyzeWithCommunities(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
    community: CommunityContext,
) CommunityFeasibilityResult {
    var analyzer = FeasibilityAnalyzer.init(allocator);
    defer analyzer.deinit();

    const base = analyzer.analyze(constraints);

    var tensions = std.ArrayList(CommunityTension){};
    var relaxation = std.ArrayList(RelaxationPriority){};

    // Check each constraint for cross-community coupling
    for (constraints) |c| {
        const source = findCommunity(community.entities, c.name);
        const target = findCommunityFromDescription(community.entities, c.description);

        if (source != null and target != null and source.? != target.?) {
            const coupling = lookupCoupling(
                community.couplings,
                source.?,
                target.?,
            );

            // Low coupling across communities = architectural tension
            if (coupling < 0.3) {
                tensions.append(allocator, CommunityTension{
                    .constraint_id = c.id,
                    .source_community = source.?,
                    .target_community = target.?,
                    .coupling_strength = coupling,
                    .description = "Cross-community constraint with low historical coupling",
                }) catch {};
            }
        }

        // Build relaxation priority based on kind
        const priority: u8 = switch (c.kind) {
            .syntactic => 20, // Cosmetic — relax early
            .type_safety => 50, // Important — relax reluctantly
            .semantic => 40, // Behavioral — moderate
            .architectural => 30, // Structural — relax before types
            .operational => 35, // Operational — moderate
            .security => 90, // Safety — relax last
        };

        // Cross-community import tensions lower the priority (relax sooner)
        var adjusted_priority = priority;
        if (source != null and target != null and source.? != target.?) {
            const coupling = lookupCoupling(community.couplings, source.?, target.?);
            if (coupling < 0.3 and c.kind == .architectural) {
                adjusted_priority = 10; // Relax first when crossing low-coupling communities
            }
        }

        relaxation.append(allocator, RelaxationPriority{
            .constraint_id = c.id,
            .priority = adjusted_priority,
            .reason = switch (c.kind) {
                .syntactic => "cosmetic constraint",
                .type_safety => "type safety constraint",
                .semantic => "behavioral constraint",
                .architectural => if (adjusted_priority == 10) "low-coupling cross-community import" else "structural constraint",
                .operational => "operational constraint",
                .security => "security constraint",
            },
        }) catch {};
    }

    // Sort relaxation order
    const owned_relaxation = relaxation.toOwnedSlice(allocator) catch &.{};
    std.mem.sort(RelaxationPriority, @constCast(owned_relaxation), {}, RelaxationPriority.lessThan);

    return CommunityFeasibilityResult{
        .base = base,
        .tensions = tensions.toOwnedSlice(allocator) catch &.{},
        .relaxation_order = owned_relaxation,
    };
}

/// Find the community ID for an entity by path prefix match.
fn findCommunity(entities: []const EntityCommunity, name: []const u8) ?u32 {
    for (entities) |e| {
        if (std.mem.indexOf(u8, name, e.path) != null or
            std.mem.indexOf(u8, e.path, name) != null)
        {
            return e.community_id;
        }
    }
    return null;
}

/// Find community referenced in a constraint description.
fn findCommunityFromDescription(entities: []const EntityCommunity, description: []const u8) ?u32 {
    for (entities) |e| {
        if (std.mem.indexOf(u8, description, e.path) != null) {
            return e.community_id;
        }
    }
    return null;
}

/// Look up coupling strength between two communities.
fn lookupCoupling(couplings: []const CommunityCoupling, a: u32, b: u32) f32 {
    for (couplings) |c| {
        if ((c.community_a == a and c.community_b == b) or
            (c.community_a == b and c.community_b == a))
        {
            return c.coupling_strength;
        }
    }
    return 0.0; // No recorded coupling = independent
}

/// Convenience function to analyze and log warnings
pub fn analyzeAndWarn(allocator: std.mem.Allocator, constraints: []const Constraint) FeasibilityResult {
    var analyzer = FeasibilityAnalyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(constraints);

    if (!result.is_feasible) {
        std.log.warn("Constraint set is infeasible - found {d} conflicts", .{result.conflicts.len});
        for (result.conflicts) |conflict| {
            std.log.warn("  Conflict: constraints {d} and {d} - {s}", .{
                conflict.constraint_a,
                conflict.constraint_b,
                @tagName(conflict.conflict_type),
            });
        }
    }

    if (result.tightness_score > 0.9) {
        std.log.warn("Constraint set is very tight ({d:.0}%), generation may timeout", .{result.tightness_score * 100});
    }

    for (result.warnings) |warning| {
        std.log.warn("Feasibility warning: {s}", .{warning});
    }

    return result;
}

test "empty constraints are feasible" {
    var analyzer = FeasibilityAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&.{});

    try std.testing.expect(result.is_feasible);
    try std.testing.expect(result.tightness_score == 0.0);
    try std.testing.expect(result.conflicts.len == 0);
}

test "single constraint is feasible" {
    var analyzer = FeasibilityAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const constraints = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "test",
            .description = "must use async",
            .kind = .syntactic,
        },
    };

    const result = analyzer.analyze(&constraints);

    try std.testing.expect(result.is_feasible);
    try std.testing.expect(result.tightness_score > 0.0);
}

test "tightness increases with more constraints" {
    var analyzer = FeasibilityAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const single = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "test1",
            .description = "must use async",
            .kind = .syntactic,
        },
    };

    const multiple = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "test1",
            .description = "must use async",
            .kind = .syntactic,
        },
        Constraint{
            .id = 2,
            .name = "test2",
            .description = "must use await",
            .kind = .syntactic,
        },
        Constraint{
            .id = 3,
            .name = "test3",
            .description = "must handle errors",
            .kind = .security,
        },
    };

    const result_single = analyzer.analyze(&single);
    const result_multiple = analyzer.analyze(&multiple);

    try std.testing.expect(result_multiple.tightness_score > result_single.tightness_score);
}

test "community-aware: cross-community tension detected" {
    const entities = [_]EntityCommunity{
        .{ .path = "auth", .community_id = 1 },
        .{ .path = "billing", .community_id = 2 },
    };
    const couplings = [_]CommunityCoupling{
        .{ .community_a = 1, .community_b = 2, .coupling_strength = 0.1 },
    };
    const community = CommunityContext{
        .entities = &entities,
        .couplings = &couplings,
    };

    const constraints = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "auth",
            .description = "must import billing module",
            .kind = .architectural,
        },
    };

    const result = analyzeWithCommunities(std.testing.allocator, &constraints, community);
    defer {
        std.testing.allocator.free(result.tensions);
        std.testing.allocator.free(result.relaxation_order);
        if (result.base.conflicts.len > 0) std.testing.allocator.free(result.base.conflicts);
        if (result.base.warnings.len > 0) std.testing.allocator.free(result.base.warnings);
    }

    try std.testing.expect(result.tensions.len == 1);
    try std.testing.expect(result.tensions[0].coupling_strength < 0.3);
    try std.testing.expectEqual(@as(u32, 1), result.tensions[0].source_community);
    try std.testing.expectEqual(@as(u32, 2), result.tensions[0].target_community);
}

test "community-aware: relaxation prefers imports over types" {
    const entities = [_]EntityCommunity{
        .{ .path = "api", .community_id = 1 },
        .{ .path = "db", .community_id = 2 },
    };
    const couplings = [_]CommunityCoupling{
        .{ .community_a = 1, .community_b = 2, .coupling_strength = 0.1 },
    };
    const community = CommunityContext{
        .entities = &entities,
        .couplings = &couplings,
    };

    const constraints = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "api",
            .description = "must import db connection pool",
            .kind = .architectural,
        },
        Constraint{
            .id = 2,
            .name = "api",
            .description = "return type must be Result<T, Error>",
            .kind = .type_safety,
        },
        Constraint{
            .id = 3,
            .name = "api",
            .description = "must validate auth token",
            .kind = .security,
        },
    };

    const result = analyzeWithCommunities(std.testing.allocator, &constraints, community);
    defer {
        std.testing.allocator.free(result.tensions);
        std.testing.allocator.free(result.relaxation_order);
        if (result.base.conflicts.len > 0) std.testing.allocator.free(result.base.conflicts);
        if (result.base.warnings.len > 0) std.testing.allocator.free(result.base.warnings);
    }

    // Relaxation order: architectural import (10) < type_safety (50) < security (90)
    try std.testing.expect(result.relaxation_order.len == 3);
    try std.testing.expect(result.relaxation_order[0].priority < result.relaxation_order[1].priority);
    try std.testing.expect(result.relaxation_order[1].priority < result.relaxation_order[2].priority);
    // First to relax should be the cross-community import
    try std.testing.expectEqual(@as(u8, 10), result.relaxation_order[0].priority);
}

test "community-aware: tightly coupled communities don't flag tension" {
    const entities = [_]EntityCommunity{
        .{ .path = "models", .community_id = 1 },
        .{ .path = "views", .community_id = 1 }, // Same community
    };
    const couplings = [_]CommunityCoupling{};
    const community = CommunityContext{
        .entities = &entities,
        .couplings = &couplings,
    };

    const constraints = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "models",
            .description = "must import views renderer",
            .kind = .architectural,
        },
    };

    const result = analyzeWithCommunities(std.testing.allocator, &constraints, community);
    defer {
        std.testing.allocator.free(result.tensions);
        std.testing.allocator.free(result.relaxation_order);
        if (result.base.conflicts.len > 0) std.testing.allocator.free(result.base.conflicts);
        if (result.base.warnings.len > 0) std.testing.allocator.free(result.base.warnings);
    }

    // Same community = no tension
    try std.testing.expect(result.tensions.len == 0);
}

test "security constraints are tighter than syntactic" {
    var analyzer = FeasibilityAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const syntactic = [_]Constraint{
        Constraint{
            .id = 1,
            .name = "test1",
            .description = "format code",
            .kind = .syntactic,
        },
    };

    const security = [_]Constraint{
        Constraint{
            .id = 2,
            .name = "test2",
            .description = "validate input",
            .kind = .security,
        },
    };

    const result_syntactic = analyzer.analyze(&syntactic);
    const result_security = analyzer.analyze(&security);

    try std.testing.expect(result_security.tightness_score > result_syntactic.tightness_score);
}
