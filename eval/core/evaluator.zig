const std = @import("std");
const task_spec = @import("task_spec");
const modal_client = @import("modal_client");
const baseline = @import("baseline");
const test_runner = @import("test_runner");
const constraint_compiler = @import("constraint_compiler");
const quality_scorer = @import("quality_scorer");
const Allocator = std.mem.Allocator;

/// Configuration captured at evaluation run time for scientific reproducibility
pub const EvaluationConfig = struct {
    /// Unique run identifier (ISO 8601 timestamp)
    run_id: []const u8,
    /// Framework version
    framework_version: []const u8 = "1.0.0",
    /// Inference endpoint URL
    endpoint_url: []const u8,
    /// Model configuration
    model: ModelConfig,
    /// Hardware configuration (from Modal deployment)
    hardware: HardwareConfig,
    /// Constraint system configuration
    constraint_system: ConstraintConfig,
    /// Evaluation parameters
    evaluation: EvaluationParams,

    pub const ModelConfig = struct {
        name: []const u8 = "Qwen/Qwen2.5-Coder-7B-Instruct",
        provider: []const u8 = "vLLM",
        quantization: ?[]const u8 = null,
    };

    pub const HardwareConfig = struct {
        gpu_type: []const u8 = "NVIDIA H100",
        gpu_count: u32 = 1,
        platform: []const u8 = "Modal",
    };

    pub const ConstraintConfig = struct {
        backend: []const u8 = "llguidance",
        integration: []const u8 = "vLLM regex-guided decoding",
        compiler: []const u8 = "Braid",
    };

    pub const EvaluationParams = struct {
        temperature: f32 = 0.0,
        max_tokens_multiplier: u32 = 20,
        max_tokens_cap: u32 = 4096,
        samples_per_task: u32 = 1,
    };

    /// Create default configuration with current timestamp
    pub fn initDefault(allocator: Allocator, endpoint_url: []const u8) !EvaluationConfig {
        // Generate ISO 8601 timestamp as run_id
        const timestamp = std.time.timestamp();
        const run_id = try std.fmt.allocPrint(allocator, "{d}", .{timestamp});

        return EvaluationConfig{
            .run_id = run_id,
            .endpoint_url = try allocator.dupe(u8, endpoint_url),
            .model = .{},
            .hardware = .{},
            .constraint_system = .{},
            .evaluation = .{},
        };
    }

    pub fn deinit(self: *EvaluationConfig, allocator: Allocator) void {
        allocator.free(self.run_id);
        allocator.free(self.endpoint_url);
    }

    /// Serialize config to JSON
    pub fn toJson(self: EvaluationConfig, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 2048);
        defer buf.deinit(allocator);

        const writer = buf.writer(allocator);

        try writer.writeAll("{\n");
        try writer.print("  \"run_id\": \"{s}\",\n", .{self.run_id});
        try writer.print("  \"framework_version\": \"{s}\",\n", .{self.framework_version});
        try writer.print("  \"endpoint_url\": \"{s}\",\n", .{self.endpoint_url});

        // Model config
        try writer.writeAll("  \"model\": {\n");
        try writer.print("    \"name\": \"{s}\",\n", .{self.model.name});
        try writer.print("    \"provider\": \"{s}\",\n", .{self.model.provider});
        if (self.model.quantization) |q| {
            try writer.print("    \"quantization\": \"{s}\"\n", .{q});
        } else {
            try writer.writeAll("    \"quantization\": null\n");
        }
        try writer.writeAll("  },\n");

        // Hardware config
        try writer.writeAll("  \"hardware\": {\n");
        try writer.print("    \"gpu_type\": \"{s}\",\n", .{self.hardware.gpu_type});
        try writer.print("    \"gpu_count\": {d},\n", .{self.hardware.gpu_count});
        try writer.print("    \"platform\": \"{s}\"\n", .{self.hardware.platform});
        try writer.writeAll("  },\n");

        // Constraint system config
        try writer.writeAll("  \"constraint_system\": {\n");
        try writer.print("    \"backend\": \"{s}\",\n", .{self.constraint_system.backend});
        try writer.print("    \"integration\": \"{s}\",\n", .{self.constraint_system.integration});
        try writer.print("    \"compiler\": \"{s}\"\n", .{self.constraint_system.compiler});
        try writer.writeAll("  },\n");

        // Evaluation params
        try writer.writeAll("  \"evaluation\": {\n");
        try writer.print("    \"temperature\": {d:.1},\n", .{self.evaluation.temperature});
        try writer.print("    \"max_tokens_multiplier\": {d},\n", .{self.evaluation.max_tokens_multiplier});
        try writer.print("    \"max_tokens_cap\": {d},\n", .{self.evaluation.max_tokens_cap});
        try writer.print("    \"samples_per_task\": {d}\n", .{self.evaluation.samples_per_task});
        try writer.writeAll("  }\n");

        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};

/// Main evaluation orchestrator for comparing constrained vs unconstrained generation
pub const Evaluator = struct {
    allocator: Allocator,
    base_url: []const u8,
    baseline_generator: baseline.BaselineGenerator,
    test_runner: test_runner.TestRunner,

    pub fn init(allocator: Allocator, base_url: []const u8) Evaluator {
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .baseline_generator = baseline.BaselineGenerator.init(allocator, base_url),
            .test_runner = test_runner.TestRunner.init(allocator),
        };
    }

    pub fn deinit(self: *Evaluator) void {
        self.baseline_generator.deinit();
    }

    /// Run evaluation on a single task in both modes
    pub fn evaluateTask(self: *Evaluator, task: task_spec.TaskSpec) !EvaluationPair {
        std.log.info("Evaluating task: {s}", .{task.id});

        // Generate baseline (unconstrained)
        std.log.info("Generating baseline (unconstrained)...", .{});
        var baseline_result = try self.baseline_generator.generate(task);
        errdefer {
            var mut_baseline = baseline_result;
            mut_baseline.deinit(self.allocator);
        }

        // Generate constrained (Ananke)
        std.log.info("Generating constrained (Ananke)...", .{});
        var constrained_result = try self.generateConstrained(task);
        errdefer {
            var mut_constrained = constrained_result;
            mut_constrained.deinit(self.allocator);
        }

        // Run tests on baseline code with timing
        std.log.info("Running tests on baseline code...", .{});
        var baseline_test_timer = try std.time.Timer.start();
        const baseline_test_result = try self.test_runner.runTests(
            task.language.toString(),
            baseline_result.code,
            task.test_suite_path,
        );
        const baseline_test_time_ms = baseline_test_timer.read() / std.time.ns_per_ms;

        // Update baseline timing with test execution time
        if (baseline_result.timing) |*timing| {
            timing.test_execution_ms = @intCast(baseline_test_time_ms);
            timing.total_ms += @intCast(baseline_test_time_ms);
        } else {
            baseline_result.timing = task_spec.TimingBreakdown{
                .generation_ms = baseline_result.duration_ms,
                .test_execution_ms = @intCast(baseline_test_time_ms),
                .total_ms = baseline_result.duration_ms + @as(u64, @intCast(baseline_test_time_ms)),
            };
        }

        // Run tests on constrained code with timing
        std.log.info("Running tests on constrained code...", .{});
        var constrained_test_timer = try std.time.Timer.start();
        const constrained_test_result = try self.test_runner.runTests(
            task.language.toString(),
            constrained_result.code,
            task.test_suite_path,
        );
        const constrained_test_time_ms = constrained_test_timer.read() / std.time.ns_per_ms;

        // Update constrained timing with test execution time
        if (constrained_result.timing) |*timing| {
            timing.test_execution_ms = @intCast(constrained_test_time_ms);
            timing.total_ms += @intCast(constrained_test_time_ms);
        }

        // Score code quality (comparative analysis)
        std.log.info("Scoring code quality...", .{});
        const raw_constraints = try self.loadConstraints(task.constraint_path);
        defer self.allocator.free(raw_constraints);

        var scorer = quality_scorer.QualityScorer.init(self.allocator, task.language.toString());
        const quality_results = scorer.compare(
            constrained_result.code,
            baseline_result.code,
            raw_constraints,
        );

        return EvaluationPair{
            .task_id = try self.allocator.dupe(u8, task.id),
            .baseline = baseline_result,
            .constrained = constrained_result,
            .baseline_tests = baseline_test_result,
            .constrained_tests = constrained_test_result,
            .baseline_quality = quality_results.unconstrained,
            .constrained_quality = quality_results.constrained,
            .comparison = quality_results.comparison,
        };
    }

    /// Generate code with constraints (Ananke pipeline)
    /// Uses the constraint compiler to convert eval format to llguidance-compatible format
    fn generateConstrained(self: *Evaluator, task: task_spec.TaskSpec) !task_spec.GenerationResult {
        var total_timer = try std.time.Timer.start();

        // Load raw constraints from file
        const raw_constraints_json = try self.loadConstraints(task.constraint_path);
        defer self.allocator.free(raw_constraints_json);

        // Track constraint compilation time (Braid compilation)
        var compile_timer = try std.time.Timer.start();

        // Compile constraints to llguidance-compatible format
        // This is the Ananke compilation step: eval format → llguidance JSON
        std.log.info("Compiling constraints for task: {s}", .{task.id});
        const compiled_constraints = try constraint_compiler.compileForModal(
            self.allocator,
            raw_constraints_json,
        );
        defer self.allocator.free(compiled_constraints);

        const compile_time_ms = compile_timer.read() / std.time.ns_per_ms;

        // Build prompt (similar to baseline but will use constraints)
        const prompt = try self.buildConstrainedPrompt(task);
        defer self.allocator.free(prompt);

        const max_tokens: u32 = @min(task.expected_loc * 20, 4096);

        // Track generation time
        var gen_timer = try std.time.Timer.start();

        // Create Modal client and generate with compiled constraints
        var client = modal_client.ModalClient.init(self.allocator, self.base_url);
        defer client.deinit();

        var result = try client.generateConstrained(prompt, compiled_constraints, max_tokens);

        const generation_time_ms = gen_timer.read() / std.time.ns_per_ms;
        const total_time_ms = total_timer.read() / std.time.ns_per_ms;

        // Set task_id
        self.allocator.free(result.task_id);
        result.task_id = try self.allocator.dupe(u8, task.id);

        // Add timing breakdown
        result.timing = task_spec.TimingBreakdown{
            .constraint_compilation_ms = @intCast(compile_time_ms),
            .generation_ms = @intCast(generation_time_ms),
            .test_execution_ms = 0, // Filled in by caller after running tests
            .total_ms = @intCast(total_time_ms),
        };

        return result;
    }

    /// Load constraints from file
    /// File format: {"task_id": "...", "constraints": {...}}
    /// Returns the entire file content - Modal service handles nested structure
    fn loadConstraints(self: *Evaluator, path: []const u8) ![]const u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        return try file.readToEndAlloc(self.allocator, 1024 * 1024);
    }

    /// Build prompt for constrained generation
    fn buildConstrainedPrompt(self: *Evaluator, task: task_spec.TaskSpec) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 1024);
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);

        try writer.print("Generate {s} code for the following task:\n\n", .{task.language.toString()});
        try writer.print("Title: {s}\n", .{task.title});
        try writer.print("Description: {s}\n\n", .{task.description});

        if (task.requirements.len > 0) {
            try writer.writeAll("Requirements:\n");
            for (task.requirements) |req| {
                try writer.print("- {s}\n", .{req});
            }
        }

        return try buf.toOwnedSlice(self.allocator);
    }

    /// Run evaluation on multiple tasks
    pub fn evaluateBatch(
        self: *Evaluator,
        tasks: []const task_spec.TaskSpec,
    ) ![]EvaluationPair {
        var results = try self.allocator.alloc(EvaluationPair, tasks.len);
        errdefer self.allocator.free(results);

        for (tasks, 0..) |task, i| {
            results[i] = try self.evaluateTask(task);
        }

        return results;
    }
};

/// Pair of generation results for comparison
pub const EvaluationPair = struct {
    task_id: []const u8,
    baseline: task_spec.GenerationResult,
    constrained: task_spec.GenerationResult,
    baseline_tests: test_runner.TestResult,
    constrained_tests: test_runner.TestResult,

    // Quality scores (optional for backwards compatibility)
    baseline_quality: ?quality_scorer.QualityScore = null,
    constrained_quality: ?quality_scorer.QualityScore = null,
    comparison: ?quality_scorer.ComparativeAnalysis = null,

    pub fn deinit(self: *EvaluationPair, allocator: Allocator) void {
        allocator.free(self.task_id);
        var mut_baseline = self.baseline;
        mut_baseline.deinit(allocator);
        var mut_constrained = self.constrained;
        mut_constrained.deinit(allocator);
        var mut_baseline_tests = self.baseline_tests;
        mut_baseline_tests.deinit(allocator);
        var mut_constrained_tests = self.constrained_tests;
        mut_constrained_tests.deinit(allocator);
    }

    /// Serialize to JSON string
    pub fn toJson(self: EvaluationPair, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 2048);
        defer buf.deinit(allocator);

        const writer = buf.writer(allocator);

        try writer.writeAll("{");
        try writer.print("\"task_id\":\"{s}\",", .{self.task_id});

        // Baseline generation results
        try writer.writeAll("\"baseline\":{");
        try writer.print("\"task_id\":\"{s}\",", .{self.baseline.task_id});
        try writer.print("\"mode\":\"{s}\",", .{@tagName(self.baseline.mode)});
        try writer.print("\"duration_ms\":{d},", .{self.baseline.duration_ms});
        try writer.print("\"success\":{},", .{self.baseline.success});

        // Baseline test results
        try writer.writeAll("\"tests\":{");
        try writer.print("\"success\":{},", .{self.baseline_tests.success});
        try writer.print("\"total_tests\":{d},", .{self.baseline_tests.total_tests});
        try writer.print("\"passed_tests\":{d},", .{self.baseline_tests.passed_tests});
        try writer.print("\"failed_tests\":{d},", .{self.baseline_tests.failed_tests});
        try writer.print("\"duration_ms\":{d},", .{self.baseline_tests.duration_ms});
        try writer.print("\"coverage_percent\":{d}", .{self.baseline_tests.coverage_percent});
        try writer.writeAll("},");

        // Baseline timing breakdown
        if (self.baseline.timing) |timing| {
            try writer.writeAll("\"timing\":{");
            try writer.print("\"constraint_compilation_ms\":{d},", .{timing.constraint_compilation_ms});
            try writer.print("\"generation_ms\":{d},", .{timing.generation_ms});
            try writer.print("\"test_execution_ms\":{d},", .{timing.test_execution_ms});
            try writer.print("\"total_ms\":{d},", .{timing.total_ms});
            try writer.print("\"overhead_ms\":{d}", .{timing.overheadMs()});
            try writer.writeAll("}");
        } else {
            try writer.writeAll("\"timing\":null");
        }
        try writer.writeAll("},");

        // Constrained generation results
        try writer.writeAll("\"constrained\":{");
        try writer.print("\"task_id\":\"{s}\",", .{self.constrained.task_id});
        try writer.print("\"mode\":\"{s}\",", .{@tagName(self.constrained.mode)});
        try writer.print("\"duration_ms\":{d},", .{self.constrained.duration_ms});
        try writer.print("\"success\":{},", .{self.constrained.success});

        // Constrained test results
        try writer.writeAll("\"tests\":{");
        try writer.print("\"success\":{},", .{self.constrained_tests.success});
        try writer.print("\"total_tests\":{d},", .{self.constrained_tests.total_tests});
        try writer.print("\"passed_tests\":{d},", .{self.constrained_tests.passed_tests});
        try writer.print("\"failed_tests\":{d},", .{self.constrained_tests.failed_tests});
        try writer.print("\"duration_ms\":{d},", .{self.constrained_tests.duration_ms});
        try writer.print("\"coverage_percent\":{d}", .{self.constrained_tests.coverage_percent});
        try writer.writeAll("},");

        // Constrained timing breakdown
        if (self.constrained.timing) |timing| {
            try writer.writeAll("\"timing\":{");
            try writer.print("\"constraint_compilation_ms\":{d},", .{timing.constraint_compilation_ms});
            try writer.print("\"generation_ms\":{d},", .{timing.generation_ms});
            try writer.print("\"test_execution_ms\":{d},", .{timing.test_execution_ms});
            try writer.print("\"total_ms\":{d},", .{timing.total_ms});
            try writer.print("\"overhead_ms\":{d}", .{timing.overheadMs()});
            try writer.writeAll("}");
        } else {
            try writer.writeAll("\"timing\":null");
        }
        try writer.writeAll("},");

        // Quality scores
        try writer.writeAll("\"quality\":{");

        // Baseline quality
        if (self.baseline_quality) |bq| {
            try writer.writeAll("\"baseline\":{");
            try writer.print("\"overall\":{d:.2},", .{bq.overall});
            try writer.print("\"constraint_adherence\":{d:.2},", .{bq.constraint_adherence.score});
            try writer.print("\"pattern_conformity\":{d:.2},", .{bq.pattern_conformity.score});
            try writer.print("\"code_quality\":{d:.2},", .{bq.code_quality.score});
            try writer.print("\"security\":{d:.2}", .{bq.security.score});
            try writer.writeAll("},");
        } else {
            try writer.writeAll("\"baseline\":null,");
        }

        // Constrained quality
        if (self.constrained_quality) |cq| {
            try writer.writeAll("\"constrained\":{");
            try writer.print("\"overall\":{d:.2},", .{cq.overall});
            try writer.print("\"constraint_adherence\":{d:.2},", .{cq.constraint_adherence.score});
            try writer.print("\"pattern_conformity\":{d:.2},", .{cq.pattern_conformity.score});
            try writer.print("\"code_quality\":{d:.2},", .{cq.code_quality.score});
            try writer.print("\"security\":{d:.2}", .{cq.security.score});
            try writer.writeAll("},");
        } else {
            try writer.writeAll("\"constrained\":null,");
        }

        // Comparative analysis
        if (self.comparison) |comp| {
            try writer.writeAll("\"comparison\":{");
            try writer.print("\"overall_delta\":{d:.2},", .{comp.overall_delta});
            try writer.print("\"winner\":\"{s}\"", .{@tagName(comp.winner.overall)});
            try writer.writeAll("}");
        } else {
            try writer.writeAll("\"comparison\":null");
        }

        try writer.writeAll("}");
        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};
