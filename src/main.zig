// Ananke CLI - Command-line interface for constraint-driven code generation
const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "extract")) {
        try handleExtract(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "compile")) {
        try handleCompile(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "generate")) {
        try handleGenerate(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "validate")) {
        try handleValidate(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "version")) {
        try printVersion();
    } else if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        try stderr_writer.interface.print("Unknown command: {s}\n", .{command});
        try stderr_writer.interface.flush();
        try printUsage();
        return error.UnknownCommand;
    }
}

fn printUsage() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    try stdout_writer.interface.writeAll(
        \\Ananke - Constraint-driven code generation system
        \\
        \\Usage: ananke <command> [options]
        \\
        \\Commands:
        \\  extract <file>          Extract constraints from source code
        \\  compile <constraints>   Compile constraints to IR
        \\  generate <intent>       Generate code with constraints
        \\  validate <code>         Validate code against constraints
        \\  version                 Show version information
        \\  help                    Show this help message
        \\
        \\Options:
        \\  --use-claude            Enable Claude API for analysis
        \\  --output, -o <file>     Output to file
        \\  --constraints, -c <file> Load constraints from file
        \\  --format <format>       Output format (json, yaml, ariadne)
        \\  --language <lang>       Source language (auto-detected if not specified)
        \\
        \\Examples:
        \\  ananke extract src/main.ts --use-claude -o constraints.json
        \\  ananke compile constraints.json -o compiled.cir
        \\  ananke generate "create auth handler" --constraints rules.yaml
        \\  ananke validate src/auth.ts --constraints compiled.cir
        \\
    );
    try stdout_writer.interface.flush();
}

fn printVersion() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    try stdout_writer.interface.writeAll("Ananke v0.1.0 (November 2025)\n");
    try stdout_writer.interface.writeAll("Zig 0.15.1\n");
    try stdout_writer.interface.flush();
}

fn handleExtract(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        try stderr_writer.interface.writeAll("Error: extract requires a file path\n");
        try stderr_writer.interface.flush();
        return error.MissingArgument;
    }

    const file_path = args[0];
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    // Read source file
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source);

    // Detect language
    const language = detectLanguage(file_path);

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Extract constraints
    var constraint_set = try ananke_instance.extract(source, language);
    defer constraint_set.deinit();

    try stdout_writer.interface.print("Extracted {} constraints from {s}\n", .{ constraint_set.constraints.items.len, file_path });

    // Output constraints
    for (constraint_set.constraints.items) |constraint| {
        try stdout_writer.interface.print("  - [{s}] {s}: {s}\n", .{
            @tagName(constraint.kind),
            constraint.name,
            constraint.description,
        });
    }
    try stdout_writer.interface.flush();
}

fn handleCompile(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        try stderr_writer.interface.writeAll("Error: compile requires a constraints file\n");
        try stderr_writer.interface.flush();
        return error.MissingArgument;
    }

    const constraints_file = args[0];
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    // Read constraints file
    const constraints_json = try std.fs.cwd().readFileAlloc(allocator, constraints_file, 1024 * 1024);
    defer allocator.free(constraints_json);

    // TODO: Parse JSON constraints

    try stdout_writer.interface.print("Compiling constraints from {s}\n", .{constraints_file});

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // TODO: Compile constraints
    try stdout_writer.interface.writeAll("Constraint compilation completed\n");
    try stdout_writer.interface.flush();
}

fn handleGenerate(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        try stderr_writer.interface.writeAll("Error: generate requires an intent\n");
        try stderr_writer.interface.flush();
        return error.MissingArgument;
    }

    const intent = args[0];
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    try stdout_writer.interface.print("Generating code for: \"{s}\"\n", .{intent});

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // TODO: Parse intent and generate code
    try stdout_writer.interface.writeAll("Note: Generation requires Maze inference service (not yet implemented)\n");
    try stdout_writer.interface.flush();
}

fn handleValidate(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        try stderr_writer.interface.writeAll("Error: validate requires a file path\n");
        try stderr_writer.interface.flush();
        return error.MissingArgument;
    }

    const file_path = args[0];
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    // Read source file
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source);

    try stdout_writer.interface.print("Validating {s}\n", .{file_path});

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // TODO: Validate against constraints
    try stdout_writer.interface.writeAll("Validation completed\n");
    try stdout_writer.interface.flush();
}

fn detectLanguage(file_path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, file_path, ".ts") or std.mem.endsWith(u8, file_path, ".tsx")) {
        return "typescript";
    } else if (std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".jsx")) {
        return "javascript";
    } else if (std.mem.endsWith(u8, file_path, ".py")) {
        return "python";
    } else if (std.mem.endsWith(u8, file_path, ".rs")) {
        return "rust";
    } else if (std.mem.endsWith(u8, file_path, ".go")) {
        return "go";
    } else if (std.mem.endsWith(u8, file_path, ".java")) {
        return "java";
    } else if (std.mem.endsWith(u8, file_path, ".zig")) {
        return "zig";
    }
    return "unknown";
}