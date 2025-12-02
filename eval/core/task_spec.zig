const std = @import("std");
const Allocator = std.mem.Allocator;

/// Task category for benchmark classification
pub const TaskCategory = enum {
    algorithms,
    api,
    concurrency,
    data_processing,
    data_structures,
    database,
    file_io,
    mathematics,
    security,
    string_processing,
    system_utilities,
    web_components,

    pub fn toString(self: TaskCategory) []const u8 {
        return switch (self) {
            .algorithms => "algorithms",
            .api => "api",
            .concurrency => "concurrency",
            .data_processing => "data_processing",
            .data_structures => "data_structures",
            .database => "database",
            .file_io => "file_io",
            .mathematics => "mathematics",
            .security => "security",
            .string_processing => "string_processing",
            .system_utilities => "system_utilities",
            .web_components => "web_components",
        };
    }

    pub fn fromString(s: []const u8) ?TaskCategory {
        if (std.mem.eql(u8, s, "algorithms")) return .algorithms;
        if (std.mem.eql(u8, s, "api")) return .api;
        if (std.mem.eql(u8, s, "concurrency")) return .concurrency;
        if (std.mem.eql(u8, s, "data_processing")) return .data_processing;
        if (std.mem.eql(u8, s, "data_structures")) return .data_structures;
        if (std.mem.eql(u8, s, "database")) return .database;
        if (std.mem.eql(u8, s, "file_io")) return .file_io;
        if (std.mem.eql(u8, s, "mathematics")) return .mathematics;
        if (std.mem.eql(u8, s, "security")) return .security;
        if (std.mem.eql(u8, s, "string_processing")) return .string_processing;
        if (std.mem.eql(u8, s, "system_utilities")) return .system_utilities;
        if (std.mem.eql(u8, s, "web_components")) return .web_components;
        return null;
    }
};

/// Task difficulty level
pub const DifficultyLevel = enum {
    simple,
    medium,
    moderate,
    complex,

    pub fn toString(self: DifficultyLevel) []const u8 {
        return switch (self) {
            .simple => "simple",
            .medium => "medium",
            .moderate => "moderate",
            .complex => "complex",
        };
    }

    pub fn fromString(s: []const u8) ?DifficultyLevel {
        if (std.mem.eql(u8, s, "simple")) return .simple;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "moderate")) return .moderate;
        if (std.mem.eql(u8, s, "complex")) return .complex;
        return null;
    }
};

/// Target programming language
pub const Language = enum {
    typescript,
    python,

    pub fn toString(self: Language) []const u8 {
        return switch (self) {
            .typescript => "typescript",
            .python => "python",
        };
    }

    pub fn fromString(s: []const u8) ?Language {
        if (std.mem.eql(u8, s, "typescript")) return .typescript;
        if (std.mem.eql(u8, s, "python")) return .python;
        return null;
    }

    pub fn fileExtension(self: Language) []const u8 {
        return switch (self) {
            .typescript => ".ts",
            .python => ".py",
        };
    }
};

/// Few-shot example for baseline generation
pub const FewShotExample = struct {
    prompt: []const u8,
    code: []const u8,

    pub fn deinit(self: *FewShotExample, allocator: Allocator) void {
        allocator.free(self.prompt);
        allocator.free(self.code);
    }
};

/// Task specification for evaluation
pub const TaskSpec = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    category: TaskCategory,
    language: Language,
    difficulty: DifficultyLevel,
    requirements: [][]const u8,
    reference_impl_path: []const u8,
    test_suite_path: []const u8,
    constraint_path: []const u8,
    few_shot_examples: []FewShotExample,
    expected_loc: u32,

    pub fn deinit(self: *TaskSpec, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.title);
        allocator.free(self.description);
        for (self.requirements) |req| {
            allocator.free(req);
        }
        allocator.free(self.requirements);
        allocator.free(self.reference_impl_path);
        allocator.free(self.test_suite_path);
        allocator.free(self.constraint_path);
        for (self.few_shot_examples) |*example| {
            example.deinit(allocator);
        }
        allocator.free(self.few_shot_examples);
    }

    /// Parse task specification from JSON content
    pub fn fromJson(allocator: Allocator, json_content: []const u8) !TaskSpec {
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            json_content,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        // Extract fields
        const id = try allocator.dupe(u8, root.get("id").?.string);
        errdefer allocator.free(id);

        const title = try allocator.dupe(u8, root.get("title").?.string);
        errdefer allocator.free(title);

        const description = try allocator.dupe(u8, root.get("description").?.string);
        errdefer allocator.free(description);

        const category = TaskCategory.fromString(root.get("category").?.string) orelse
            return error.InvalidCategory;

        const language = Language.fromString(root.get("language").?.string) orelse
            return error.InvalidLanguage;

        const difficulty = DifficultyLevel.fromString(root.get("difficulty").?.string) orelse
            return error.InvalidDifficulty;

        // Parse requirements array
        const req_array = root.get("requirements").?.array;
        const requirements = try allocator.alloc([]const u8, req_array.items.len);
        errdefer {
            for (requirements) |req| allocator.free(req);
            allocator.free(requirements);
        }
        for (req_array.items, 0..) |item, i| {
            requirements[i] = try allocator.dupe(u8, item.string);
        }

        const reference_impl_path = try allocator.dupe(u8, root.get("reference_impl_path").?.string);
        errdefer allocator.free(reference_impl_path);

        const test_suite_path = try allocator.dupe(u8, root.get("test_suite_path").?.string);
        errdefer allocator.free(test_suite_path);

        const constraint_path = try allocator.dupe(u8, root.get("constraint_path").?.string);
        errdefer allocator.free(constraint_path);

        const expected_loc = @as(u32, @intCast(root.get("expected_loc").?.integer));

        // Parse few-shot examples
        const examples_array = root.get("few_shot_examples").?.array;
        const few_shot_examples = try allocator.alloc(FewShotExample, examples_array.items.len);
        errdefer {
            for (few_shot_examples) |*ex| ex.deinit(allocator);
            allocator.free(few_shot_examples);
        }
        for (examples_array.items, 0..) |item, i| {
            const example_obj = item.object;
            few_shot_examples[i] = FewShotExample{
                .prompt = try allocator.dupe(u8, example_obj.get("prompt").?.string),
                .code = try allocator.dupe(u8, example_obj.get("code").?.string),
            };
        }

        return TaskSpec{
            .id = id,
            .title = title,
            .description = description,
            .category = category,
            .language = language,
            .difficulty = difficulty,
            .requirements = requirements,
            .reference_impl_path = reference_impl_path,
            .test_suite_path = test_suite_path,
            .constraint_path = constraint_path,
            .few_shot_examples = few_shot_examples,
            .expected_loc = expected_loc,
        };
    }

    /// Validate that all referenced files exist
    pub fn validate(self: TaskSpec) !void {
        // Check reference implementation exists
        std.fs.cwd().access(self.reference_impl_path, .{}) catch |err| {
            std.debug.print("Reference implementation not found: {s}\n", .{self.reference_impl_path});
            return err;
        };

        // Check test suite exists
        std.fs.cwd().access(self.test_suite_path, .{}) catch |err| {
            std.debug.print("Test suite not found: {s}\n", .{self.test_suite_path});
            return err;
        };

        // Check constraints exist
        std.fs.cwd().access(self.constraint_path, .{}) catch |err| {
            std.debug.print("Constraint file not found: {s}\n", .{self.constraint_path});
            return err;
        };
    }
};

/// Detailed timing breakdown for a generation attempt
pub const TimingBreakdown = struct {
    /// Time spent compiling constraints (Braid compilation, 0 for baseline)
    constraint_compilation_ms: u64 = 0,
    /// Time spent in inference API call (vLLM generation)
    generation_ms: u64 = 0,
    /// Time spent running tests on generated code
    test_execution_ms: u64 = 0,
    /// Total end-to-end time (may include overhead not in above)
    total_ms: u64 = 0,

    /// Calculate the overhead (network, parsing, etc.)
    pub fn overheadMs(self: TimingBreakdown) u64 {
        const sum = self.constraint_compilation_ms + self.generation_ms + self.test_execution_ms;
        return if (self.total_ms > sum) self.total_ms - sum else 0;
    }

    /// Serialize to JSON
    pub fn toJson(self: TimingBreakdown, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer buf.deinit(allocator);

        const writer = buf.writer(allocator);
        try writer.writeAll("{");
        try writer.print("\"constraint_compilation_ms\":{d},", .{self.constraint_compilation_ms});
        try writer.print("\"generation_ms\":{d},", .{self.generation_ms});
        try writer.print("\"test_execution_ms\":{d},", .{self.test_execution_ms});
        try writer.print("\"total_ms\":{d},", .{self.total_ms});
        try writer.print("\"overhead_ms\":{d}", .{self.overheadMs()});
        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};

/// Result of a generation attempt
pub const GenerationResult = struct {
    task_id: []const u8,
    mode: GenerationMode,
    code: []const u8,
    duration_ms: u64,
    success: bool,
    error_msg: ?[]const u8,
    /// Detailed timing breakdown (optional for backwards compatibility)
    timing: ?TimingBreakdown = null,

    pub fn deinit(self: *GenerationResult, allocator: Allocator) void {
        allocator.free(self.task_id);
        allocator.free(self.code);
        if (self.error_msg) |msg| {
            allocator.free(msg);
        }
    }
};

/// Generation mode: constrained (WITH Ananke) or unconstrained (WITHOUT)
pub const GenerationMode = enum {
    constrained, // WITH Ananke constraints
    unconstrained, // WITHOUT constraints (baseline)

    pub fn toString(self: GenerationMode) []const u8 {
        return switch (self) {
            .constrained => "constrained",
            .unconstrained => "unconstrained",
        };
    }
};

/// Evaluation metrics for a single task
pub const TaskMetrics = struct {
    task_id: []const u8,
    mode: GenerationMode,

    // Correctness metrics
    compiles: bool,
    tests_passed: u32,
    tests_failed: u32,
    tests_total: u32,

    // Constraint satisfaction
    constraints_satisfied: u32,
    constraints_violated: u32,
    constraints_total: u32,

    // Code quality
    cyclomatic_complexity: f32,
    maintainability_index: f32,
    loc: u32,
    type_coverage_pct: f32,

    // Security
    vulnerabilities_found: u32,
    vulnerability_severity: []const u8,

    // Efficiency
    generation_time_ms: u64,

    pub fn deinit(self: *TaskMetrics, allocator: Allocator) void {
        allocator.free(self.task_id);
        allocator.free(self.vulnerability_severity);
    }
};
