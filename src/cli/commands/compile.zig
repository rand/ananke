// Compile command - Compile constraints to IR
const std = @import("std");
const ananke = @import("ananke");
const args_mod = @import("../args.zig");
const output = @import("../output.zig");
const config_mod = @import("../config.zig");
const cli_error = @import("../error.zig");

pub const usage =
    \\Usage: ananke compile <constraints-file> [options]
    \\
    \\Compile constraints to intermediate representation (IR) for use with llguidance.
    \\
    \\Arguments:
    \\  <constraints-file>      JSON/YAML file containing constraints
    \\
    \\Options:
    \\  --format <fmt>          Output format: json, yaml (default: json)
    \\  --output, -o <file>     Write compiled IR to file instead of stdout
    \\  --priority <level>      Priority level: low, medium, high, critical (default: medium)
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke compile constraints.json -o compiled.cir
    \\  ananke compile rules.yaml --priority high --format json
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    _ = config;

    // Check for help flag
    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    // Get required file argument
    const constraints_file = parsed_args.getPositional(0) catch {
        cli_error.printError("Missing required argument: <constraints-file>", .{});
        std.debug.print("\n{s}\n", .{usage});
        return error.MissingArgument;
    };

    // Parse options
    const format_str = parsed_args.getFlagOr("format", "json");
    const output_file = parsed_args.getFlag("output") orelse parsed_args.getFlag("o");
    const priority_str = parsed_args.getFlagOr("priority", "medium");
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    // Validate format
    if (!std.mem.eql(u8, format_str, "json") and !std.mem.eql(u8, format_str, "yaml")) {
        cli_error.printError("Invalid format '{s}'", .{format_str});
        cli_error.printInfo("Valid formats: json, yaml", .{});
        return error.InvalidArgument;
    }

    // Parse priority
    const priority = parsePriority(priority_str) orelse {
        cli_error.printError("Invalid priority '{s}'", .{priority_str});
        cli_error.printInfo("Valid priorities: low, medium, high, critical", .{});
        return error.InvalidArgument;
    };

    if (verbose) {
        cli_error.printInfo("Compiling constraints from: {s}", .{constraints_file});
        cli_error.printInfo("Priority: {s}", .{@tagName(priority)});
    }

    // Read constraints file
    const constraints_json = std.fs.cwd().readFileAlloc(allocator, constraints_file, 10 * 1024 * 1024) catch |err| {
        cli_error.printFileError(err, constraints_file);
        return err;
    };
    defer allocator.free(constraints_json);

    // Parse JSON constraints
    const constraint_set = parseConstraintsJson(allocator, constraints_json) catch |err| {
        cli_error.printError("Failed to parse constraints file: {s}", .{@errorName(err)});
        cli_error.printInfo("Expected JSON format with 'name' and 'constraints' fields", .{});
        return err;
    };
    defer {
        for (constraint_set.constraints.items) |_| {}
        // Constraints owned by constraint_set
    }

    if (verbose) {
        cli_error.printInfo("Loaded {d} constraints", .{constraint_set.constraints.items.len});
    }

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Compile constraints to IR
    var spinner = output.Spinner.init("Compiling constraints to IR...");
    const ir = ananke_instance.compile(constraint_set.constraints.items) catch |err| {
        cli_error.printError("Compilation failed: {s}", .{@errorName(err)});
        return err;
    };
    spinner.finish("Compilation complete");

    // Serialize IR
    const output_text = try output.formatIRJson(allocator, ir);
    defer allocator.free(output_text);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer file.close();

        try file.writeAll(output_text);
        cli_error.printSuccess("Compiled IR written to {s}", .{path});
    } else {
        std.debug.print("{s}", .{output_text});
    }
}

fn parsePriority(s: []const u8) ?ananke.ConstraintPriority {
    if (std.mem.eql(u8, s, "low")) return .Low;
    if (std.mem.eql(u8, s, "medium")) return .Medium;
    if (std.mem.eql(u8, s, "high")) return .High;
    if (std.mem.eql(u8, s, "critical")) return .Critical;
    return null;
}

fn parseConstraintsJson(
    allocator: std.mem.Allocator,
    json_str: []const u8,
) !ananke.ConstraintSet {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value.object;
    const name = root.get("name").?.string;
    const constraints_array = root.get("constraints").?.array;

    var constraint_set = ananke.ConstraintSet.init(
        allocator,
        try allocator.dupe(u8, name),
    );

    for (constraints_array.items) |constraint_value| {
        const constraint_obj = constraint_value.object;

        const kind_str = constraint_obj.get("kind").?.string;
        const severity_str = constraint_obj.get("severity").?.string;
        const constraint_name = constraint_obj.get("name").?.string;
        const description = constraint_obj.get("description").?.string;

        const kind = parseConstraintKind(kind_str);
        const severity = parseSeverity(severity_str);

        const constraint = ananke.Constraint{
            .kind = kind,
            .severity = severity,
            .name = try allocator.dupe(u8, constraint_name),
            .description = try allocator.dupe(u8, description),
            .source = .User_Defined,
            .confidence = if (constraint_obj.get("confidence")) |c| @floatCast(c.float) else 1.0,
        };

        try constraint_set.add(constraint);
    }

    return constraint_set;
}

fn parseConstraintKind(s: []const u8) ananke.ConstraintKind {
    if (std.mem.eql(u8, s, "syntactic")) return .syntactic;
    if (std.mem.eql(u8, s, "type_safety")) return .type_safety;
    if (std.mem.eql(u8, s, "semantic")) return .semantic;
    if (std.mem.eql(u8, s, "architectural")) return .architectural;
    if (std.mem.eql(u8, s, "operational")) return .operational;
    if (std.mem.eql(u8, s, "security")) return .security;
    return .semantic;
}

fn parseSeverity(s: []const u8) ananke.types.constraint.Severity {
    if (std.mem.eql(u8, s, "error") or std.mem.eql(u8, s, "err")) return .err;
    if (std.mem.eql(u8, s, "warning")) return .warning;
    if (std.mem.eql(u8, s, "info")) return .info;
    if (std.mem.eql(u8, s, "hint")) return .hint;
    return .err;
}
