const std = @import("std");
const Evaluator = @import("eval_evaluator").Evaluator;
const EvaluationConfig = @import("eval_evaluator").EvaluationConfig;
const TaskSpec = @import("eval_task_spec").TaskSpec;

pub const EvaluationRunner = struct {
    allocator: std.mem.Allocator,
    evaluator: Evaluator,
    config: EvaluationConfig,
    task_definitions_dir: []const u8,
    output_dir: []const u8,
    /// Track run start time for duration calculation
    run_start_time: i64,

    pub fn init(
        allocator: std.mem.Allocator,
        base_url: []const u8,
        task_definitions_dir: []const u8,
        output_dir: []const u8,
    ) !EvaluationRunner {
        const evaluator = Evaluator.init(allocator, base_url);
        const config = try EvaluationConfig.initDefault(allocator, base_url);

        return .{
            .allocator = allocator,
            .evaluator = evaluator,
            .config = config,
            .task_definitions_dir = task_definitions_dir,
            .output_dir = output_dir,
            .run_start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *EvaluationRunner) void {
        self.evaluator.deinit();
        var config = self.config;
        config.deinit(self.allocator);
    }

    /// Load all task definitions from the tasks directory
    pub fn loadTasks(self: *EvaluationRunner, tasks_list: *std.ArrayList(TaskSpec)) !void {
        var dir = try std.fs.cwd().openDir(self.task_definitions_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            // Read task definition file
            const file_path = try std.fs.path.join(
                self.allocator,
                &[_][]const u8{ self.task_definitions_dir, entry.name },
            );
            defer self.allocator.free(file_path);

            const file = try std.fs.cwd().openFile(file_path, .{});
            defer file.close();

            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(content);

            // Parse task spec
            const task = try TaskSpec.fromJson(self.allocator, content);
            try tasks_list.append(self.allocator, task);
        }
    }

    /// Run evaluation on all tasks
    pub fn runAll(self: *EvaluationRunner) !void {
        const TaskList = std.ArrayList(TaskSpec);
        var tasks_list = try TaskList.initCapacity(self.allocator, 0);
        defer {
            for (tasks_list.items) |*task| {
                task.deinit(self.allocator);
            }
            tasks_list.deinit(self.allocator);
        }

        try self.loadTasks(&tasks_list);

        std.debug.print("Loaded {d} tasks\n", .{tasks_list.items.len});

        // Create output directory
        std.fs.cwd().makeDir(self.output_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Initialize statistics tracking
        var stats = RunStats{
            .total_tasks = @intCast(tasks_list.items.len),
        };

        // Evaluate each task
        for (tasks_list.items) |task| {
            std.debug.print("\n=== Evaluating: {s} ===\n", .{task.id});

            var result = self.evaluator.evaluateTask(task) catch |err| {
                std.debug.print("Error evaluating task {s}: {}\n", .{ task.id, err });
                stats.failed_tasks += 1;
                continue;
            };
            defer result.deinit(self.allocator);

            // Update statistics
            stats.completed_tasks += 1;
            stats.total_baseline_duration_ms += result.baseline.duration_ms;
            stats.total_constrained_duration_ms += result.constrained.duration_ms;
            stats.total_baseline_tests_passed += result.baseline_tests.passed_tests;
            stats.total_constrained_tests_passed += result.constrained_tests.passed_tests;

            // Aggregate timing breakdown stats
            if (result.baseline.timing) |timing| {
                stats.total_generation_ms_baseline += timing.generation_ms;
                stats.total_test_execution_ms_baseline += timing.test_execution_ms;
            }
            if (result.constrained.timing) |timing| {
                stats.total_constraint_compilation_ms += timing.constraint_compilation_ms;
                stats.total_generation_ms_constrained += timing.generation_ms;
                stats.total_test_execution_ms_constrained += timing.test_execution_ms;
            }

            // Determine winner based on quality comparison
            if (result.comparison) |comp| {
                const winner_tag = @tagName(comp.winner.overall);
                if (std.mem.eql(u8, winner_tag, "constrained")) {
                    stats.constrained_wins += 1;
                } else if (std.mem.eql(u8, winner_tag, "baseline")) {
                    stats.baseline_wins += 1;
                } else {
                    stats.ties += 1;
                }
            } else {
                // Fallback: compare test pass rates
                if (result.constrained_tests.passed_tests > result.baseline_tests.passed_tests) {
                    stats.constrained_wins += 1;
                } else if (result.baseline_tests.passed_tests > result.constrained_tests.passed_tests) {
                    stats.baseline_wins += 1;
                } else {
                    stats.ties += 1;
                }
            }

            // Save results
            try self.saveResults(task.id, result);

            std.debug.print("Completed: {s}\n", .{task.id});
            std.debug.print("  Constrained: {d} ms, success={}\n", .{
                result.constrained.duration_ms,
                result.constrained.success,
            });
            std.debug.print("  Baseline: {d} ms, success={}\n", .{
                result.baseline.duration_ms,
                result.baseline.success,
            });
        }

        // Calculate run duration
        stats.run_duration_seconds = std.time.timestamp() - self.run_start_time;

        // Save run summary with config and statistics
        try self.saveRunSummary(stats);

        std.debug.print("\n=== Evaluation Complete ===\n", .{});
        std.debug.print("Results saved to: {s}\n", .{self.output_dir});
        std.debug.print("Summary: {d}/{d} tasks completed, constrained won {d}, baseline won {d}, ties {d}\n", .{
            stats.completed_tasks,
            stats.total_tasks,
            stats.constrained_wins,
            stats.baseline_wins,
            stats.ties,
        });
    }

    /// Run evaluation on specific tasks by ID
    pub fn runTasks(self: *EvaluationRunner, task_ids: []const []const u8) !void {
        const TaskList = std.ArrayList(TaskSpec);
        var all_tasks = try TaskList.initCapacity(self.allocator, 0);
        defer {
            for (all_tasks.items) |*task| {
                task.deinit(self.allocator);
            }
            all_tasks.deinit(self.allocator);
        }

        try self.loadTasks(&all_tasks);

        // Filter tasks by ID
        var selected_tasks = try std.ArrayList(TaskSpec).initCapacity(self.allocator, task_ids.len);
        defer selected_tasks.deinit(self.allocator);

        for (task_ids) |task_id| {
            var found = false;
            for (all_tasks.items) |task| {
                if (std.mem.eql(u8, task.id, task_id)) {
                    try selected_tasks.append(self.allocator, task);
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("Warning: Task not found: {s}\n", .{task_id});
            }
        }

        std.debug.print("Running {d} selected tasks\n", .{selected_tasks.items.len});

        // Create output directory
        std.fs.cwd().makeDir(self.output_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Evaluate selected tasks
        for (selected_tasks.items) |task| {
            std.debug.print("\n=== Evaluating: {s} ===\n", .{task.id});

            var result = self.evaluator.evaluateTask(task) catch |err| {
                std.debug.print("Error evaluating task {s}: {}\n", .{ task.id, err });
                continue;
            };
            defer result.deinit(self.allocator);

            try self.saveResults(task.id, result);

            std.debug.print("Completed: {s}\n", .{task.id});
        }
    }

    /// Save evaluation results to JSON file
    fn saveResults(
        self: *EvaluationRunner,
        task_id: []const u8,
        result: anytype,
    ) !void {
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}_results.json",
            .{ self.output_dir, task_id },
        );
        defer self.allocator.free(filename);

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        // Serialize result to JSON
        const json_str = try result.toJson(self.allocator);
        defer self.allocator.free(json_str);

        try file.writeAll(json_str);
    }

    /// Aggregate statistics for a run
    pub const RunStats = struct {
        total_tasks: u32 = 0,
        completed_tasks: u32 = 0,
        failed_tasks: u32 = 0,
        baseline_wins: u32 = 0,
        constrained_wins: u32 = 0,
        ties: u32 = 0,
        total_baseline_duration_ms: u64 = 0,
        total_constrained_duration_ms: u64 = 0,
        total_baseline_tests_passed: u32 = 0,
        total_constrained_tests_passed: u32 = 0,
        run_duration_seconds: i64 = 0,

        // Timing breakdown aggregates
        total_constraint_compilation_ms: u64 = 0,
        total_generation_ms_baseline: u64 = 0,
        total_generation_ms_constrained: u64 = 0,
        total_test_execution_ms_baseline: u64 = 0,
        total_test_execution_ms_constrained: u64 = 0,
    };

    /// Save run summary with config and aggregate statistics
    pub fn saveRunSummary(self: *EvaluationRunner, stats: RunStats) !void {
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/run_summary.json",
            .{self.output_dir},
        );
        defer self.allocator.free(filename);

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);

        try writer.writeAll("{\n");

        // Write config
        try writer.writeAll("  \"config\": ");
        const config_json = try self.config.toJson(self.allocator);
        defer self.allocator.free(config_json);

        // Indent config JSON
        var config_iter = std.mem.splitScalar(u8, config_json, '\n');
        var first = true;
        while (config_iter.next()) |line| {
            if (!first) {
                try writer.writeAll("\n  ");
            }
            try writer.writeAll(line);
            first = false;
        }
        try writer.writeAll(",\n");

        // Write aggregate statistics
        try writer.writeAll("  \"statistics\": {\n");
        try writer.print("    \"total_tasks\": {d},\n", .{stats.total_tasks});
        try writer.print("    \"completed_tasks\": {d},\n", .{stats.completed_tasks});
        try writer.print("    \"failed_tasks\": {d},\n", .{stats.failed_tasks});
        try writer.print("    \"baseline_wins\": {d},\n", .{stats.baseline_wins});
        try writer.print("    \"constrained_wins\": {d},\n", .{stats.constrained_wins});
        try writer.print("    \"ties\": {d},\n", .{stats.ties});
        try writer.print("    \"avg_baseline_duration_ms\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_baseline_duration_ms / stats.completed_tasks else 0,
        });
        try writer.print("    \"avg_constrained_duration_ms\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_constrained_duration_ms / stats.completed_tasks else 0,
        });
        try writer.print("    \"total_baseline_tests_passed\": {d},\n", .{stats.total_baseline_tests_passed});
        try writer.print("    \"total_constrained_tests_passed\": {d},\n", .{stats.total_constrained_tests_passed});
        try writer.print("    \"run_duration_seconds\": {d}\n", .{stats.run_duration_seconds});
        try writer.writeAll("  },\n");

        // Timing breakdown section
        try writer.writeAll("  \"timing_breakdown\": {\n");
        try writer.print("    \"total_constraint_compilation_ms\": {d},\n", .{stats.total_constraint_compilation_ms});
        try writer.print("    \"avg_constraint_compilation_ms\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_constraint_compilation_ms / stats.completed_tasks else 0,
        });
        try writer.print("    \"total_generation_ms_baseline\": {d},\n", .{stats.total_generation_ms_baseline});
        try writer.print("    \"avg_generation_ms_baseline\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_generation_ms_baseline / stats.completed_tasks else 0,
        });
        try writer.print("    \"total_generation_ms_constrained\": {d},\n", .{stats.total_generation_ms_constrained});
        try writer.print("    \"avg_generation_ms_constrained\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_generation_ms_constrained / stats.completed_tasks else 0,
        });
        try writer.print("    \"total_test_execution_ms_baseline\": {d},\n", .{stats.total_test_execution_ms_baseline});
        try writer.print("    \"avg_test_execution_ms_baseline\": {d},\n", .{
            if (stats.completed_tasks > 0) stats.total_test_execution_ms_baseline / stats.completed_tasks else 0,
        });
        try writer.print("    \"total_test_execution_ms_constrained\": {d},\n", .{stats.total_test_execution_ms_constrained});
        try writer.print("    \"avg_test_execution_ms_constrained\": {d}\n", .{
            if (stats.completed_tasks > 0) stats.total_test_execution_ms_constrained / stats.completed_tasks else 0,
        });
        try writer.writeAll("  }\n");

        try writer.writeAll("}\n");

        const json_str = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(json_str);

        try file.writeAll(json_str);

        std.debug.print("Run summary saved to: {s}\n", .{filename});
    }
};
