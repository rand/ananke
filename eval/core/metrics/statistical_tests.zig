// Statistical Tests for Evaluation Rigor
//
// Implements statistical significance tests for comparing constrained vs baseline:
// - Paired t-test (parametric, assumes normal distribution)
// - Wilcoxon signed-rank test (non-parametric alternative)
// - Cohen's d effect size
// - 95% Confidence intervals
// - Bootstrap resampling for small samples

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

/// Result of a statistical comparison between two conditions
pub const ComparisonResult = struct {
    /// Sample size
    n: u32,

    /// Mean difference (constrained - baseline)
    mean_diff: f64,

    /// Standard error of the mean difference
    std_error: f64,

    /// 95% confidence interval lower bound
    ci_lower: f64,

    /// 95% confidence interval upper bound
    ci_upper: f64,

    /// t-statistic for paired t-test
    t_statistic: f64,

    /// p-value from t-test (two-tailed)
    p_value: f64,

    /// Cohen's d effect size
    effect_size: f64,

    /// Effect size interpretation
    effect_interpretation: EffectInterpretation,

    /// Is the result statistically significant at p < 0.05?
    is_significant: bool,

    pub const EffectInterpretation = enum {
        negligible, // |d| < 0.2
        small, // 0.2 <= |d| < 0.5
        medium, // 0.5 <= |d| < 0.8
        large, // |d| >= 0.8

        pub fn fromCohenD(d: f64) EffectInterpretation {
            const abs_d = @abs(d);
            if (abs_d < 0.2) return .negligible;
            if (abs_d < 0.5) return .small;
            if (abs_d < 0.8) return .medium;
            return .large;
        }

        pub fn toString(self: EffectInterpretation) []const u8 {
            return switch (self) {
                .negligible => "negligible",
                .small => "small",
                .medium => "medium",
                .large => "large",
            };
        }
    };

    pub fn toJson(self: ComparisonResult, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 512);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"n":{d},"mean_diff":{d:.4},"std_error":{d:.4},"ci_lower":{d:.4},"ci_upper":{d:.4},"t_statistic":{d:.4},"p_value":{d:.6},"effect_size":{d:.4},"effect_interpretation":"{s}","is_significant":{}}}
        , .{
            self.n,
            self.mean_diff,
            self.std_error,
            self.ci_lower,
            self.ci_upper,
            self.t_statistic,
            self.p_value,
            self.effect_size,
            self.effect_interpretation.toString(),
            self.is_significant,
        });

        return buf.toOwnedSlice();
    }
};

/// Perform a paired t-test comparing two conditions
/// Returns ComparisonResult with t-statistic, p-value, effect size, and CI
pub fn pairedTTest(constrained: []const f64, baseline: []const f64) !ComparisonResult {
    if (constrained.len != baseline.len) return error.MismatchedSampleSizes;
    if (constrained.len < 2) return error.InsufficientSamples;

    const n = @as(u32, @intCast(constrained.len));
    const n_f = @as(f64, @floatFromInt(n));

    // Calculate differences
    var diff_sum: f64 = 0.0;
    for (constrained, baseline) |c, b| {
        diff_sum += c - b;
    }
    const mean_diff = diff_sum / n_f;

    // Calculate standard deviation of differences
    var ss: f64 = 0.0; // Sum of squares
    for (constrained, baseline) |c, b| {
        const d = (c - b) - mean_diff;
        ss += d * d;
    }
    const variance = ss / (n_f - 1.0);
    const std_dev = @sqrt(variance);

    // Standard error
    const std_error = std_dev / @sqrt(n_f);

    // t-statistic
    const t_stat = if (std_error > 0.0001) mean_diff / std_error else 0.0;

    // Calculate p-value using t-distribution approximation
    // For df > 30, t-distribution approximates normal
    const df = n_f - 1.0;
    const p_value = tDistributionPValue(t_stat, df);

    // 95% confidence interval (t-critical for df degrees of freedom)
    const t_critical = tCriticalValue(0.05, df);
    const ci_lower = mean_diff - t_critical * std_error;
    const ci_upper = mean_diff + t_critical * std_error;

    // Cohen's d effect size
    const effect_size = if (std_dev > 0.0001) mean_diff / std_dev else 0.0;

    return ComparisonResult{
        .n = n,
        .mean_diff = mean_diff,
        .std_error = std_error,
        .ci_lower = ci_lower,
        .ci_upper = ci_upper,
        .t_statistic = t_stat,
        .p_value = p_value,
        .effect_size = effect_size,
        .effect_interpretation = ComparisonResult.EffectInterpretation.fromCohenD(effect_size),
        .is_significant = p_value < 0.05,
    };
}

/// Wilcoxon signed-rank test (non-parametric)
/// Returns approximate z-score and p-value
pub const WilcoxonResult = struct {
    n: u32,
    w_plus: f64, // Sum of positive ranks
    w_minus: f64, // Sum of negative ranks
    w_statistic: f64, // min(W+, W-)
    z_score: f64,
    p_value: f64,
    is_significant: bool,

    pub fn toJson(self: WilcoxonResult, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"n":{d},"w_plus":{d:.2},"w_minus":{d:.2},"w_statistic":{d:.2},"z_score":{d:.4},"p_value":{d:.6},"is_significant":{}}}
        , .{
            self.n,
            self.w_plus,
            self.w_minus,
            self.w_statistic,
            self.z_score,
            self.p_value,
            self.is_significant,
        });

        return buf.toOwnedSlice();
    }
};

pub fn wilcoxonSignedRank(allocator: Allocator, constrained: []const f64, baseline: []const f64) !WilcoxonResult {
    if (constrained.len != baseline.len) return error.MismatchedSampleSizes;
    if (constrained.len < 5) return error.InsufficientSamples;

    const n = constrained.len;

    // Calculate differences and their absolute values
    const DiffRank = struct {
        diff: f64,
        abs_diff: f64,
        rank: f64,
    };

    var diffs = try allocator.alloc(DiffRank, n);
    defer allocator.free(diffs);

    var non_zero_count: usize = 0;
    for (constrained, baseline, 0..) |c, b, i| {
        const diff = c - b;
        if (@abs(diff) > 0.0001) {
            diffs[non_zero_count] = .{
                .diff = diff,
                .abs_diff = @abs(diff),
                .rank = 0,
            };
            non_zero_count += 1;
        }
        _ = i;
    }

    if (non_zero_count < 5) {
        return WilcoxonResult{
            .n = @as(u32, @intCast(non_zero_count)),
            .w_plus = 0,
            .w_minus = 0,
            .w_statistic = 0,
            .z_score = 0,
            .p_value = 1.0,
            .is_significant = false,
        };
    }

    // Sort by absolute difference for ranking
    std.mem.sort(DiffRank, diffs[0..non_zero_count], {}, struct {
        fn lessThan(_: void, a: DiffRank, b: DiffRank) bool {
            return a.abs_diff < b.abs_diff;
        }
    }.lessThan);

    // Assign ranks (handling ties with average rank)
    var i: usize = 0;
    while (i < non_zero_count) {
        var j = i;
        // Find all tied values
        while (j < non_zero_count and @abs(diffs[j].abs_diff - diffs[i].abs_diff) < 0.0001) {
            j += 1;
        }
        // Average rank for ties
        const avg_rank = (@as(f64, @floatFromInt(i + j + 1)) / 2.0);
        for (i..j) |k| {
            diffs[k].rank = avg_rank;
        }
        i = j;
    }

    // Calculate W+ and W-
    var w_plus: f64 = 0.0;
    var w_minus: f64 = 0.0;
    for (diffs[0..non_zero_count]) |d| {
        if (d.diff > 0) {
            w_plus += d.rank;
        } else {
            w_minus += d.rank;
        }
    }

    const nn = @as(f64, @floatFromInt(non_zero_count));
    const w_stat = @min(w_plus, w_minus);

    // Normal approximation for z-score
    const mean_w = nn * (nn + 1.0) / 4.0;
    const var_w = nn * (nn + 1.0) * (2.0 * nn + 1.0) / 24.0;
    const std_w = @sqrt(var_w);

    const z_score = if (std_w > 0.0001) (w_stat - mean_w) / std_w else 0.0;
    const p_value = 2.0 * normalCDF(-@abs(z_score)); // Two-tailed

    return WilcoxonResult{
        .n = @as(u32, @intCast(non_zero_count)),
        .w_plus = w_plus,
        .w_minus = w_minus,
        .w_statistic = w_stat,
        .z_score = z_score,
        .p_value = p_value,
        .is_significant = p_value < 0.05,
    };
}

/// Bootstrap confidence interval for the mean difference
pub const BootstrapResult = struct {
    mean_diff: f64,
    ci_lower: f64, // 2.5th percentile
    ci_upper: f64, // 97.5th percentile
    bootstrap_iterations: u32,

    pub fn toJson(self: BootstrapResult, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 128);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.print(
            \\{{"mean_diff":{d:.4},"ci_lower":{d:.4},"ci_upper":{d:.4},"bootstrap_iterations":{d}}}
        , .{ self.mean_diff, self.ci_lower, self.ci_upper, self.bootstrap_iterations });

        return buf.toOwnedSlice();
    }
};

pub fn bootstrapCI(
    allocator: Allocator,
    constrained: []const f64,
    baseline: []const f64,
    iterations: u32,
    seed: u64,
) !BootstrapResult {
    if (constrained.len != baseline.len) return error.MismatchedSampleSizes;

    const n = constrained.len;
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // Store bootstrap means
    var boot_means = try allocator.alloc(f64, iterations);
    defer allocator.free(boot_means);

    // Calculate original mean difference
    var orig_sum: f64 = 0.0;
    for (constrained, baseline) |c, b| {
        orig_sum += c - b;
    }
    const orig_mean = orig_sum / @as(f64, @floatFromInt(n));

    // Bootstrap iterations
    for (0..iterations) |iter| {
        var boot_sum: f64 = 0.0;
        for (0..n) |_| {
            const idx = random.intRangeAtMost(usize, 0, n - 1);
            boot_sum += constrained[idx] - baseline[idx];
        }
        boot_means[iter] = boot_sum / @as(f64, @floatFromInt(n));
    }

    // Sort for percentiles
    std.mem.sort(f64, boot_means, {}, std.sort.asc(f64));

    // 2.5th and 97.5th percentiles for 95% CI
    const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(iterations)) * 0.025));
    const upper_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(iterations)) * 0.975));

    return BootstrapResult{
        .mean_diff = orig_mean,
        .ci_lower = boot_means[lower_idx],
        .ci_upper = boot_means[upper_idx],
        .bootstrap_iterations = iterations,
    };
}

// =============================================================================
// Helper functions for distributions
// =============================================================================

/// Approximate p-value for t-distribution (two-tailed)
fn tDistributionPValue(t: f64, df: f64) f64 {
    // Use normal approximation for large df
    if (df > 100) {
        return 2.0 * normalCDF(-@abs(t));
    }

    // For smaller df, use a rough approximation
    // This is a simplification; production code should use a proper implementation
    const x = df / (df + t * t);
    const p_one_tail = 0.5 * incompleteBeta(df / 2.0, 0.5, x);
    return 2.0 * p_one_tail;
}

/// Approximate critical t-value for given alpha and df
fn tCriticalValue(alpha: f64, df: f64) f64 {
    // Common critical values (two-tailed)
    // This is a simplification for common cases
    if (df > 100) {
        if (alpha <= 0.01) return 2.576;
        if (alpha <= 0.05) return 1.96;
        return 1.645;
    }

    // Rough approximation for smaller df
    const base = if (alpha <= 0.01) @as(f64, 2.576) else if (alpha <= 0.05) @as(f64, 1.96) else @as(f64, 1.645);
    const adjustment = 1.0 + 3.0 / df; // Increase for smaller df
    return base * adjustment;
}

/// Standard normal CDF approximation
fn normalCDF(x: f64) f64 {
    // Approximation using error function
    const a1: f64 = 0.254829592;
    const a2: f64 = -0.284496736;
    const a3: f64 = 1.421413741;
    const a4: f64 = -1.453152027;
    const a5: f64 = 1.061405429;
    const p: f64 = 0.3275911;

    const sign: f64 = if (x < 0) -1.0 else 1.0;
    const abs_x = @abs(x) / @sqrt(2.0);

    const t = 1.0 / (1.0 + p * abs_x);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * @exp(-abs_x * abs_x);

    return 0.5 * (1.0 + sign * y);
}

/// Incomplete beta function approximation (for t-distribution)
fn incompleteBeta(a: f64, b: f64, x: f64) f64 {
    // Simple approximation for the cases we need
    // Production code should use a proper implementation
    if (x <= 0) return 0.0;
    if (x >= 1) return 1.0;

    // Using continued fraction approximation
    const bt = @exp(
        a * @log(x) + b * @log(1.0 - x) - @log(a) - logBeta(a, b),
    );

    if (x < (a + 1.0) / (a + b + 2.0)) {
        return bt * betaCF(a, b, x) / a;
    } else {
        return 1.0 - bt * betaCF(b, a, 1.0 - x) / b;
    }
}

fn logBeta(a: f64, b: f64) f64 {
    return std.math.lgamma(a) + std.math.lgamma(b) - std.math.lgamma(a + b);
}

fn betaCF(a: f64, b: f64, x: f64) f64 {
    const max_iter: usize = 100;
    const eps: f64 = 1e-10;

    const qab = a + b;
    const qap = a + 1.0;
    const qam = a - 1.0;
    var c: f64 = 1.0;
    var d = 1.0 - qab * x / qap;
    if (@abs(d) < eps) d = eps;
    d = 1.0 / d;
    var h = d;

    for (1..max_iter + 1) |m| {
        const m_f = @as(f64, @floatFromInt(m));
        const m2 = 2.0 * m_f;

        var aa = m_f * (b - m_f) * x / ((qam + m2) * (a + m2));
        d = 1.0 + aa * d;
        if (@abs(d) < eps) d = eps;
        c = 1.0 + aa / c;
        if (@abs(c) < eps) c = eps;
        d = 1.0 / d;
        h *= d * c;

        aa = -(a + m_f) * (qab + m_f) * x / ((a + m2) * (qap + m2));
        d = 1.0 + aa * d;
        if (@abs(d) < eps) d = eps;
        c = 1.0 + aa / c;
        if (@abs(c) < eps) c = eps;
        d = 1.0 / d;
        const del = d * c;
        h *= del;

        if (@abs(del - 1.0) < eps) break;
    }

    return h;
}

// =============================================================================
// Tests
// =============================================================================

test "paired t-test basic" {
    const constrained = [_]f64{ 0.8, 0.9, 0.85, 0.95, 0.88 };
    const baseline = [_]f64{ 0.5, 0.6, 0.55, 0.65, 0.58 };

    const result = try pairedTTest(&constrained, &baseline);

    // Mean diff should be ~0.3
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), result.mean_diff, 0.01);

    // Should be significant (large difference)
    try std.testing.expect(result.is_significant);

    // Large effect size
    try std.testing.expect(result.effect_interpretation == .large);
}

test "paired t-test no difference" {
    const constrained = [_]f64{ 0.5, 0.6, 0.55, 0.65, 0.58 };
    const baseline = [_]f64{ 0.5, 0.6, 0.55, 0.65, 0.58 };

    const result = try pairedTTest(&constrained, &baseline);

    // Mean diff should be 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result.mean_diff, 0.001);

    // Should not be significant
    try std.testing.expect(!result.is_significant);

    // Negligible effect
    try std.testing.expect(result.effect_interpretation == .negligible);
}

test "effect size interpretation" {
    const Interp = ComparisonResult.EffectInterpretation;

    try std.testing.expectEqual(Interp.negligible, Interp.fromCohenD(0.1));
    try std.testing.expectEqual(Interp.small, Interp.fromCohenD(0.3));
    try std.testing.expectEqual(Interp.medium, Interp.fromCohenD(0.6));
    try std.testing.expectEqual(Interp.large, Interp.fromCohenD(1.0));
}

test "bootstrap CI" {
    const allocator = std.testing.allocator;

    const constrained = [_]f64{ 0.8, 0.9, 0.85, 0.95, 0.88 };
    const baseline = [_]f64{ 0.5, 0.6, 0.55, 0.65, 0.58 };

    const result = try bootstrapCI(allocator, &constrained, &baseline, 1000, 42);

    // CI should contain the mean
    try std.testing.expect(result.ci_lower < result.mean_diff);
    try std.testing.expect(result.ci_upper > result.mean_diff);

    // Mean should be ~0.3
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), result.mean_diff, 0.01);
}
