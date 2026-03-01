const std = @import("std");
const task_spec = @import("task_spec");
const modal_client = @import("modal_client");
const baseline = @import("baseline");
const test_runner = @import("test_runner");
const constraint_compiler = @import("constraint_compiler");
const quality_scorer = @import("quality_scorer");
const pass_at_k = @import("metrics/pass_at_k.zig");
const constraint_metrics = @import("metrics/constraint_metrics.zig");
const statistical_tests = @import("metrics/statistical_tests.zig");
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
        /// Sampling temperature (0.0 = deterministic, identical for both modes)
        temperature: f32 = 0.0,
        /// Top-p nucleus sampling (identical for both modes)
        top_p: f32 = 0.95,
        /// Max tokens = expected_loc * multiplier
        max_tokens_multiplier: u32 = 20,
        /// Hard cap on max tokens
        max_tokens_cap: u32 = 4096,
        /// Number of samples per task for pass@k calculation
        samples_per_task: u32 = 5,
        /// Random seed for reproducibility (null = random)
        random_seed: ?u64 = null,
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
        try writer.print("    \"top_p\": {d:.2},\n", .{self.evaluation.top_p});
        try writer.print("    \"max_tokens_multiplier\": {d},\n", .{self.evaluation.max_tokens_multiplier});
        try writer.print("    \"max_tokens_cap\": {d},\n", .{self.evaluation.max_tokens_cap});
        try writer.print("    \"samples_per_task\": {d},\n", .{self.evaluation.samples_per_task});
        if (self.evaluation.random_seed) |seed| {
            try writer.print("    \"random_seed\": {d}\n", .{seed});
        } else {
            try writer.writeAll("    \"random_seed\": null\n");
        }
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

// =============================================================================
// Multi-Sample Evaluation for pass@k
// =============================================================================

/// Result of generating multiple samples for a single task
pub const MultiSampleResult = struct {
    task_id: []const u8,
    mode: task_spec.GenerationMode,
    samples: []pass_at_k.SampleResult,
    pass_at_k_results: pass_at_k.PassAtKResults,
    constraint_result: ?constraint_metrics.TaskConstraintResult,
    total_generation_time_ms: u64,

    pub fn deinit(self: *MultiSampleResult, allocator: Allocator) void {
        allocator.free(self.task_id);
        for (self.samples) |sample| {
            allocator.free(sample.code);
        }
        allocator.free(self.samples);
    }
};

/// Complete multi-sample evaluation result for constrained vs unconstrained comparison
pub const MultiSampleEvaluationResult = struct {
    task_id: []const u8,
    constrained: MultiSampleResult,
    unconstrained: MultiSampleResult,
    /// Statistical comparison of the two modes
    comparison: ?statistical_tests.ComparisonResult,
    /// Constraint satisfaction comparison (CodeIF metrics)
    constraint_comparison: ?constraint_metrics.ConstraintComparison,

    pub fn deinit(self: *MultiSampleEvaluationResult, allocator: Allocator) void {
        allocator.free(self.task_id);
        self.constrained.deinit(allocator);
        self.unconstrained.deinit(allocator);
    }

    /// Get the overall winner based on pass@1
    pub fn getWinner(self: MultiSampleEvaluationResult) enum { constrained, unconstrained, tie } {
        const delta = self.constrained.pass_at_k_results.pass_at_1 - self.unconstrained.pass_at_k_results.pass_at_1;
        if (delta > 0.05) return .constrained;
        if (delta < -0.05) return .unconstrained;
        return .tie;
    }
};

/// Evaluator for multi-sample pass@k evaluation
pub const MultiSampleEvaluator = struct {
    allocator: Allocator,
    base_url: []const u8,
    config: EvaluationConfig,
    baseline_generator: baseline.BaselineGenerator,
    test_runner_inst: test_runner.TestRunner,

    pub fn init(allocator: Allocator, base_url: []const u8, config: EvaluationConfig) MultiSampleEvaluator {
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .config = config,
            .baseline_generator = baseline.BaselineGenerator.init(allocator, base_url),
            .test_runner_inst = test_runner.TestRunner.init(allocator),
        };
    }

    pub fn deinit(self: *MultiSampleEvaluator) void {
        self.baseline_generator.deinit();
    }

    /// Generate multiple samples for a task in a given mode
    pub fn generateSamples(
        self: *MultiSampleEvaluator,
        task: task_spec.TaskSpec,
        mode: task_spec.GenerationMode,
        num_samples: u32,
    ) !MultiSampleResult {
        var samples = try self.allocator.alloc(pass_at_k.SampleResult, num_samples);
        errdefer self.allocator.free(samples);

        var total_time_ms: u64 = 0;
        var correct_count: u32 = 0;
        var constraints_total: u32 = 0;
        var constraints_satisfied: u32 = 0;

        // Load constraints once for all samples
        const raw_constraints = try self.loadConstraints(task.constraint_path);
        defer self.allocator.free(raw_constraints);

        // Generate each sample
        for (0..num_samples) |i| {
            const sample_idx: u32 = @intCast(i);

            const gen_result = switch (mode) {
                .constrained => try self.generateConstrainedSample(task, sample_idx),
                .unconstrained => try self.generateUnconstrainedSample(task, sample_idx),
            };
            defer {
                if (gen_result.error_msg) |msg| self.allocator.free(msg);
            }

            total_time_ms += gen_result.duration_ms;

            // Run tests on generated code
            const test_result = try self.test_runner_inst.runTests(
                task.language.toString(),
                gen_result.code,
                task.test_suite_path,
            );

            // Calculate constraint satisfaction for this sample
            var sample_constraints_satisfied: u32 = 0;
            var sample_constraints_total: u32 = 0;
            if (mode == .constrained) {
                sample_constraints_total = 1;
                sample_constraints_satisfied = if (gen_result.success) @as(u32, 1) else @as(u32, 0);
            }

            const passed_all = test_result.passed_tests == test_result.total_tests and test_result.total_tests > 0;
            if (passed_all) correct_count += 1;

            constraints_total += sample_constraints_total;
            constraints_satisfied += sample_constraints_satisfied;

            samples[i] = pass_at_k.SampleResult{
                .sample_id = sample_idx,
                .passed_all_tests = passed_all,
                .tests_passed = test_result.passed_tests,
                .tests_total = test_result.total_tests,
                .constraints_satisfied = sample_constraints_satisfied,
                .constraints_total = sample_constraints_total,
                .generation_time_ms = gen_result.duration_ms,
                .code = try self.allocator.dupe(u8, gen_result.code),
            };

            // Free test result
            var mut_test = test_result;
            mut_test.deinit(self.allocator);

            // Free generation result (but we already duped the code)
            self.allocator.free(gen_result.task_id);
            self.allocator.free(gen_result.code);
        }

        // Compute pass@k results
        const pass_at_k_results = pass_at_k.PassAtKResults.compute(num_samples, correct_count);

        // Create constraint result if applicable
        const constraint_result: ?constraint_metrics.TaskConstraintResult = if (mode == .constrained) blk: {
            break :blk constraint_metrics.TaskConstraintResult{
                .task_id = task.id,
                .evaluations = &.{},
                .total_constraints = constraints_total,
                .satisfied_constraints = constraints_satisfied,
            };
        } else null;

        return MultiSampleResult{
            .task_id = try self.allocator.dupe(u8, task.id),
            .mode = mode,
            .samples = samples,
            .pass_at_k_results = pass_at_k_results,
            .constraint_result = constraint_result,
            .total_generation_time_ms = total_time_ms,
        };
    }

    /// Run full multi-sample evaluation on a task
    pub fn evaluateTask(
        self: *MultiSampleEvaluator,
        task: task_spec.TaskSpec,
    ) !MultiSampleEvaluationResult {
        const num_samples = self.config.evaluation.samples_per_task;

        std.log.info("Evaluating task {s} with {d} samples per mode", .{ task.id, num_samples });

        // Generate samples for both modes
        var constrained_result = try self.generateSamples(task, .constrained, num_samples);
        errdefer constrained_result.deinit(self.allocator);

        var unconstrained_result = try self.generateSamples(task, .unconstrained, num_samples);
        errdefer unconstrained_result.deinit(self.allocator);

        // Perform statistical comparison if we have enough samples
        var comparison: ?statistical_tests.ComparisonResult = null;
        if (num_samples >= 5) {
            var constrained_rates = try self.allocator.alloc(f64, num_samples);
            defer self.allocator.free(constrained_rates);
            var unconstrained_rates = try self.allocator.alloc(f64, num_samples);
            defer self.allocator.free(unconstrained_rates);

            for (constrained_result.samples, 0..) |sample, idx| {
                constrained_rates[idx] = sample.passRate();
            }
            for (unconstrained_result.samples, 0..) |sample, idx| {
                unconstrained_rates[idx] = sample.passRate();
            }

            comparison = statistical_tests.pairedTTest(constrained_rates, unconstrained_rates);
        }

        // Compute constraint comparison if available
        var constraint_comparison: ?constraint_metrics.ConstraintComparison = null;
        if (constrained_result.constraint_result != null) {
            var all_constrained = try self.allocator.alloc(constraint_metrics.TaskConstraintResult, 1);
            defer self.allocator.free(all_constrained);
            all_constrained[0] = constrained_result.constraint_result.?;

            var all_unconstrained = try self.allocator.alloc(constraint_metrics.TaskConstraintResult, 1);
            defer self.allocator.free(all_unconstrained);
            all_unconstrained[0] = constraint_metrics.TaskConstraintResult{
                .task_id = task.id,
                .evaluations = &.{},
                .total_constraints = 0,
                .satisfied_constraints = 0,
            };

            const constrained_codeif = constraint_metrics.CodeIFMetrics.compute(all_constrained);
            const unconstrained_codeif = constraint_metrics.CodeIFMetrics.compute(all_unconstrained);

            constraint_comparison = constraint_metrics.ConstraintComparison{
                .constrained = constrained_codeif,
                .unconstrained = unconstrained_codeif,
            };
        }

        return MultiSampleEvaluationResult{
            .task_id = try self.allocator.dupe(u8, task.id),
            .constrained = constrained_result,
            .unconstrained = unconstrained_result,
            .comparison = comparison,
            .constraint_comparison = constraint_comparison,
        };
    }

    /// Evaluate multiple tasks and aggregate results
    pub fn evaluateBatch(
        self: *MultiSampleEvaluator,
        tasks: []const task_spec.TaskSpec,
    ) !BatchEvaluationResult {
        var task_results = try self.allocator.alloc(MultiSampleEvaluationResult, tasks.len);
        errdefer self.allocator.free(task_results);

        var constrained_pass_at_1 = try self.allocator.alloc(f64, tasks.len);
        defer self.allocator.free(constrained_pass_at_1);
        var unconstrained_pass_at_1 = try self.allocator.alloc(f64, tasks.len);
        defer self.allocator.free(unconstrained_pass_at_1);

        for (tasks, 0..) |task, idx| {
            task_results[idx] = try self.evaluateTask(task);
            constrained_pass_at_1[idx] = task_results[idx].constrained.pass_at_k_results.pass_at_1;
            unconstrained_pass_at_1[idx] = task_results[idx].unconstrained.pass_at_k_results.pass_at_1;
        }

        const constrained_aggregate = try pass_at_k.AggregatePassAtK.fromValues(
            self.allocator,
            constrained_pass_at_1,
            1,
        );
        const unconstrained_aggregate = try pass_at_k.AggregatePassAtK.fromValues(
            self.allocator,
            unconstrained_pass_at_1,
            1,
        );

        const overall_comparison = statistical_tests.pairedTTest(constrained_pass_at_1, unconstrained_pass_at_1);

        return BatchEvaluationResult{
            .task_results = task_results,
            .constrained_aggregate = constrained_aggregate,
            .unconstrained_aggregate = unconstrained_aggregate,
            .overall_comparison = overall_comparison,
        };
    }

    fn loadConstraints(self: *MultiSampleEvaluator, path: []const u8) ![]const u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        return try file.readToEndAlloc(self.allocator, 1024 * 1024);
    }

    fn generateConstrainedSample(
        self: *MultiSampleEvaluator,
        task: task_spec.TaskSpec,
        sample_idx: u32,
    ) !task_spec.GenerationResult {
        _ = sample_idx;

        var total_timer = try std.time.Timer.start();

        const raw_constraints_json = try self.loadConstraints(task.constraint_path);
        defer self.allocator.free(raw_constraints_json);

        const compiled_constraints = try constraint_compiler.compileForModal(
            self.allocator,
            raw_constraints_json,
        );
        defer self.allocator.free(compiled_constraints);

        const prompt = try self.buildPrompt(task, true);
        defer self.allocator.free(prompt);

        const max_tokens: u32 = @min(
            task.expected_loc * self.config.evaluation.max_tokens_multiplier,
            self.config.evaluation.max_tokens_cap,
        );

        var client = modal_client.ModalClient.init(self.allocator, self.base_url);
        defer client.deinit();

        var result = try client.generateConstrained(prompt, compiled_constraints, max_tokens);
        result.duration_ms = total_timer.read() / std.time.ns_per_ms;

        return result;
    }

    fn generateUnconstrainedSample(
        self: *MultiSampleEvaluator,
        task: task_spec.TaskSpec,
        sample_idx: u32,
    ) !task_spec.GenerationResult {
        _ = sample_idx;

        return try self.baseline_generator.generate(task);
    }

    fn buildPrompt(self: *MultiSampleEvaluator, task: task_spec.TaskSpec, constrained: bool) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 2048);
        errdefer buf.deinit();

        const writer = buf.writer();

        try writer.print("Generate {s} code for the following task:\n\n", .{task.language.toString()});
        try writer.print("Title: {s}\n", .{task.title});
        try writer.print("Description: {s}\n\n", .{task.description});

        if (task.requirements.len > 0) {
            try writer.writeAll("Requirements:\n");
            for (task.requirements) |req| {
                try writer.print("- {s}\n", .{req});
            }
            try writer.writeAll("\n");
        }

        if (constrained) {
            try writer.writeAll("Note: Your output will be automatically validated against structural requirements.\n");
        } else {
            try writer.writeAll("Follow these structural guidelines:\n");
            try writer.writeAll("- Follow the standard patterns and conventions for this language\n");
            try writer.writeAll("- Include proper type annotations where applicable\n");
            try writer.writeAll("- Use meaningful variable and function names\n");
        }

        return try buf.toOwnedSlice();
    }
};

/// Aggregated results from evaluating a batch of tasks
pub const BatchEvaluationResult = struct {
    task_results: []MultiSampleEvaluationResult,
    constrained_aggregate: pass_at_k.AggregatePassAtK,
    unconstrained_aggregate: pass_at_k.AggregatePassAtK,
    overall_comparison: ?statistical_tests.ComparisonResult,

    pub fn deinit(self: *BatchEvaluationResult, allocator: Allocator) void {
        for (self.task_results) |*result| {
            result.deinit(allocator);
        }
        allocator.free(self.task_results);
    }

    /// Get the delta in mean pass@1 (constrained - unconstrained)
    pub fn passAt1Delta(self: BatchEvaluationResult) f64 {
        return self.constrained_aggregate.mean - self.unconstrained_aggregate.mean;
    }

    /// Check if the difference is statistically significant (p < 0.05)
    pub fn isSignificant(self: BatchEvaluationResult) bool {
        if (self.overall_comparison) |comp| {
            return comp.p_value < 0.05;
        }
        return false;
    }

    /// Get effect size interpretation
    pub fn effectSizeInterpretation(self: BatchEvaluationResult) []const u8 {
        if (self.overall_comparison) |comp| {
            return comp.interpretEffectSize();
        }
        return "unknown";
    }
};
