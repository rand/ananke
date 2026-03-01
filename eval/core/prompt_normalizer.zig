const std = @import("std");
const task_spec = @import("task_spec");
const Allocator = std.mem.Allocator;

/// Prompt normalization for fair baseline comparison.
///
/// This module ensures both constrained and baseline modes receive
/// semantically equivalent prompts, differing only in structural guidance.
/// This is critical for scientific validity of the comparison.
pub const PromptNormalizer = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Generate normalized prompt for constrained mode.
    ///
    /// Constrained mode receives:
    /// - Task description
    /// - Requirements list
    /// - Note that output will be structurally validated
    pub fn constrainedPrompt(self: Self, spec: task_spec.TaskSpec) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        // Common task section (identical to baseline)
        try self.writeCommonTaskSection(writer, spec);

        // Constrained-specific guidance
        try writer.writeAll("\n## Output Requirements\n");
        try writer.writeAll("Your output will be automatically validated against structural requirements.\n");
        try writer.writeAll("The system will guide your generation to produce syntactically valid code.\n");

        return buf.toOwnedSlice();
    }

    /// Generate normalized prompt for baseline mode.
    ///
    /// Baseline mode receives:
    /// - Task description
    /// - Requirements list
    /// - Natural language description of structural requirements
    pub fn baselinePrompt(self: Self, spec: task_spec.TaskSpec, constraints_as_text: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        // Common task section (identical to constrained)
        try self.writeCommonTaskSection(writer, spec);

        // Baseline-specific guidance: convert constraints to natural language
        try writer.writeAll("\n## Structural Requirements\n");
        try writer.writeAll("Follow these structural requirements in your implementation:\n\n");
        try writer.writeAll(constraints_as_text);
        try writer.writeAll("\n");

        return buf.toOwnedSlice();
    }

    /// Write the common task section shared by both modes.
    fn writeCommonTaskSection(self: Self, writer: anytype, spec: task_spec.TaskSpec) !void {
        _ = self;

        // Title and description
        try writer.writeAll("# ");
        try writer.writeAll(spec.title);
        try writer.writeAll("\n\n");
        try writer.writeAll(spec.description);
        try writer.writeAll("\n\n");

        // Language
        try writer.writeAll("**Language**: ");
        try writer.writeAll(@tagName(spec.language));
        try writer.writeAll("\n\n");

        // Requirements list
        try writer.writeAll("## Requirements\n");
        for (spec.requirements) |req| {
            try writer.writeAll("- ");
            try writer.writeAll(req);
            try writer.writeAll("\n");
        }

        // Few-shot examples if available
        if (spec.few_shot_examples.len > 0) {
            try writer.writeAll("\n## Examples\n");
            for (spec.few_shot_examples) |example| {
                try writer.writeAll("\n**Prompt**: ");
                try writer.writeAll(example.prompt);
                try writer.writeAll("\n```\n");
                try writer.writeAll(example.code);
                try writer.writeAll("\n```\n");
            }
        }
    }
};

/// Convert JSON schema constraints to natural language for baseline prompts.
///
/// This ensures baseline mode has access to the same information as constrained mode,
/// just expressed differently.
pub const ConstraintToTextConverter = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Convert constraint JSON to human-readable description.
    pub fn convert(self: Self, constraint_json: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        // Parse JSON and extract key patterns
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, constraint_json, .{}) catch |err| {
            // Fallback: return the raw JSON as code block
            _ = err;
            try writer.writeAll("The output should conform to the following structure:\n```json\n");
            try writer.writeAll(constraint_json);
            try writer.writeAll("\n```\n");
            return buf.toOwnedSlice();
        };
        defer parsed.deinit();

        try self.describeConstraint(writer, parsed.value, 0);

        return buf.toOwnedSlice();
    }

    fn describeConstraint(self: Self, writer: anytype, value: std.json.Value, depth: usize) !void {
        _ = self;

        switch (value) {
            .object => |obj| {
                // Check for common schema patterns
                if (obj.get("type")) |type_val| {
                    if (type_val == .string) {
                        const type_str = type_val.string;

                        if (std.mem.eql(u8, type_str, "object")) {
                            try writer.writeAll("An object with the following properties:\n");
                            if (obj.get("properties")) |props| {
                                if (props == .object) {
                                    var iter = props.object.iterator();
                                    while (iter.next()) |entry| {
                                        for (0..depth + 1) |_| try writer.writeAll("  ");
                                        try writer.writeAll("- `");
                                        try writer.writeAll(entry.key_ptr.*);
                                        try writer.writeAll("`: ");
                                        try self.describePropertyType(writer, entry.value_ptr.*);
                                        try writer.writeAll("\n");
                                    }
                                }
                            }
                        } else if (std.mem.eql(u8, type_str, "string")) {
                            try writer.writeAll("A string");
                            if (obj.get("pattern")) |pattern| {
                                if (pattern == .string) {
                                    try writer.writeAll(" matching pattern `");
                                    try writer.writeAll(pattern.string);
                                    try writer.writeAll("`");
                                }
                            }
                        } else if (std.mem.eql(u8, type_str, "array")) {
                            try writer.writeAll("An array");
                            if (obj.get("items")) |items| {
                                try writer.writeAll(" of ");
                                try self.describePropertyType(writer, items);
                            }
                        } else {
                            try writer.writeAll(type_str);
                        }
                    }
                }

                // Check for required fields
                if (obj.get("required")) |required| {
                    if (required == .array) {
                        try writer.writeAll("\nRequired fields: ");
                        var first = true;
                        for (required.array.items) |item| {
                            if (item == .string) {
                                if (!first) try writer.writeAll(", ");
                                try writer.writeAll("`");
                                try writer.writeAll(item.string);
                                try writer.writeAll("`");
                                first = false;
                            }
                        }
                        try writer.writeAll("\n");
                    }
                }
            },
            else => {},
        }
    }

    fn describePropertyType(self: Self, writer: anytype, value: std.json.Value) !void {
        _ = self;

        switch (value) {
            .object => |obj| {
                if (obj.get("type")) |type_val| {
                    if (type_val == .string) {
                        try writer.writeAll(type_val.string);
                    }
                } else {
                    try writer.writeAll("object");
                }
            },
            .string => |s| try writer.writeAll(s),
            else => try writer.writeAll("any"),
        }
    }
};

/// Comparison result with statistical analysis.
pub const StatisticalComparison = struct {
    /// Name of the metric being compared
    metric_name: []const u8,

    /// Constrained mode results
    constrained_mean: f64,
    constrained_std: f64,
    constrained_n: usize,

    /// Baseline mode results
    baseline_mean: f64,
    baseline_std: f64,
    baseline_n: usize,

    /// Statistical tests
    t_test_p_value: f64,
    wilcoxon_p_value: ?f64, // null if not applicable
    cohens_d: f64,

    /// Confidence interval for the difference
    ci_lower: f64,
    ci_upper: f64,
    ci_level: f64, // typically 0.95

    /// Interpretation helpers
    pub fn isSignificant(self: StatisticalComparison, alpha: f64) bool {
        return self.t_test_p_value < alpha;
    }

    pub fn effectSizeInterpretation(self: StatisticalComparison) []const u8 {
        const d = @abs(self.cohens_d);
        if (d < 0.2) return "negligible";
        if (d < 0.5) return "small";
        if (d < 0.8) return "medium";
        return "large";
    }

    pub fn constrainedIsBetter(self: StatisticalComparison) bool {
        return self.constrained_mean > self.baseline_mean;
    }

    /// Format as human-readable summary
    pub fn format(self: StatisticalComparison, allocator: Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        try writer.print("## {s}\n\n", .{self.metric_name});
        try writer.print("| Mode | Mean | Std | N |\n", .{});
        try writer.print("|------|------|-----|---|\n", .{});
        try writer.print("| Constrained | {d:.3} | {d:.3} | {d} |\n", .{ self.constrained_mean, self.constrained_std, self.constrained_n });
        try writer.print("| Baseline | {d:.3} | {d:.3} | {d} |\n", .{ self.baseline_mean, self.baseline_std, self.baseline_n });
        try writer.writeAll("\n");

        // Statistical results
        try writer.print("**Difference**: {d:.3} ({s} better)\n", .{
            self.constrained_mean - self.baseline_mean,
            if (self.constrainedIsBetter()) "constrained" else "baseline",
        });
        try writer.print("**95% CI**: [{d:.3}, {d:.3}]\n", .{ self.ci_lower, self.ci_upper });
        try writer.print("**p-value** (t-test): {d:.4}\n", .{self.t_test_p_value});
        try writer.print("**Effect size** (Cohen's d): {d:.3} ({s})\n", .{ self.cohens_d, self.effectSizeInterpretation() });

        if (self.isSignificant(0.05)) {
            try writer.writeAll("\n*Result is statistically significant at p < 0.05*\n");
        } else {
            try writer.writeAll("\n*Result is NOT statistically significant at p < 0.05*\n");
        }

        return buf.toOwnedSlice();
    }
};

/// Run statistical comparison between two sets of results.
pub fn compareResults(
    allocator: Allocator,
    metric_name: []const u8,
    constrained_results: []const f64,
    baseline_results: []const f64,
) !StatisticalComparison {
    const stats = @import("metrics/statistical_tests.zig");

    // Basic statistics
    const constrained_mean = mean(constrained_results);
    const constrained_std = std_dev(constrained_results, constrained_mean);
    const baseline_mean = mean(baseline_results);
    const baseline_std = std_dev(baseline_results, baseline_mean);

    // Run statistical tests
    const t_result = stats.pairedTTest(constrained_results, baseline_results);
    const effect = stats.effectSize(constrained_results, baseline_results);
    const ci = try stats.bootstrapCI(allocator, constrained_results, baseline_results, 0.95, 1000);

    // Wilcoxon for non-parametric comparison (if enough samples)
    var wilcoxon_p: ?f64 = null;
    if (constrained_results.len >= 10) {
        const wilcoxon = stats.wilcoxonSignedRank(constrained_results, baseline_results);
        wilcoxon_p = wilcoxon.p_value;
    }

    return StatisticalComparison{
        .metric_name = metric_name,
        .constrained_mean = constrained_mean,
        .constrained_std = constrained_std,
        .constrained_n = constrained_results.len,
        .baseline_mean = baseline_mean,
        .baseline_std = baseline_std,
        .baseline_n = baseline_results.len,
        .t_test_p_value = t_result.p_value,
        .wilcoxon_p_value = wilcoxon_p,
        .cohens_d = effect.cohens_d,
        .ci_lower = ci.lower,
        .ci_upper = ci.upper,
        .ci_level = 0.95,
    };
}

// Helper functions
fn mean(data: []const f64) f64 {
    if (data.len == 0) return 0;
    var sum: f64 = 0;
    for (data) |x| sum += x;
    return sum / @as(f64, @floatFromInt(data.len));
}

fn std_dev(data: []const f64, data_mean: f64) f64 {
    if (data.len <= 1) return 0;
    var sum_sq: f64 = 0;
    for (data) |x| {
        const diff = x - data_mean;
        sum_sq += diff * diff;
    }
    return @sqrt(sum_sq / @as(f64, @floatFromInt(data.len - 1)));
}

test "prompt normalizer generates valid prompts" {
    const allocator = std.testing.allocator;
    const normalizer = PromptNormalizer.init(allocator);

    // Create test spec
    const spec = task_spec.TaskSpec{
        .id = "test_001",
        .title = "Test Task",
        .description = "A test task description.",
        .language = .typescript,
        .requirements = &[_][]const u8{ "Requirement 1", "Requirement 2" },
    };

    const constrained = try normalizer.constrainedPrompt(spec);
    defer allocator.free(constrained);

    const baseline = try normalizer.baselinePrompt(spec, "- Use function name 'foo'");
    defer allocator.free(baseline);

    // Both should contain the common sections
    try std.testing.expect(std.mem.indexOf(u8, constrained, "Test Task") != null);
    try std.testing.expect(std.mem.indexOf(u8, baseline, "Test Task") != null);

    // Constrained should mention validation
    try std.testing.expect(std.mem.indexOf(u8, constrained, "validated") != null);

    // Baseline should have structural requirements section
    try std.testing.expect(std.mem.indexOf(u8, baseline, "Structural Requirements") != null);
}
