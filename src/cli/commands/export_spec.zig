// Export-spec command - One-shot pipeline: extract + compile + rich context → ConstraintSpec JSON
const std = @import("std");
const ananke = @import("ananke");
const args_mod = @import("cli_args");
const output = @import("cli_output");
const config_mod = @import("cli_config");
const cli_error = @import("cli_error");
const path_validator = @import("path_validator");

pub const usage =
    \\Usage: ananke export-spec <file> [options]
    \\
    \\Export a ConstraintSpec JSON combining compiled IR and rich context.
    \\This is the complete payload for sglang's ConstraintSpec.from_dict().
    \\
    \\Arguments:
    \\  <file>                  Source file to extract constraints from
    \\
    \\Options:
    \\  --language <lang>       Source language (auto-detected if not specified)
    \\  --output, -o <file>     Write output to file instead of stdout
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke export-spec src/auth.py -o spec.json
    \\  ananke export-spec src/models/user.ts --language typescript
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const file_path = parsed_args.getPositional(0) catch {
        cli_error.printError("Missing required argument: <file>", .{});
        std.debug.print("\n{s}\n", .{usage});
        return error.MissingArgument;
    };

    const output_file = parsed_args.getFlag("output") orelse parsed_args.getFlag("o");
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    // Determine language
    const language = parsed_args.getFlag("language") orelse
        detectLanguage(file_path) orelse
        config.default_language;

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        cli_error.printFileError(err, file_path);
        return err;
    };
    defer allocator.free(source);

    if (verbose) {
        cli_error.printInfo("Extracting from: {s} (language: {s})", .{ file_path, language });
    }

    // Initialize ananke engine
    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    // 1. Extract constraints
    var constraint_set = try engine.extract(source, language);
    defer constraint_set.deinit();

    if (verbose) {
        cli_error.printInfo("Extracted {d} constraints", .{constraint_set.constraints.items.len});
    }

    // 2. Compile to IR
    var ir = try engine.compile(constraint_set.constraints.items);
    defer ir.deinit(allocator);

    // 3. Extract rich context
    var rich_context = try engine.extractRichContext(source, language);
    defer rich_context.deinit(allocator);

    if (verbose) {
        cli_error.printInfo("Rich context: functions={}, types={}, classes={}, imports={}", .{
            rich_context.function_signatures_json != null,
            rich_context.type_bindings_json != null,
            rich_context.class_definitions_json != null,
            rich_context.imports_json != null,
        });
    }

    // 4. Build combined ConstraintSpec JSON
    var json_buf = std.ArrayList(u8){};
    defer json_buf.deinit(allocator);
    const writer = json_buf.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"language\": \"{s}\"", .{language});

    // IR fields
    const ir_json = try output.formatIRJson(allocator, ir);
    defer allocator.free(ir_json);
    try writer.writeAll(",\n  \"constraint_ir\": ");
    try writer.writeAll(ir_json);

    // Rich context fields (top-level, matching ConstraintSpec.from_dict() keys)
    if (rich_context.function_signatures_json) |fs| {
        try writer.writeAll(",\n  \"function_signatures\": ");
        try writer.writeAll(fs);
    }
    if (rich_context.type_bindings_json) |tb| {
        try writer.writeAll(",\n  \"type_bindings\": ");
        try writer.writeAll(tb);
    }
    if (rich_context.class_definitions_json) |cd| {
        try writer.writeAll(",\n  \"class_definitions\": ");
        try writer.writeAll(cd);
    }
    if (rich_context.imports_json) |im| {
        try writer.writeAll(",\n  \"imports\": ");
        try writer.writeAll(im);
    }
    if (rich_context.control_flow_json) |cf| {
        try writer.writeAll(",\n  \"control_flow\": ");
        try writer.writeAll(cf);
    }
    if (rich_context.semantic_constraints_json) |sc| {
        try writer.writeAll(",\n  \"semantic_constraints\": ");
        try writer.writeAll(sc);
    }
    if (rich_context.scope_bindings_json) |sb| {
        try writer.writeAll(",\n  \"scope_bindings\": ");
        try writer.writeAll(sb);
    }

    try writer.writeAll("\n}\n");

    const spec_json = try json_buf.toOwnedSlice(allocator);
    defer allocator.free(spec_json);

    // Output
    if (output_file) |path| {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(spec_json);
        cli_error.printSuccess("ConstraintSpec written to {s}", .{path});
    } else {
        const stdout_file = std.fs.File.stdout();
        try stdout_file.writeAll(spec_json);
    }
}

fn detectLanguage(path: []const u8) ?[]const u8 {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) return "typescript";
    if (std.mem.eql(u8, ext, ".py")) return "python";
    if (std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".jsx")) return "javascript";
    if (std.mem.eql(u8, ext, ".rs")) return "rust";
    if (std.mem.eql(u8, ext, ".go")) return "go";
    if (std.mem.eql(u8, ext, ".zig")) return "zig";
    if (std.mem.eql(u8, ext, ".c")) return "c";
    if (std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".cc")) return "cpp";
    if (std.mem.eql(u8, ext, ".java")) return "java";
    return null;
}
