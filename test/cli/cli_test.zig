// CLI tests for Ananke
const std = @import("std");
const testing = std.testing;
const args_mod = @import("args");
const output = @import("output");
const config_mod = @import("config");

test "args: parse basic command" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "extract", "file.ts" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    try testing.expectEqualStrings("extract", args.command);
    try testing.expectEqual(@as(usize, 1), args.positional.items.len);
    try testing.expectEqualStrings("file.ts", args.positional.items[0]);
}

test "args: parse flags with values" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "extract", "file.ts", "--format", "json", "--output", "out.json" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    try testing.expectEqualStrings("extract", args.command);
    try testing.expectEqualStrings("json", args.getFlag("format").?);
    try testing.expectEqualStrings("out.json", args.getFlag("output").?);
}

test "args: parse boolean flags" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "extract", "--use-claude", "--verbose" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    try testing.expect(args.hasFlag("use-claude"));
    try testing.expect(args.hasFlag("verbose"));
    try testing.expect(!args.hasFlag("nonexistent"));
}

test "args: parse short flags" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "compile", "-o", "output.cir", "-v" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    try testing.expectEqualStrings("output.cir", args.getFlag("o").?);
    try testing.expect(args.hasFlag("v"));
}

test "args: parse flag with equals" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "compile", "--output=/tmp/out.cir", "--priority=high" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    try testing.expectEqualStrings("/tmp/out.cir", args.getFlag("output").?);
    try testing.expectEqualStrings("high", args.getFlag("priority").?);
}

test "args: get integer flag" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "generate", "--max-tokens", "2048" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    const max_tokens = try args.getFlagInt("max-tokens", u32);
    try testing.expectEqual(@as(?u32, 2048), max_tokens);
}

test "args: get float flag" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "generate", "--temperature", "0.5" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    const temperature = try args.getFlagFloat("temperature", f32);
    try testing.expectEqual(@as(?f32, 0.5), temperature);
}

test "args: get flag with default" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "extract" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    const format = args.getFlagOr("format", "pretty");
    try testing.expectEqualStrings("pretty", format);
}

test "args: missing positional argument" {
    const allocator = testing.allocator;

    const argv = [_][:0]const u8{ "ananke", "extract" };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    const result = args.getPositional(0);
    try testing.expectError(error.MissingArgument, result);
}

test "config: initialization" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    try testing.expectEqualStrings("typescript", config.default_language);
    try testing.expectEqual(@as(u32, 4096), config.max_tokens);
    try testing.expectEqual(@as(f32, 0.7), config.temperature);
    try testing.expectEqual(@as(f32, 0.5), config.confidence_threshold);
}

test "config: parse toml basic" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[defaults]
        \\language = "python"
        \\max_tokens = 2048
        \\temperature = 0.5
    ;

    try config.parseToml(toml);

    try testing.expectEqualStrings("python", config.default_language);
    try testing.expectEqual(@as(u32, 2048), config.max_tokens);
    try testing.expectEqual(@as(f32, 0.5), config.temperature);
}

test "config: parse toml with modal section" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[modal]
        \\endpoint = "https://test.modal.run"
        \\
        \\[defaults]
        \\language = "rust"
    ;

    try config.parseToml(toml);

    try testing.expect(config.modal_endpoint != null);
    try testing.expectEqualStrings("https://test.modal.run", config.modal_endpoint.?);
    try testing.expectEqualStrings("rust", config.default_language);
}

test "config: parse toml with extract section" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[extract]
        \\use_claude = true
    ;

    try config.parseToml(toml);

    try testing.expect(config.use_claude);
}

test "config: parse toml with comments and empty lines" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const toml =
        \\# Ananke Configuration
        \\
        \\[defaults]
        \\# Default language
        \\language = "typescript"
        \\
        \\# Token limits
        \\max_tokens = 4096
    ;

    try config.parseToml(toml);

    try testing.expectEqualStrings("typescript", config.default_language);
    try testing.expectEqual(@as(u32, 4096), config.max_tokens);
}

test "output: format enum from string" {
    try testing.expectEqual(output.OutputFormat.json, output.OutputFormat.fromString("json").?);
    try testing.expectEqual(output.OutputFormat.yaml, output.OutputFormat.fromString("yaml").?);
    try testing.expectEqual(output.OutputFormat.pretty, output.OutputFormat.fromString("pretty").?);
    try testing.expectEqual(output.OutputFormat.ariadne, output.OutputFormat.fromString("ariadne").?);
    try testing.expectEqual(@as(?output.OutputFormat, null), output.OutputFormat.fromString("invalid"));
}

test "output: color codes" {
    try testing.expectEqualStrings("\x1b[31m", output.Color.red.code());
    try testing.expectEqualStrings("\x1b[32m", output.Color.green.code());
    try testing.expectEqualStrings("\x1b[33m", output.Color.yellow.code());
    try testing.expectEqualStrings("\x1b[0m", output.Color.reset.code());
}

test "output: colorize with colors enabled" {
    const allocator = testing.allocator;
    output.setColorEnabled(true);

    const colored = try output.colorize(.red, "Error", allocator);
    defer allocator.free(colored);

    try testing.expect(std.mem.indexOf(u8, colored, "\x1b[31m") != null);
    try testing.expect(std.mem.indexOf(u8, colored, "Error") != null);
    try testing.expect(std.mem.indexOf(u8, colored, "\x1b[0m") != null);
}

test "output: colorize with colors disabled" {
    const allocator = testing.allocator;
    output.setColorEnabled(false);

    const uncolored = try output.colorize(.red, "Error", allocator);
    defer allocator.free(uncolored);

    try testing.expectEqualStrings("Error", uncolored);
    output.setColorEnabled(true); // Reset for other tests
}
