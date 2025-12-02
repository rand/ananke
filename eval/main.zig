const std = @import("std");
const runner = @import("runner");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "run")) {
        try runCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "list")) {
        try listCommand(allocator);
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n\n", .{command});
        try printUsage();
        return error.InvalidCommand;
    }
}

fn printUsage() !void {
    const usage =
        \\Ananke Evaluation Framework
        \\
        \\Usage:
        \\  ananke-eval run [options]           Run evaluation on tasks
        \\  ananke-eval list                    List available tasks
        \\  ananke-eval help                    Show this help message
        \\
        \\Options for 'run':
        \\  --endpoint <url>                    Modal inference base URL (required)
        \\  --tasks <id1,id2,...>               Specific task IDs to run (default: all)
        \\  --output <dir>                      Output directory (default: eval/results)
        \\  --task-dir <dir>                    Task definitions directory (default: eval/tasks/definitions)
        \\
        \\Examples:
        \\  # Run all tasks
        \\  ananke-eval run \
        \\    --endpoint https://rand--ananke-eval-inference-inferenceservice-fastapi-app.modal.run
        \\
        \\  # Run specific tasks
        \\  ananke-eval run \
        \\    --endpoint https://rand--ananke-eval-inference-inferenceservice-fastapi-app.modal.run \
        \\    --tasks algo_001_binary_search,api_001_request_validator
        \\
        \\  # List available tasks
        \\  ananke-eval list
        \\
    ;
    std.debug.print("{s}\n", .{usage});
}

fn runCommand(allocator: std.mem.Allocator, args: []const [:0]const u8) !void {
    var endpoint: ?[]const u8 = null;
    var task_ids_str: ?[]const u8 = null;
    var output_dir: []const u8 = "eval/results";
    var task_dir: []const u8 = "eval/tasks/definitions";

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--endpoint")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --endpoint requires a value\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            endpoint = args[i];
        } else if (std.mem.eql(u8, arg, "--tasks")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --tasks requires a value\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            task_ids_str = args[i];
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --output requires a value\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            output_dir = args[i];
        } else if (std.mem.eql(u8, arg, "--task-dir")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --task-dir requires a value\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            task_dir = args[i];
        } else {
            std.debug.print("Unknown option: {s}\n", .{arg});
            return error.UnknownOption;
        }
    }

    if (endpoint == null) {
        std.debug.print("Error: --endpoint is required\n", .{});
        return error.MissingRequiredArgument;
    }

    // Initialize runner
    var eval_runner = try runner.EvaluationRunner.init(
        allocator,
        endpoint.?,
        task_dir,
        output_dir,
    );
    defer eval_runner.deinit();

    // Run evaluation
    if (task_ids_str) |ids_str| {
        // Count comma-separated task IDs
        var count: usize = 1;
        for (ids_str) |c| {
            if (c == ',') count += 1;
        }

        // Allocate array for task IDs
        const task_ids = try allocator.alloc([]const u8, count);
        defer allocator.free(task_ids);

        // Parse comma-separated task IDs
        var iter = std.mem.splitScalar(u8, ids_str, ',');
        var idx: usize = 0;
        while (iter.next()) |task_id| : (idx += 1) {
            task_ids[idx] = std.mem.trim(u8, task_id, " ");
        }

        try eval_runner.runTasks(task_ids);
    } else {
        try eval_runner.runAll();
    }
}

fn listCommand(allocator: std.mem.Allocator) !void {
    const task_dir = "eval/tasks/definitions";

    std.debug.print("Available tasks:\n\n", .{});

    var dir = try std.fs.cwd().openDir(task_dir, .{ .iterate = true });
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        // Read and parse task definition to show details
        const file_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ task_dir, entry.name },
        );
        defer allocator.free(file_path);

        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        // Simple JSON parsing to extract id, title, category, difficulty
        // (This is a simplified version - full implementation would use proper JSON parsing)
        std.debug.print("  {s}\n", .{entry.name});
        count += 1;
    }

    std.debug.print("\nTotal: {d} tasks\n", .{count});
}
