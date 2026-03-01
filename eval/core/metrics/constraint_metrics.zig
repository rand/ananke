// CodeIF Constraint Satisfaction Metrics
//
// Implements the four-tier constraint satisfaction framework from CodeIF research
// for evaluating how well generated code satisfies specified constraints.
//
// Metrics:
// - CSR (Complete Satisfaction Rate): Tasks where ALL constraints are fully met
// - SSR (Soft Satisfaction Rate): Average proportion of constraints satisfied per task
// - RSR (Rigorous Satisfaction Rate): Logical coherence weighted by criticality
// - CCSR (Consistent Continuity Rate): Consistency across multiple generations

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Criticality level for constraints (affects RSR weighting)
pub const ConstraintCriticality = enum {
    low,
    medium,
    high,
    critical,

    pub fn weight(self: ConstraintCriticality) f64 {
        return switch (self) {
            .low => 0.5,
            .medium => 1.0,
            .high => 2.0,
            .critical => 4.0,
        };
    }
};

/// Result of evaluating a single constraint
pub const ConstraintEvaluation = struct {
    constraint_id: []const u8,
    constraint_type: []const u8, // "regex", "type", "naming", "structural", etc.
    criticality: ConstraintCriticality,
    satisfied: bool,
    partial_score: f64, // 0.0 to 1.0 for partial satisfaction
    violation_message: ?[]const u8,

    /// For full satisfaction, both satisfied=true and partial_score=1.0
    pub fn isFullySatisfied(self: ConstraintEvaluation) bool {
        return self.satisfied and self.partial_score >= 0.999;
    }
};

/// Results for a single task's constraint evaluation
pub const TaskConstraintResult = struct {
    task_id: []const u8,
    evaluations: []ConstraintEvaluation,
    total_constraints: u32,
    satisfied_constraints: u32,
    partially_satisfied: u32,
    violated_constraints: u32,

    /// Calculate the soft satisfaction rate for this task
    pub fn softSatisfactionRate(self: TaskConstraintResult) f64 {
        if (self.evaluations.len == 0) return 1.0;
        var sum: f64 = 0.0;
        for (self.evaluations) |eval| {
            sum += eval.partial_score;
        }
        return sum / @as(f64, @floatFromInt(self.evaluations.len));
    }

    /// Check if all constraints are completely satisfied
    pub fn isCompletelySatisfied(self: TaskConstraintResult) bool {
        return self.violated_constraints == 0 and
            self.partially_satisfied == 0 and
            self.satisfied_constraints == self.total_constraints;
    }

    /// Calculate weighted score (for RSR)
    pub fn weightedScore(self: TaskConstraintResult) f64 {
        if (self.evaluations.len == 0) return 1.0;
        var weighted_sum: f64 = 0.0;
        var total_weight: f64 = 0.0;
        for (self.evaluations) |eval| {
            const w = eval.criticality.weight();
            weighted_sum += eval.partial_score * w;
            total_weight += w;
        }
        return if (total_weight > 0) weighted_sum / total_weight else 0.0;
    }

    /// Get violations grouped by type
    pub fn violationsByType(self: TaskConstraintResult, allocator: Allocator) !std.StringHashMap(u32) {
        var map = std.StringHashMap(u32).init(allocator);
        for (self.evaluations) |eval| {
            if (!eval.satisfied) {
                const result = try map.getOrPut(eval.constraint_type);
                if (result.found_existing) {
                    result.value_ptr.* += 1;
                } else {
                    result.value_ptr.* = 1;
                }
            }
        }
        return map;
    }
};

/// CodeIF aggregate metrics across all tasks
pub const CodeIFMetrics = struct {
    /// Complete Satisfaction Rate: proportion of tasks with 100% constraint satisfaction
    csr: f64,

    /// Soft Satisfaction Rate: average proportion of constraints satisfied per task
    ssr: f64,

    /// Rigorous Satisfaction Rate: weighted by constraint criticality
    rsr: f64,

    /// Consistent Continuity Satisfaction Rate: consistency across samples (requires multi-sample)
    ccsr: ?f64,

    /// Number of tasks evaluated
    task_count: u32,

    /// Total constraints across all tasks
    total_constraints: u32,

    /// Total satisfied constraints
    satisfied_constraints: u32,

    /// Breakdown by constraint type
    satisfaction_by_type: ?std.StringHashMap(TypeSatisfaction),

    pub const TypeSatisfaction = struct {
        total: u32,
        satisfied: u32,
        rate: f64,
    };

    /// Compute CodeIF metrics from task results
    pub fn compute(allocator: Allocator, results: []const TaskConstraintResult) !CodeIFMetrics {
        if (results.len == 0) {
            return CodeIFMetrics{
                .csr = 0.0,
                .ssr = 0.0,
                .rsr = 0.0,
                .ccsr = null,
                .task_count = 0,
                .total_constraints = 0,
                .satisfied_constraints = 0,
                .satisfaction_by_type = null,
            };
        }

        var completely_satisfied: u32 = 0;
        var ssr_sum: f64 = 0.0;
        var rsr_sum: f64 = 0.0;
        var total_constraints: u32 = 0;
        var satisfied_constraints: u32 = 0;

        // Track by type
        var type_totals = std.StringHashMap(u32).init(allocator);
        defer type_totals.deinit();
        var type_satisfied = std.StringHashMap(u32).init(allocator);
        defer type_satisfied.deinit();

        for (results) |result| {
            // CSR: count completely satisfied tasks
            if (result.isCompletelySatisfied()) {
                completely_satisfied += 1;
            }

            // SSR: sum soft satisfaction rates
            ssr_sum += result.softSatisfactionRate();

            // RSR: sum weighted scores
            rsr_sum += result.weightedScore();

            // Totals
            total_constraints += result.total_constraints;
            satisfied_constraints += result.satisfied_constraints;

            // By type tracking
            for (result.evaluations) |eval| {
                const total_entry = try type_totals.getOrPut(eval.constraint_type);
                if (total_entry.found_existing) {
                    total_entry.value_ptr.* += 1;
                } else {
                    total_entry.value_ptr.* = 1;
                }

                if (eval.satisfied) {
                    const sat_entry = try type_satisfied.getOrPut(eval.constraint_type);
                    if (sat_entry.found_existing) {
                        sat_entry.value_ptr.* += 1;
                    } else {
                        sat_entry.value_ptr.* = 1;
                    }
                }
            }
        }

        const task_count = @as(u32, @intCast(results.len));
        const task_count_f = @as(f64, @floatFromInt(task_count));

        // Build satisfaction by type map
        var sat_by_type = std.StringHashMap(TypeSatisfaction).init(allocator);
        var iter = type_totals.iterator();
        while (iter.next()) |entry| {
            const total = entry.value_ptr.*;
            const satisfied = type_satisfied.get(entry.key_ptr.*) orelse 0;
            try sat_by_type.put(entry.key_ptr.*, TypeSatisfaction{
                .total = total,
                .satisfied = satisfied,
                .rate = @as(f64, @floatFromInt(satisfied)) / @as(f64, @floatFromInt(total)),
            });
        }

        return CodeIFMetrics{
            .csr = @as(f64, @floatFromInt(completely_satisfied)) / task_count_f,
            .ssr = ssr_sum / task_count_f,
            .rsr = rsr_sum / task_count_f,
            .ccsr = null, // Requires multi-sample data
            .task_count = task_count,
            .total_constraints = total_constraints,
            .satisfied_constraints = satisfied_constraints,
            .satisfaction_by_type = sat_by_type,
        };
    }

    /// Compute CCSR from multiple samples per task
    /// CCSR measures how consistently constraints are satisfied across samples
    pub fn computeCCSR(task_sample_results: []const []const TaskConstraintResult) f64 {
        if (task_sample_results.len == 0) return 0.0;

        var consistency_sum: f64 = 0.0;
        var task_count: u32 = 0;

        for (task_sample_results) |samples| {
            if (samples.len < 2) continue; // Need multiple samples

            // For each constraint, check if satisfaction is consistent across samples
            var constraint_consistency: f64 = 0.0;
            var constraint_count: u32 = 0;

            // Assume all samples have same constraints in same order
            if (samples[0].evaluations.len == 0) continue;

            for (0..samples[0].evaluations.len) |ci| {
                var all_satisfied = true;
                var all_violated = true;

                for (samples) |sample| {
                    if (ci >= sample.evaluations.len) continue;
                    if (sample.evaluations[ci].satisfied) {
                        all_violated = false;
                    } else {
                        all_satisfied = false;
                    }
                }

                // Constraint is "consistent" if all samples agree
                if (all_satisfied or all_violated) {
                    constraint_consistency += 1.0;
                }
                constraint_count += 1;
            }

            if (constraint_count > 0) {
                consistency_sum += constraint_consistency / @as(f64, @floatFromInt(constraint_count));
                task_count += 1;
            }
        }

        return if (task_count > 0)
            consistency_sum / @as(f64, @floatFromInt(task_count))
        else
            0.0;
    }

    pub fn deinit(self: *CodeIFMetrics) void {
        if (self.satisfaction_by_type) |*map| {
            map.deinit();
        }
    }

    /// Serialize to JSON
    pub fn toJson(self: CodeIFMetrics, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 512);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.writeAll("{");
        try writer.print("\"csr\":{d:.4},", .{self.csr});
        try writer.print("\"ssr\":{d:.4},", .{self.ssr});
        try writer.print("\"rsr\":{d:.4},", .{self.rsr});

        if (self.ccsr) |ccsr| {
            try writer.print("\"ccsr\":{d:.4},", .{ccsr});
        } else {
            try writer.writeAll("\"ccsr\":null,");
        }

        try writer.print("\"task_count\":{d},", .{self.task_count});
        try writer.print("\"total_constraints\":{d},", .{self.total_constraints});
        try writer.print("\"satisfied_constraints\":{d}", .{self.satisfied_constraints});
        try writer.writeAll("}");

        return buf.toOwnedSlice();
    }
};

/// Compare constraint satisfaction between two evaluation sets (e.g., constrained vs baseline)
pub const ConstraintComparison = struct {
    constrained_csr: f64,
    baseline_csr: f64,
    csr_delta: f64,

    constrained_ssr: f64,
    baseline_ssr: f64,
    ssr_delta: f64,

    /// Tasks where constrained outperformed baseline
    constrained_wins: u32,
    /// Tasks where baseline outperformed constrained
    baseline_wins: u32,
    /// Tasks with equal satisfaction
    ties: u32,

    pub fn compute(constrained: CodeIFMetrics, baseline: CodeIFMetrics) ConstraintComparison {
        return ConstraintComparison{
            .constrained_csr = constrained.csr,
            .baseline_csr = baseline.csr,
            .csr_delta = constrained.csr - baseline.csr,
            .constrained_ssr = constrained.ssr,
            .baseline_ssr = baseline.ssr,
            .ssr_delta = constrained.ssr - baseline.ssr,
            .constrained_wins = 0, // Requires per-task comparison
            .baseline_wins = 0,
            .ties = 0,
        };
    }

    /// Compute per-task wins/losses
    pub fn computeWithTasks(
        constrained_results: []const TaskConstraintResult,
        baseline_results: []const TaskConstraintResult,
    ) ConstraintComparison {
        var wins: u32 = 0;
        var losses: u32 = 0;
        var ties: u32 = 0;

        const min_len = @min(constrained_results.len, baseline_results.len);
        for (0..min_len) |i| {
            const c_ssr = constrained_results[i].softSatisfactionRate();
            const b_ssr = baseline_results[i].softSatisfactionRate();

            if (c_ssr > b_ssr + 0.001) {
                wins += 1;
            } else if (b_ssr > c_ssr + 0.001) {
                losses += 1;
            } else {
                ties += 1;
            }
        }

        var c_csr_sum: f64 = 0.0;
        var c_ssr_sum: f64 = 0.0;
        for (constrained_results) |r| {
            if (r.isCompletelySatisfied()) c_csr_sum += 1.0;
            c_ssr_sum += r.softSatisfactionRate();
        }

        var b_csr_sum: f64 = 0.0;
        var b_ssr_sum: f64 = 0.0;
        for (baseline_results) |r| {
            if (r.isCompletelySatisfied()) b_csr_sum += 1.0;
            b_ssr_sum += r.softSatisfactionRate();
        }

        const c_count = @as(f64, @floatFromInt(constrained_results.len));
        const b_count = @as(f64, @floatFromInt(baseline_results.len));

        const c_csr = if (c_count > 0) c_csr_sum / c_count else 0.0;
        const b_csr = if (b_count > 0) b_csr_sum / b_count else 0.0;
        const c_ssr = if (c_count > 0) c_ssr_sum / c_count else 0.0;
        const b_ssr = if (b_count > 0) b_ssr_sum / b_count else 0.0;

        return ConstraintComparison{
            .constrained_csr = c_csr,
            .baseline_csr = b_csr,
            .csr_delta = c_csr - b_csr,
            .constrained_ssr = c_ssr,
            .baseline_ssr = b_ssr,
            .ssr_delta = c_ssr - b_ssr,
            .constrained_wins = wins,
            .baseline_wins = losses,
            .ties = ties,
        };
    }

    pub fn toJson(self: ConstraintComparison, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 512);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"constrained_csr":{d:.4},"baseline_csr":{d:.4},"csr_delta":{d:.4},"constrained_ssr":{d:.4},"baseline_ssr":{d:.4},"ssr_delta":{d:.4},"constrained_wins":{d},"baseline_wins":{d},"ties":{d}}}
        , .{
            self.constrained_csr,
            self.baseline_csr,
            self.csr_delta,
            self.constrained_ssr,
            self.baseline_ssr,
            self.ssr_delta,
            self.constrained_wins,
            self.baseline_wins,
            self.ties,
        });

        return buf.toOwnedSlice();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "TaskConstraintResult basic" {
    const evals = [_]ConstraintEvaluation{
        .{
            .constraint_id = "c1",
            .constraint_type = "regex",
            .criticality = .medium,
            .satisfied = true,
            .partial_score = 1.0,
            .violation_message = null,
        },
        .{
            .constraint_id = "c2",
            .constraint_type = "type",
            .criticality = .high,
            .satisfied = false,
            .partial_score = 0.5,
            .violation_message = "Type mismatch",
        },
    };

    const result = TaskConstraintResult{
        .task_id = "task1",
        .evaluations = @constCast(&evals),
        .total_constraints = 2,
        .satisfied_constraints = 1,
        .partially_satisfied = 1,
        .violated_constraints = 0,
    };

    try std.testing.expectApproxEqAbs(@as(f64, 0.75), result.softSatisfactionRate(), 0.001);
    try std.testing.expect(!result.isCompletelySatisfied());
}

test "CodeIFMetrics CSR calculation" {
    const evals_full = [_]ConstraintEvaluation{
        .{
            .constraint_id = "c1",
            .constraint_type = "regex",
            .criticality = .medium,
            .satisfied = true,
            .partial_score = 1.0,
            .violation_message = null,
        },
    };

    const evals_partial = [_]ConstraintEvaluation{
        .{
            .constraint_id = "c1",
            .constraint_type = "regex",
            .criticality = .medium,
            .satisfied = false,
            .partial_score = 0.5,
            .violation_message = "Failed",
        },
    };

    const results = [_]TaskConstraintResult{
        .{
            .task_id = "task1",
            .evaluations = @constCast(&evals_full),
            .total_constraints = 1,
            .satisfied_constraints = 1,
            .partially_satisfied = 0,
            .violated_constraints = 0,
        },
        .{
            .task_id = "task2",
            .evaluations = @constCast(&evals_partial),
            .total_constraints = 1,
            .satisfied_constraints = 0,
            .partially_satisfied = 1,
            .violated_constraints = 0,
        },
    };

    const allocator = std.testing.allocator;
    var metrics = try CodeIFMetrics.compute(allocator, &results);
    defer metrics.deinit();

    // CSR: 1 out of 2 tasks completely satisfied = 0.5
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), metrics.csr, 0.001);

    // SSR: (1.0 + 0.5) / 2 = 0.75
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), metrics.ssr, 0.001);
}
