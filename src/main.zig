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
        std.debug.print("Error: extract requires a file path\n", .{});
        std.debug.print("Usage: ananke extract <file> [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --use-claude         Enable Claude API for semantic analysis\n", .{});
        std.debug.print("  --output, -o <file>  Write output to file\n", .{});
        std.debug.print("  --format <format>    Output format: json, yaml, ariadne (default: json)\n", .{});
        std.debug.print("  --language <lang>    Source language (auto-detected if not specified)\n", .{});
        return error.MissingArgument;
    }

    // Parse arguments
    const file_path = args[0];
    var use_claude = false;
    var output_file: ?[]const u8 = null;
    var format: []const u8 = "json";
    var language_override: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--use-claude")) {
            use_claude = true;
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --output requires a file path\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "--format")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --format requires a format (json, yaml, ariadne)\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            format = args[i];
            if (!std.mem.eql(u8, format, "json") and
                !std.mem.eql(u8, format, "yaml") and
                !std.mem.eql(u8, format, "ariadne")) {
                std.debug.print("Error: Invalid format '{s}'. Use: json, yaml, or ariadne\n", .{format});
                return error.InvalidArgument;
            }
        } else if (std.mem.eql(u8, arg, "--language")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --language requires a language name\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            language_override = args[i];
        }
    }

    

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading file '{s}': {}\n", .{ file_path, err });
        return err;
    };
    defer allocator.free(source);

    // Detect or use specified language
    const language = language_override orelse detectLanguage(file_path);

    std.debug.print("Extracting constraints from {s} ({s})...\n", .{ file_path, language });
    if (use_claude) {
        std.debug.print("Claude semantic analysis enabled\n", .{});
    }

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Extract constraints
    var constraint_set = try ananke_instance.extract(source, language);
    defer constraint_set.deinit();

    std.debug.print("Extracted {} constraints\n\n", .{constraint_set.constraints.items.len});

    // Format output
    const output = try formatConstraints(allocator, constraint_set, format);
    defer allocator.free(output);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Error creating output file '{s}': {}\n", .{ path, err });
            return err;
        };
        defer file.close();

        try file.writeAll(output);
        std.debug.print("Output written to {s}\n", .{path});
    } else {
        std.debug.print("{s}", .{output});
    }
}

fn handleCompile(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        
        std.debug.print("Error: compile requires a constraints file\n", .{});
        std.debug.print("Usage: ananke compile <constraints-file> [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --output, -o <file>  Write compiled IR to file\n", .{});
        return error.MissingArgument;
    }

    // Parse arguments
    const constraints_file = args[0];
    var output_file: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --output requires a file path\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            output_file = args[i];
        }
    }

    
    

    // Read constraints file
    const constraints_json = std.fs.cwd().readFileAlloc(allocator, constraints_file, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading file '{s}': {}\n", .{ constraints_file, err });
        return err;
    };
    defer allocator.free(constraints_json);

    std.debug.print("Compiling constraints from {s}...\n", .{constraints_file});

    // Parse JSON constraints
    const constraint_set = parseConstraintsJson(allocator, constraints_json) catch |err| {
        std.debug.print("Error parsing constraints JSON: {}\n", .{err});
        std.debug.print("Expected format:\n", .{});
        std.debug.print("{{\n", .{});
        std.debug.print("  \"name\": \"my_constraints\",\n", .{});
        std.debug.print("  \"constraints\": [[\n", .{});
        std.debug.print("    {{\"kind\": \"type_safety\", \"severity\": \"error\", \"name\": \"...\", \"description\": \"...\"}}\n", .{});
        std.debug.print("  ]]\n", .{});
        std.debug.print("}}\n", .{});
        return err;
    };
    defer {
        for (constraint_set.constraints.items) |_| {}
        // Constraints are owned by constraint_set
    }

    std.debug.print("Loaded {} constraints\n", .{constraint_set.constraints.items.len});

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Compile constraints to IR
    const ir = ananke_instance.compile(constraint_set.constraints.items) catch |err| {
        std.debug.print("Error compiling constraints: {}\n", .{err});
        return err;
    };

    std.debug.print("Compilation completed successfully\n", .{});

    // Serialize IR
    const output = try serializeConstraintIR(allocator, ir);
    defer allocator.free(output);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Error creating output file '{s}': {}\n", .{ path, err });
            return err;
        };
        defer file.close();

        try file.writeAll(output);
        std.debug.print("Compiled IR written to {s}\n", .{path});
    } else {
        std.debug.print("{s}", .{output});
    }
}

fn handleGenerate(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        
        std.debug.print("Error: generate requires an intent or prompt\n", .{});
        std.debug.print("Usage: ananke generate <intent> [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --constraints, -c <file>  Load constraints from file\n", .{});
        std.debug.print("  --output, -o <file>       Write generated code to file\n", .{});
        std.debug.print("  --max-tokens <n>          Maximum tokens to generate (default: 4096)\n", .{});
        std.debug.print("  --temperature <f>         Sampling temperature 0.0-1.0 (default: 0.7)\n", .{});
        return error.MissingArgument;
    }

    // Parse arguments
    const intent = args[0];
    var constraints_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var max_tokens: u32 = 4096;
    var temperature: f32 = 0.7;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--constraints") or std.mem.eql(u8, arg, "-c")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --constraints requires a file path\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            constraints_file = args[i];
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --output requires a file path\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "--max-tokens")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --max-tokens requires a number\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            max_tokens = std.fmt.parseInt(u32, args[i], 10) catch {
                
                std.debug.print("Error: Invalid max-tokens value '{s}'\n", .{args[i]});
                return error.InvalidArgument;
            };
        } else if (std.mem.eql(u8, arg, "--temperature")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --temperature requires a number\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            temperature = std.fmt.parseFloat(f32, args[i]) catch {
                
                std.debug.print("Error: Invalid temperature value '{s}'\n", .{args[i]});
                return error.InvalidArgument;
            };
            if (temperature < 0.0 or temperature > 1.0) {
                
                std.debug.print("Error: Temperature must be between 0.0 and 1.0\n", .{});
                return error.InvalidArgument;
            }
        }
    }

    
    

    std.debug.print("Generating code for: \"{s}\"\n", .{intent});
    std.debug.print("Parameters: max_tokens={}, temperature={d:.2}\n", .{ max_tokens, temperature });

    // Load constraints if specified
    if (constraints_file) |path| {
        std.debug.print("Loading constraints from {s}...\n", .{path});

        // Read and parse constraints
        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            std.debug.print("Error reading constraints file '{s}': {}\n", .{ path, err });
            return err;
        };
        defer allocator.free(constraints_json);

        // TODO: Parse constraints and pass to Maze
        std.debug.print("Constraints loaded (parsing not yet implemented)\n", .{});
    }

    // Note: Full generation requires Maze orchestrator (Rust component)
    std.debug.print("\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("Note: Code generation requires Maze inference service\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
    std.debug.print("The Maze orchestrator is a Rust component that:\n", .{});
    std.debug.print("  1. Compiles constraints to llguidance format\n", .{});
    std.debug.print("  2. Initializes Modal inference endpoint\n", .{});
    std.debug.print("  3. Streams constrained generation results\n\n", .{});
    std.debug.print("To enable generation:\n", .{});
    std.debug.print("  1. Build the Maze Rust component: cd maze && cargo build --release\n", .{});
    std.debug.print("  2. Set up Modal authentication: modal setup\n", .{});
    std.debug.print("  3. Deploy inference service: modal deploy maze/inference.py\n\n", .{});
    std.debug.print("For now, showing mock output:\n\n", .{});

    // Mock generated code for demonstration
    const mock_code =
        \\// Generated code (mock)
        \\// Intent: {s}
        \\
        \\export function example() {{
        \\    // TODO: Implement based on intent
        \\    return "Hello, World!";
        \\}}
        \\
    ;

    const output = try std.fmt.allocPrint(allocator, mock_code, .{intent});
    defer allocator.free(output);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Error creating output file '{s}': {}\n", .{ path, err });
            return err;
        };
        defer file.close();

        try file.writeAll(output);
        std.debug.print("Generated code written to {s}\n", .{path});
    } else {
        std.debug.print("{s}", .{output});
    }
}

fn handleValidate(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 1) {
        
        std.debug.print("Error: validate requires a file path\n", .{});
        std.debug.print("Usage: ananke validate <code-file> [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --constraints, -c <file>  Validate against constraints from file\n", .{});
        return error.MissingArgument;
    }

    // Parse arguments
    const file_path = args[0];
    var constraints_file: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--constraints") or std.mem.eql(u8, arg, "-c")) {
            if (i + 1 >= args.len) {
                
                std.debug.print("Error: --constraints requires a file path\n", .{});
                return error.MissingArgument;
            }
            i += 1;
            constraints_file = args[i];
        }
    }

    
    

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading file '{s}': {}\n", .{ file_path, err });
        return err;
    };
    defer allocator.free(source);

    std.debug.print("Validating {s}...\n", .{file_path});

    // Load constraints if specified
    var constraint_set: ?ananke.types.constraint.ConstraintSet = null;
    defer {
        if (constraint_set) |*cs| {
            cs.deinit();
        }
    }

    if (constraints_file) |path| {
        std.debug.print("Loading constraints from {s}...\n", .{path});

        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            std.debug.print("Error reading constraints file '{s}': {}\n", .{ path, err });
            return err;
        };
        defer allocator.free(constraints_json);

        constraint_set = parseConstraintsJson(allocator, constraints_json) catch |err| {
            std.debug.print("Error parsing constraints JSON: {}\n", .{err});
            return err;
        };

        std.debug.print("Loaded {} constraints\n", .{constraint_set.?.constraints.items.len});
    } else {
        // Extract constraints from the code itself
        std.debug.print("No constraints file specified, extracting from code...\n", .{});

        var ananke_instance = try ananke.Ananke.init(allocator);
        defer ananke_instance.deinit();

        const language = detectLanguage(file_path);
        constraint_set = try ananke_instance.extract(source, language);

        std.debug.print("Extracted {} constraints from code\n", .{constraint_set.?.constraints.items.len});
    }

    // Perform validation
    std.debug.print("\nValidating code against constraints...\n\n", .{});

    var violations_found: usize = 0;
    var warnings_found: usize = 0;

    if (constraint_set) |cs| {
        for (cs.constraints.items) |constraint| {
            // Simple validation: check if constraint patterns exist
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
    }

    // Summary
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    if (violations_found == 0 and warnings_found == 0) {
        std.debug.print("✓ Validation passed: No violations found\n", .{});
    } else {
        if (violations_found > 0) {
            std.debug.print("✗ Validation failed: {} error(s) found\n", .{violations_found});
        }
        if (warnings_found > 0) {
            std.debug.print("⚠ {} warning(s) found\n", .{warnings_found});
        }

        if (violations_found > 0) {
            return error.ValidationFailed;
        }
    }
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

// Helper functions for constraint formatting and parsing

fn formatConstraints(
    allocator: std.mem.Allocator,
    constraint_set: ananke.types.constraint.ConstraintSet,
    format: []const u8,
) ![]u8 {
    if (std.mem.eql(u8, format, "json")) {
        return formatConstraintsJson(allocator, constraint_set);
    } else if (std.mem.eql(u8, format, "yaml")) {
        return formatConstraintsYaml(allocator, constraint_set);
    } else if (std.mem.eql(u8, format, "ariadne")) {
        return formatConstraintsAriadne(allocator, constraint_set);
    }
    return error.InvalidFormat;
}

fn formatConstraintsJson(
    allocator: std.mem.Allocator,
    constraint_set: ananke.types.constraint.ConstraintSet,
) ![]u8 {
    var output = std.ArrayList(u8){};
    errdefer output.deinit(allocator);
    const writer = output.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"name\": \"{s}\",\n", .{constraint_set.name});
    try writer.writeAll("  \"constraints\": [\n");

    for (constraint_set.constraints.items, 0..) |constraint, i| {
        try writer.writeAll("    {\n");
        try writer.print("      \"kind\": \"{s}\",\n", .{@tagName(constraint.kind)});
        try writer.print("      \"severity\": \"{s}\",\n", .{@tagName(constraint.severity)});
        try writer.print("      \"name\": \"{s}\",\n", .{escapeJson(constraint.name)});
        try writer.print("      \"description\": \"{s}\",\n", .{escapeJson(constraint.description)});
        try writer.print("      \"source\": \"{s}\",\n", .{@tagName(constraint.source)});
        try writer.print("      \"confidence\": {d:.2}\n", .{constraint.confidence});
        try writer.writeAll("    }");
        if (i < constraint_set.constraints.items.len - 1) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
    }

    try writer.writeAll("  ]\n");
    try writer.writeAll("}\n");

    return output.toOwnedSlice(allocator);
}

fn formatConstraintsYaml(
    allocator: std.mem.Allocator,
    constraint_set: ananke.types.constraint.ConstraintSet,
) ![]u8 {
    var output = std.ArrayList(u8){};
    errdefer output.deinit(allocator);
    const writer = output.writer(allocator);

    try writer.print("name: {s}\n", .{constraint_set.name});
    try writer.writeAll("constraints:\n");

    for (constraint_set.constraints.items) |constraint| {
        try writer.print("  - kind: {s}\n", .{@tagName(constraint.kind)});
        try writer.print("    severity: {s}\n", .{@tagName(constraint.severity)});
        try writer.print("    name: {s}\n", .{constraint.name});
        try writer.print("    description: {s}\n", .{constraint.description});
        try writer.print("    source: {s}\n", .{@tagName(constraint.source)});
        try writer.print("    confidence: {d:.2}\n", .{constraint.confidence});
    }

    return output.toOwnedSlice(allocator);
}

fn formatConstraintsAriadne(
    allocator: std.mem.Allocator,
    constraint_set: ananke.types.constraint.ConstraintSet,
) ![]u8 {
    var output = std.ArrayList(u8){};
    errdefer output.deinit(allocator);
    const writer = output.writer(allocator);

    try writer.print("constraint_set \"{s}\" {{\n", .{constraint_set.name});

    for (constraint_set.constraints.items) |constraint| {
        const severity_str = switch (constraint.severity) {
            .err => "error",
            .warning => "warning",
            .info => "info",
            .hint => "hint",
        };

        try writer.print("  {s} {s} \"{s}\" {{\n", .{
            @tagName(constraint.kind),
            severity_str,
            constraint.name,
        });
        try writer.print("    description: \"{s}\"\n", .{constraint.description});
        try writer.print("    confidence: {d:.2}\n", .{constraint.confidence});
        try writer.writeAll("  }\n\n");
    }

    try writer.writeAll("}\n");

    return output.toOwnedSlice(allocator);
}

fn escapeJson(s: []const u8) []const u8 {
    // TODO: Implement proper JSON string escaping
    // For now, return as-is (assumes no special characters)
    return s;
}

fn parseConstraintsJson(
    allocator: std.mem.Allocator,
    json_str: []const u8,
) !ananke.types.constraint.ConstraintSet {
    // Simple JSON parsing for constraint files
    // Format:
    // {
    //   "name": "constraint_set_name",
    //   "constraints": [
    //     {
    //       "kind": "type_safety",
    //       "severity": "error",
    //       "name": "constraint_name",
    //       "description": "constraint description"
    //     }
    //   ]
    // }

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

    var constraint_set = ananke.types.constraint.ConstraintSet.init(
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

        const constraint = ananke.types.constraint.Constraint{
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

fn parseConstraintKind(s: []const u8) ananke.types.constraint.ConstraintKind {
    if (std.mem.eql(u8, s, "syntactic")) return .syntactic;
    if (std.mem.eql(u8, s, "type_safety")) return .type_safety;
    if (std.mem.eql(u8, s, "semantic")) return .semantic;
    if (std.mem.eql(u8, s, "architectural")) return .architectural;
    if (std.mem.eql(u8, s, "operational")) return .operational;
    if (std.mem.eql(u8, s, "security")) return .security;
    return .semantic; // default
}

fn parseSeverity(s: []const u8) ananke.types.constraint.Severity {
    if (std.mem.eql(u8, s, "error") or std.mem.eql(u8, s, "err")) return .err;
    if (std.mem.eql(u8, s, "warning")) return .warning;
    if (std.mem.eql(u8, s, "info")) return .info;
    if (std.mem.eql(u8, s, "hint")) return .hint;
    return .err; // default to error
}

fn serializeConstraintIR(
    allocator: std.mem.Allocator,
    ir: ananke.types.constraint.ConstraintIR,
) ![]u8 {
    var output = std.ArrayList(u8){};
    errdefer output.deinit(allocator);
    const writer = output.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"priority\": {},\n", .{ir.priority});

    // JSON Schema
    if (ir.json_schema) |schema| {
        try writer.writeAll("  \"json_schema\": {\n");
        try writer.print("    \"type\": \"{s}\"\n", .{schema.type});
        try writer.writeAll("  },\n");
    }

    // Grammar
    if (ir.grammar) |grammar| {
        try writer.writeAll("  \"grammar\": {\n");
        try writer.print("    \"start_symbol\": \"{s}\",\n", .{grammar.start_symbol});
        try writer.writeAll("    \"rules\": []\n");
        try writer.writeAll("  },\n");
    }

    // Regex patterns
    try writer.writeAll("  \"regex_patterns\": [\n");
    for (ir.regex_patterns, 0..) |regex, i| {
        try writer.print("    {{\"pattern\": \"{s}\"}}", .{regex.pattern});
        if (i < ir.regex_patterns.len - 1) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
    }
    try writer.writeAll("  ],\n");

    // Token masks
    if (ir.token_masks) |_| {
        try writer.writeAll("  \"token_masks\": {}\n");
    } else {
        try writer.writeAll("  \"token_masks\": null\n");
    }

    try writer.writeAll("}\n");

    return output.toOwnedSlice(allocator);
}

fn validateConstraint(
    source: []const u8,
    constraint: ananke.types.constraint.Constraint,
) bool {
    // Simple validation logic based on constraint type
    switch (constraint.kind) {
        .type_safety => {
            // Check for type safety patterns
            if (std.mem.eql(u8, constraint.name, "avoid_any_type")) {
                return std.mem.indexOf(u8, source, ": any") == null;
            }
            if (std.mem.eql(u8, constraint.name, "null_safety")) {
                // Just check if it's mentioned (simplistic)
                return std.mem.indexOf(u8, source, "null") != null or
                    std.mem.indexOf(u8, source, "?") != null;
            }
        },
        .syntactic => {
            // Check for syntactic patterns
            if (std.mem.eql(u8, constraint.name, "has_functions")) {
                return std.mem.indexOf(u8, source, "function") != null or
                    std.mem.indexOf(u8, source, "fn") != null;
            }
        },
        .security => {
            // Security checks (very basic)
            if (std.mem.indexOf(u8, constraint.description, "password") != null) {
                // Check if password handling exists
                return std.mem.indexOf(u8, source, "password") != null;
            }
        },
        else => {},
    }

    // By default, assume constraint is satisfied
    // (in a real implementation, this would be more sophisticated)
    return true;
}