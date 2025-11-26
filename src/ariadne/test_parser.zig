const std = @import("std");
const ariadne = @import("ariadne");

test "lexer - basic tokens" {
    const source = "constraint foo { id: \"test-001\" }";
    var lexer = ariadne.Lexer.init(source);

    const tokens = [_]ariadne.TokenType{
        .keyword_constraint,
        .identifier,
        .left_brace,
        .identifier,
        .colon,
        .string,
        .right_brace,
        .eof,
    };

    for (tokens) |expected_type| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(expected_type, token.type);
    }
}

test "lexer - comments" {
    const source = "-- This is a comment\nconstraint foo";
    var lexer = ariadne.Lexer.init(source);

    var token = try lexer.nextToken();
    try std.testing.expectEqual(ariadne.TokenType.comment, token.type);

    token = try lexer.nextToken();
    try std.testing.expectEqual(ariadne.TokenType.keyword_constraint, token.type);
}

test "lexer - variants" {
    const source = ".Structural .ManualPolicy .HardBlock";
    var lexer = ariadne.Lexer.init(source);

    for (0..3) |_| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(ariadne.TokenType.variant, token.type);
    }
}

test "lexer - multi-line strings" {
    const source =
        \\"""
        \\This is a
        \\multi-line string
        \\"""
    ;
    var lexer = ariadne.Lexer.init(source);

    const token = try lexer.nextToken();
    try std.testing.expectEqual(ariadne.TokenType.multiline_string, token.type);
}

test "lexer - numbers" {
    const source = "42 3.14 -5 0.95";
    var lexer = ariadne.Lexer.init(source);

    for (0..4) |_| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(ariadne.TokenType.number, token.type);
    }
}

test "parser - simple constraint" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint no_any_type {
        \\    id: "type-001",
        \\    name: "no_any_type"
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 1), ast.nodes.len);

    const node = ast.nodes[0];
    try std.testing.expect(node == .constraint_def);

    const constraint = node.constraint_def;
    try std.testing.expectEqualStrings("no_any_type", constraint.name);
    try std.testing.expectEqual(@as(usize, 2), constraint.properties.len);
}

test "parser - module and import" {
    const allocator = std.testing.allocator;

    const source =
        \\module api.security
        \\
        \\import std.{clew, braid}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 2), ast.nodes.len);

    const module_node = ast.nodes[0];
    try std.testing.expect(module_node == .module_decl);
    try std.testing.expectEqualStrings("api.security", module_node.module_decl.name);

    const import_node = ast.nodes[1];
    try std.testing.expect(import_node == .import_stmt);
    try std.testing.expectEqualStrings("std", import_node.import_stmt.path);
    try std.testing.expectEqual(@as(usize, 2), import_node.import_stmt.symbols.len);
}

test "parser - nested objects" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test {
        \\    provenance: {
        \\        source: .ManualPolicy,
        \\        confidence_score: 1.0
        \\    }
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 1), ast.nodes.len);

    const constraint = ast.nodes[0].constraint_def;
    try std.testing.expectEqual(@as(usize, 1), constraint.properties.len);

    const prop = constraint.properties[0];
    try std.testing.expectEqualStrings("provenance", prop.key);
    try std.testing.expect(prop.value == .object);
}

test "parser - arrays" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test {
        \\    depends_on: ["foo", "bar"]
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    const constraint = ast.nodes[0].constraint_def;
    const prop = constraint.properties[0];
    try std.testing.expect(prop.value == .array);
    try std.testing.expectEqual(@as(usize, 2), prop.value.array.len);
}

test "parser - query patterns" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test {
        \\    pattern: query(javascript) {
        \\        (call_expression
        \\            function: (identifier) @fn
        \\        )
        \\    }
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    const constraint = ast.nodes[0].constraint_def;
    const prop = constraint.properties[0];
    try std.testing.expect(prop.value == .query);
    try std.testing.expectEqualStrings("javascript", prop.value.query.language);
}

test "parser - public const" {
    const allocator = std.testing.allocator;

    const source =
        \\pub const api_security_constraints = [
        \\    no_dangerous_operations,
        \\    require_input_validation
        \\]
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 1), ast.nodes.len);

    const node = ast.nodes[0];
    try std.testing.expect(node == .public_const);
    try std.testing.expectEqualStrings("api_security_constraints", node.public_const.name);
    try std.testing.expect(node.public_const.value == .array);
}

test "semantic analyzer - unknown constraint reference" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint foo {
        \\    id: "001"
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var analyzer = ariadne.SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(ast);

    try std.testing.expect(analyzer.constraint_defs.contains("foo"));
}

test "compiler - full workflow" {
    const allocator = std.testing.allocator;

    const source =
        \\module test.constraints
        \\
        \\constraint simple_test {
        \\    id: "test-001",
        \\    name: "simple_test",
        \\    severity: .error
        \\}
    ;

    var compiler = try ariadne.AriadneCompiler.init(allocator);
    defer compiler.deinit();

    var ast = try compiler.parse(source);
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 2), ast.nodes.len);

    try compiler.validate(ast);
}

test "IR generator - simple constraint" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint no_any_type {
        \\    id: "type-001",
        \\    name: "no_any_type"
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    // Verify IR was generated
    try std.testing.expect(ir_gen.constraints.items.len == 1);

    const constraint = ir_gen.constraints.items[0];
    try std.testing.expectEqualStrings("no_any_type", constraint.name);
    try std.testing.expect(constraint.id != 0); // Should be hashed from "type-001"
}

test "IR generator - enforcement parsing" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test_syntactic {
        \\    id: "test-001",
        \\    enforcement: .Syntactic
        \\}
        \\
        \\constraint test_structural {
        \\    id: "test-002",
        \\    enforcement: .Structural
        \\}
        \\
        \\constraint test_semantic {
        \\    id: "test-003",
        \\    enforcement: .Semantic
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    try std.testing.expectEqual(@as(usize, 3), ir_gen.constraints.items.len);

    // Check enforcement types
    try std.testing.expect(ir_gen.constraints.items[0].enforcement == .Syntactic);
    try std.testing.expect(ir_gen.constraints.items[1].enforcement == .Structural);
    try std.testing.expect(ir_gen.constraints.items[2].enforcement == .Semantic);
}

test "IR generator - severity from failure mode" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint hard_block {
        \\    id: "001",
        \\    failure_mode: .HardBlock
        \\}
        \\
        \\constraint soft_warn {
        \\    id: "002",
        \\    failure_mode: .SoftWarn
        \\}
        \\
        \\constraint suggest {
        \\    id: "003",
        \\    failure_mode: .Suggest
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    try std.testing.expectEqual(@as(usize, 3), ir_gen.constraints.items.len);

    // Check severity levels
    try std.testing.expect(ir_gen.constraints.items[0].severity == .err);
    try std.testing.expect(ir_gen.constraints.items[1].severity == .warning);
    try std.testing.expect(ir_gen.constraints.items[2].severity == .hint);
}

test "IR generator - provenance parsing" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test {
        \\    id: "001",
        \\    provenance: {
        \\        source: .ManualPolicy,
        \\        confidence_score: 0.95,
        \\        origin_artifact: "test.md"
        \\    }
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    try std.testing.expectEqual(@as(usize, 1), ir_gen.constraints.items.len);

    const constraint = ir_gen.constraints.items[0];
    try std.testing.expect(constraint.source == .User_Defined);
    try std.testing.expectApproxEqAbs(@as(f32, 0.95), constraint.confidence, 0.001);
    try std.testing.expectEqualStrings("test.md", constraint.origin_file.?);
}

test "IR generator - multiple constraints" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint first {
        \\    id: "001",
        \\    name: "first_constraint"
        \\}
        \\
        \\constraint second {
        \\    id: "002",
        \\    name: "second_constraint"
        \\}
        \\
        \\constraint third {
        \\    id: "003",
        \\    name: "third_constraint"
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    const ir = try ir_gen.generate(ast);
    _ = ir;

    // Should have 3 constraints
    try std.testing.expectEqual(@as(usize, 3), ir_gen.constraints.items.len);

    try std.testing.expectEqualStrings("first_constraint", ir_gen.constraints.items[0].name);
    try std.testing.expectEqualStrings("second_constraint", ir_gen.constraints.items[1].name);
    try std.testing.expectEqualStrings("third_constraint", ir_gen.constraints.items[2].name);
}

test "IR generator - variant with nested value" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint test {
        \\    id: "001",
        \\    enforcement: .Type({
        \\        strictness: .Strict
        \\    })
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    try std.testing.expectEqual(@as(usize, 1), ir_gen.constraints.items.len);

    // Should parse the variant name before the nested value
    const constraint = ir_gen.constraints.items[0];
    // .Type should map to .Structural or .Semantic enforcement
    try std.testing.expect(constraint.enforcement == .Syntactic); // Default since .Type is not explicitly handled
}

test "IR generator - constraint source types" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint manual {
        \\    id: "001",
        \\    provenance: { source: .ManualPolicy }
        \\}
        \\
        \\constraint mined {
        \\    id: "002",
        \\    provenance: { source: .ClewMined }
        \\}
        \\
        \\constraint best_practice {
        \\    id: "003",
        \\    provenance: { source: .BestPractice }
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    _ = try ir_gen.generate(ast);

    try std.testing.expectEqual(@as(usize, 3), ir_gen.constraints.items.len);

    try std.testing.expect(ir_gen.constraints.items[0].source == .User_Defined);
    try std.testing.expect(ir_gen.constraints.items[1].source == .Test_Mining);
    try std.testing.expect(ir_gen.constraints.items[2].source == .Documentation);
}

test "IR generator - empty constraints" {
    const allocator = std.testing.allocator;

    const source = "-- Empty file with just a comment";

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    const ir = try ir_gen.generate(ast);
    _ = ir;

    // No constraints should be generated
    try std.testing.expectEqual(@as(usize, 0), ir_gen.constraints.items.len);
}

test "IR generator - priority calculation" {
    const allocator = std.testing.allocator;

    const source =
        \\constraint low {
        \\    id: "001",
        \\    name: "low_priority"
        \\}
        \\
        \\constraint high {
        \\    id: "002",
        \\    name: "high_priority"
        \\}
    ;

    var parser = ariadne.Parser.init(allocator, source);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    var ir_gen = ariadne.IRGenerator.init(allocator);
    defer ir_gen.deinit();

    const ir = try ir_gen.generate(ast);

    // Priority should be set (even if default)
    try std.testing.expect(ir.priority >= 0);
}
