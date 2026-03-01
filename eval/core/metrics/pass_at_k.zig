// Pass@k Metrics for Code Generation Evaluation
//
// Implements the unbiased pass@k estimator from the HumanEval paper:
// "Evaluating Large Language Models Trained on Code" (Chen et al., 2021)
//
// pass@k = 1 - C(n-c, k) / C(n, k)
// Where n = total samples, c = correct samples, k = samples to consider
//
// This metric answers: "What is the probability that at least one of k
// samples passes all tests?"

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Result of a single generation sample
pub const SampleResult = struct {
    sample_id: u32,
    passed_all_tests: bool,
    tests_passed: u32,
    tests_total: u32,
    constraints_satisfied: u32,
    constraints_total: u32,
    generation_time_ms: u64,
    code: []const u8,

    pub fn passRate(self: SampleResult) f64 {
        if (self.tests_total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.tests_passed)) / @as(f64, @floatFromInt(self.tests_total));
    }

    pub fn constraintSatisfactionRate(self: SampleResult) f64 {
        if (self.constraints_total == 0) return 1.0; // No constraints = all satisfied
        return @as(f64, @floatFromInt(self.constraints_satisfied)) / @as(f64, @floatFromInt(self.constraints_total));
    }
};

/// Collection of samples for a single task
pub const TaskSamples = struct {
    task_id: []const u8,
    samples: []SampleResult,
    total_samples: u32,
    correct_samples: u32, // Samples that pass ALL tests

    /// Calculate pass@k for various k values
    pub fn passAtK(self: TaskSamples, k: u32) f64 {
        return computePassAtK(self.total_samples, self.correct_samples, k);
    }

    /// Get pass@1 (most commonly reported metric)
    pub fn passAt1(self: TaskSamples) f64 {
        return self.passAtK(1);
    }

    /// Get pass@5 (common for comparing models)
    pub fn passAt5(self: TaskSamples) f64 {
        return self.passAtK(5);
    }

    /// Get pass@10 (upper bound estimate)
    pub fn passAt10(self: TaskSamples) f64 {
        return self.passAtK(10);
    }

    /// Calculate the average test pass rate across all samples
    pub fn avgTestPassRate(self: TaskSamples) f64 {
        if (self.samples.len == 0) return 0.0;
        var sum: f64 = 0.0;
        for (self.samples) |sample| {
            sum += sample.passRate();
        }
        return sum / @as(f64, @floatFromInt(self.samples.len));
    }

    /// Calculate the average constraint satisfaction rate
    pub fn avgConstraintSatisfaction(self: TaskSamples) f64 {
        if (self.samples.len == 0) return 0.0;
        var sum: f64 = 0.0;
        for (self.samples) |sample| {
            sum += sample.constraintSatisfactionRate();
        }
        return sum / @as(f64, @floatFromInt(self.samples.len));
    }
};

/// Compute the unbiased pass@k estimator
/// Formula: pass@k = 1 - C(n-c, k) / C(n, k)
/// Where C(a,b) is the binomial coefficient "a choose b"
pub fn computePassAtK(n: u32, c: u32, k: u32) f64 {
    // Edge cases
    if (k > n) return if (c > 0) 1.0 else 0.0;
    if (c == 0) return 0.0;
    if (c >= n) return 1.0;
    if (k == 0) return 0.0;

    // For numerical stability, compute in log space
    // log(C(n-c, k) / C(n, k)) = log(C(n-c, k)) - log(C(n, k))
    //
    // C(n, k) = n! / (k! * (n-k)!)
    // log(C(n, k)) = sum(log(n-i+1) - log(i)) for i in 1..k

    const n_f = @as(f64, @floatFromInt(n));
    const c_f = @as(f64, @floatFromInt(c));

    // If n-c < k, then C(n-c, k) = 0, so pass@k = 1
    if (n - c < k) return 1.0;

    // Compute log(C(n-c, k)) - log(C(n, k))
    // = sum_{i=1}^{k} log((n-c-i+1)/(n-i+1))
    var log_ratio: f64 = 0.0;
    var i: u32 = 0;
    while (i < k) : (i += 1) {
        const i_f = @as(f64, @floatFromInt(i));
        const numerator = n_f - c_f - i_f;
        const denominator = n_f - i_f;
        log_ratio += @log(numerator / denominator);
    }

    // pass@k = 1 - exp(log_ratio)
    return 1.0 - @exp(log_ratio);
}

/// Aggregate pass@k across multiple tasks
pub const AggregatePassAtK = struct {
    k: u32,
    mean: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    median: f64,
    count: u32,

    /// Create from a list of per-task pass@k values
    pub fn fromValues(allocator: Allocator, values: []const f64, k: u32) !AggregatePassAtK {
        if (values.len == 0) {
            return AggregatePassAtK{
                .k = k,
                .mean = 0.0,
                .std_dev = 0.0,
                .min = 0.0,
                .max = 0.0,
                .median = 0.0,
                .count = 0,
            };
        }

        // Calculate mean
        var sum: f64 = 0.0;
        var min_val: f64 = values[0];
        var max_val: f64 = values[0];
        for (values) |v| {
            sum += v;
            if (v < min_val) min_val = v;
            if (v > max_val) max_val = v;
        }
        const mean = sum / @as(f64, @floatFromInt(values.len));

        // Calculate standard deviation
        var variance_sum: f64 = 0.0;
        for (values) |v| {
            const diff = v - mean;
            variance_sum += diff * diff;
        }
        const std_dev = @sqrt(variance_sum / @as(f64, @floatFromInt(values.len)));

        // Calculate median (need to sort)
        const sorted = try allocator.alloc(f64, values.len);
        defer allocator.free(sorted);
        @memcpy(sorted, values);
        std.mem.sort(f64, sorted, {}, std.sort.asc(f64));

        const median = if (sorted.len % 2 == 0)
            (sorted[sorted.len / 2 - 1] + sorted[sorted.len / 2]) / 2.0
        else
            sorted[sorted.len / 2];

        return AggregatePassAtK{
            .k = k,
            .mean = mean,
            .std_dev = std_dev,
            .min = min_val,
            .max = max_val,
            .median = median,
            .count = @as(u32, @intCast(values.len)),
        };
    }

    /// Serialize to JSON
    pub fn toJson(self: AggregatePassAtK, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"k":{d},"mean":{d:.4},"std_dev":{d:.4},"min":{d:.4},"max":{d:.4},"median":{d:.4},"count":{d}}}
        , .{ self.k, self.mean, self.std_dev, self.min, self.max, self.median, self.count });

        return buf.toOwnedSlice();
    }
};

/// Compute pass@k for multiple k values at once
pub const PassAtKResults = struct {
    pass_at_1: f64,
    pass_at_5: f64,
    pass_at_10: f64,
    total_samples: u32,
    correct_samples: u32,

    pub fn compute(n: u32, c: u32) PassAtKResults {
        return PassAtKResults{
            .pass_at_1 = computePassAtK(n, c, 1),
            .pass_at_5 = computePassAtK(n, c, 5),
            .pass_at_10 = computePassAtK(n, c, 10),
            .total_samples = n,
            .correct_samples = c,
        };
    }

    pub fn toJson(self: PassAtKResults, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"pass@1":{d:.4},"pass@5":{d:.4},"pass@10":{d:.4},"total_samples":{d},"correct_samples":{d}}}
        , .{ self.pass_at_1, self.pass_at_5, self.pass_at_10, self.total_samples, self.correct_samples });

        return buf.toOwnedSlice();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "pass@k basic cases" {
    // All samples correct
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), computePassAtK(10, 10, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), computePassAtK(10, 10, 5), 0.0001);

    // No samples correct
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), computePassAtK(10, 0, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), computePassAtK(10, 0, 5), 0.0001);

    // Half correct
    // pass@1 with 5/10 correct = 0.5
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), computePassAtK(10, 5, 1), 0.0001);

    // pass@5 with 5/10 correct should be higher
    const pass_at_5 = computePassAtK(10, 5, 5);
    try std.testing.expect(pass_at_5 > 0.5);
    try std.testing.expect(pass_at_5 < 1.0);
}

test "pass@k edge cases" {
    // k > n
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), computePassAtK(5, 3, 10), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), computePassAtK(5, 0, 10), 0.0001);

    // k = 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), computePassAtK(10, 5, 0), 0.0001);

    // n - c < k (guaranteed success)
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), computePassAtK(10, 8, 5), 0.0001);
}

test "pass@k HumanEval reference" {
    // Reference values from HumanEval paper methodology
    // With n=200 samples and c=150 correct:
    // pass@1 = 150/200 = 0.75
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), computePassAtK(200, 150, 1), 0.001);

    // pass@10 should be significantly higher (near 1.0)
    const pass_at_10 = computePassAtK(200, 150, 10);
    try std.testing.expect(pass_at_10 > 0.99);
}

test "aggregate pass@k" {
    const allocator = std.testing.allocator;
    const values = [_]f64{ 0.5, 0.6, 0.7, 0.8, 0.9 };

    const agg = try AggregatePassAtK.fromValues(allocator, &values, 1);

    try std.testing.expectApproxEqAbs(@as(f64, 0.7), agg.mean, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), agg.min, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), agg.max, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), agg.median, 0.0001);
    try std.testing.expectEqual(@as(u32, 5), agg.count);
}

test "PassAtKResults" {
    const results = PassAtKResults.compute(100, 70);

    try std.testing.expectApproxEqAbs(@as(f64, 0.7), results.pass_at_1, 0.001);
    try std.testing.expect(results.pass_at_5 > results.pass_at_1);
    try std.testing.expect(results.pass_at_10 > results.pass_at_5);
    try std.testing.expectEqual(@as(u32, 100), results.total_samples);
    try std.testing.expectEqual(@as(u32, 70), results.correct_samples);
}
