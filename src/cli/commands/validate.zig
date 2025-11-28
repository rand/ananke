// Validate command - Validate code against constraints
const std = @import("std");
const ananke = @import("ananke");
const args_mod = @import("../args.zig");
const output = @import("../output.zig");
const config_mod = @import("../config.zig");
const cli_error = @import("../error.zig");

pub const usage =
    \\Usage: ananke validate <code-file> [options]
    \\
    \\Validate code against a set of constraints.
    \\
    \\Arguments:
    \\  <code-file>             Source code file to validate
    \\
    \\Options:
    \\  --constraints, -c <file> Validate against constraints from file
    \\  --strict                Treat warnings as errors
    \\  --report <file>         Write validation report to file
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke validate src/auth.ts -c constraints.json
    \\  ananke validate lib.rs --strict --report validation.txt
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    _ = config;

    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const file_path = parsed_args.getPositional(0) catch {
        cli_error.printError("Missing required argument: <code-file>", .{});
        std.debug.print("\n{s}\n", .{usage});
        return error.MissingArgument;
    };

    const constraints_file = parsed_args.getFlag("constraints") orelse parsed_args.getFlag("c");
    const strict = parsed_args.hasFlag("strict");
    const report_file = parsed_args.getFlag("report");
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    if (verbose) {
        cli_error.printInfo("Validating: {s}", .{file_path});
        if (strict) {
            cli_error.printInfo("Strict mode: warnings treated as errors", .{});
        }
    }

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        cli_error.printFileError(err, file_path);
        return err;
    };
    defer allocator.free(source);

    // Load constraints
    // Use an arena allocator for JSON-parsed constraints to avoid manual memory management
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var constraint_set: ?ananke.ConstraintSet = null;
    defer {
        if (constraint_set) |*cs| {
            cs.deinit();
        }
    }

    if (constraints_file) |path| {
        if (verbose) {
            cli_error.printInfo("Loading constraints from: {s}", .{path});
        }

        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer allocator.free(constraints_json);

        // Parse constraints using arena allocator - all strings will be freed when arena is freed
        constraint_set = parseConstraintsJson(arena_allocator, constraints_json) catch |err| {
            cli_error.printError("Failed to parse constraints: {s}", .{@errorName(err)});
            return err;
        };
    } else {
        // Extract constraints from code itself
        if (verbose) {
            cli_error.printInfo("No constraints file specified, extracting from code", .{});
        }

        var ananke_instance = try ananke.Ananke.init(allocator);
        defer ananke_instance.deinit();

        const language = detectLanguage(file_path);
        constraint_set = try ananke_instance.extract(source, language);
    }

    const cs = constraint_set.?;
    if (verbose) {
        cli_error.printInfo("Validating against {d} constraints", .{cs.constraints.items.len});
    }

    // Perform validation
    std.debug.print("\nValidation Results:\n\n", .{});

    var violations_found: usize = 0;
    var warnings_found: usize = 0;

    for (cs.constraints.items) |constraint| {
        const validated = validateConstraint(source, constraint);

        if (!validated) {
            if (constraint.severity == .err) {
                violations_found += 1;
                std.debug.print("  ✗ ERROR: {s}\n", .{constraint.name});
            } else if (constraint.severity == .warning) {
                warnings_found += 1;
                std.debug.print("  ⚠ WARNING: {s}\n", .{constraint.name});
            } else {
                std.debug.print("  ℹ INFO: {s}\n", .{constraint.name});
            }
            std.debug.print("    Description: {s}\n", .{constraint.description});
            std.debug.print("    Kind: {s}\n\n", .{@tagName(constraint.kind)});
        }
    }

    // Write report if requested
    if (report_file) |path| {
        const report = try generateReport(allocator, violations_found, warnings_found, cs);
        defer allocator.free(report);

        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer file.close();
        try file.writeAll(report);
        cli_error.printSuccess("Validation report written to {s}", .{path});
    }

    // Summary
    cli_error.printValidationSummary(violations_found, warnings_found);

    // Exit with error if validation failed
    if (violations_found > 0 or (strict and warnings_found > 0)) {
        return error.ValidationFailed;
    }
}

fn detectLanguage(file_path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, file_path, ".ts") or std.mem.endsWith(u8, file_path, ".tsx")) return "typescript";
    if (std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".jsx")) return "javascript";
    if (std.mem.endsWith(u8, file_path, ".py")) return "python";
    if (std.mem.endsWith(u8, file_path, ".rs")) return "rust";
    if (std.mem.endsWith(u8, file_path, ".go")) return "go";
    if (std.mem.endsWith(u8, file_path, ".zig")) return "zig";
    return "unknown";
}

fn validateConstraint(source: []const u8, constraint: ananke.Constraint) bool {
    // Simple validation logic
    switch (constraint.kind) {
        .type_safety => {
            if (std.mem.eql(u8, constraint.name, "avoid_any_type")) {
                return std.mem.indexOf(u8, source, ": any") == null;
            }
        },
        .syntactic => {
            if (std.mem.eql(u8, constraint.name, "has_functions")) {
                return std.mem.indexOf(u8, source, "function") != null or
                    std.mem.indexOf(u8, source, "fn") != null;
            }
        },
        else => {},
    }
    return true;
}

fn parseConstraintsJson(allocator: std.mem.Allocator, json_str: []const u8) !ananke.ConstraintSet {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    const name = root.get("name").?.string;
    const constraints_array = root.get("constraints").?.array;

    var constraint_set = ananke.ConstraintSet.init(allocator, try allocator.dupe(u8, name));

    for (constraints_array.items) |constraint_value| {
        const constraint_obj = constraint_value.object;
        const kind_str = constraint_obj.get("kind").?.string;
        const severity_str = constraint_obj.get("severity").?.string;
        const constraint_name = constraint_obj.get("name").?.string;
        const description = constraint_obj.get("description").?.string;

        const constraint = ananke.Constraint{
            .kind = parseConstraintKind(kind_str),
            .severity = parseSeverity(severity_str),
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

fn generateReport(allocator: std.mem.Allocator, violations: usize, warnings: usize, cs: ananke.ConstraintSet) ![]u8 {
    var list = std.ArrayList(u8){};
    const writer = list.writer(allocator);

    try writer.writeAll("Ananke Validation Report\n");
    try writer.writeAll("=" ** 70);
    try writer.writeAll("\n\n");
    try writer.print("Total Constraints: {d}\n", .{cs.constraints.items.len});
    try writer.print("Violations: {d}\n", .{violations});
    try writer.print("Warnings: {d}\n\n", .{warnings});

    if (violations == 0 and warnings == 0) {
        try writer.writeAll("✓ All constraints satisfied\n");
    } else {
        try writer.writeAll("Issues found:\n\n");
        for (cs.constraints.items) |constraint| {
            try writer.print("  - {s}: {s}\n", .{ @tagName(constraint.severity), constraint.name });
        }
    }

    return list.toOwnedSlice(allocator);
}
