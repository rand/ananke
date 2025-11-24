// Tests for grammar building in Braid
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

// Import constraint types
const Constraint = ananke.Constraint;
const ConstraintKind = ananke.ConstraintKind;
const Grammar = ananke.types.constraint.Grammar;
const GrammarRule = ananke.types.constraint.GrammarRule;
const buildGrammarFromConstraints = braid.buildGrammarFromConstraints;

// Helper function to find a rule by LHS
fn findRule(grammar: Grammar, lhs: []const u8) ?GrammarRule {
    for (grammar.rules) |rule| {
        if (std.mem.eql(u8, rule.lhs, lhs)) {
            return rule;
        }
    }
    return null;
}

// Helper function to count rules with a specific LHS
fn countRules(grammar: Grammar, lhs: []const u8) usize {
    var count: usize = 0;
    for (grammar.rules) |rule| {
        if (std.mem.eql(u8, rule.lhs, lhs)) {
            count += 1;
        }
    }
    return count;
}

// Helper function to check if RHS contains a specific symbol
fn rhsContains(rhs: []const []const u8, symbol: []const u8) bool {
    for (rhs) |item| {
        if (std.mem.eql(u8, item, symbol)) {
            return true;
        }
    }
    return false;
}

// Helper to free grammar rules
fn freeGrammar(allocator: std.mem.Allocator, grammar: Grammar) void {
    for (grammar.rules) |rule| {
        allocator.free(rule.lhs);
        for (rule.rhs) |rhs_item| {
            allocator.free(rhs_item);
        }
        allocator.free(rule.rhs);
    }
    allocator.free(grammar.rules);
}

test "buildGrammar - simple function grammar" {
    const allocator = testing.allocator;

    // Create constraints with function declaration
    var constraints = [_]Constraint{
        Constraint.init(1, "function_decl", "function declaration pattern"),
    };
    constraints[0].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify start symbol
    try testing.expectEqualStrings("program", grammar.start_symbol);

    // Verify we have basic rules
    try testing.expect(grammar.rules.len > 0);

    // Verify program rule exists
    const program_rule = findRule(grammar, "program");
    try testing.expect(program_rule != null);

    // Verify function_declaration rule exists (since we have a function constraint)
    const func_rule = findRule(grammar, "function_declaration");
    try testing.expect(func_rule != null);
    if (func_rule) |rule| {
        // Should contain FUNCTION token
        try testing.expect(rhsContains(rule.rhs, "FUNCTION"));
    }

    // Verify statement rule includes function_declaration
    const statement_rule = findRule(grammar, "statement");
    try testing.expect(statement_rule != null);
    if (statement_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "function_declaration"));
    }

    // Verify basic expression rules exist
    try testing.expect(findRule(grammar, "expression") != null);
    try testing.expect(findRule(grammar, "identifier") != null);
}

test "buildGrammar - async function grammar" {
    const allocator = testing.allocator;

    // Create constraints with async function
    var constraints = [_]Constraint{
        Constraint.init(1, "async_func", "async function declaration"),
    };
    constraints[0].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify async_function rule exists
    const async_rule = findRule(grammar, "async_function");
    try testing.expect(async_rule != null);

    if (async_rule) |rule| {
        // Should contain both ASYNC and FUNCTION tokens
        try testing.expect(rhsContains(rule.rhs, "ASYNC"));
        try testing.expect(rhsContains(rule.rhs, "FUNCTION"));
    }

    // Verify function_declaration includes async alternative
    const func_decl_count = countRules(grammar, "function_declaration");
    try testing.expect(func_decl_count >= 1);
}

test "buildGrammar - control flow grammar (if/for/while)" {
    const allocator = testing.allocator;

    // Create constraints with control flow patterns
    var constraints = [_]Constraint{
        Constraint.init(1, "if_stmt", "if statement control flow"),
        Constraint.init(2, "for_loop", "for loop iteration"),
        Constraint.init(3, "while_loop", "while loop control"),
    };
    constraints[0].kind = .syntactic;
    constraints[1].kind = .syntactic;
    constraints[2].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify if_statement rule
    const if_rule = findRule(grammar, "if_statement");
    try testing.expect(if_rule != null);
    if (if_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "IF"));
        try testing.expect(rhsContains(rule.rhs, "expression"));
    }

    // Verify for_statement rule
    const for_rule = findRule(grammar, "for_statement");
    try testing.expect(for_rule != null);
    if (for_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "FOR"));
    }

    // Verify while_statement rule
    const while_rule = findRule(grammar, "while_statement");
    try testing.expect(while_rule != null);
    if (while_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "WHILE"));
    }

    // Verify statement rule includes all control flow statements
    const statement_rule = findRule(grammar, "statement");
    try testing.expect(statement_rule != null);
    if (statement_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "if_statement"));
        try testing.expect(rhsContains(rule.rhs, "for_statement"));
        try testing.expect(rhsContains(rule.rhs, "while_statement"));
    }
}

test "buildGrammar - try/catch grammar" {
    const allocator = testing.allocator;

    // Create constraints with try/catch
    var constraints = [_]Constraint{
        Constraint.init(1, "exception", "try catch exception handling"),
    };
    constraints[0].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify try_statement rule exists
    const try_rule = findRule(grammar, "try_statement");
    try testing.expect(try_rule != null);

    if (try_rule) |rule| {
        // Should contain TRY, CATCH tokens
        try testing.expect(rhsContains(rule.rhs, "TRY"));
        try testing.expect(rhsContains(rule.rhs, "CATCH"));
    }

    // Verify statement includes try_statement
    const statement_rule = findRule(grammar, "statement");
    try testing.expect(statement_rule != null);
    if (statement_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "try_statement"));
    }
}

test "buildGrammar - multiple patterns combined" {
    const allocator = testing.allocator;

    // Create constraints with multiple patterns
    var constraints = [_]Constraint{
        Constraint.init(1, "async_func", "async function"),
        Constraint.init(2, "arrow_func", "arrow function =>"),
        Constraint.init(3, "class_decl", "class declaration"),
        Constraint.init(4, "return_stmt", "return statement"),
    };
    constraints[0].kind = .syntactic;
    constraints[1].kind = .syntactic;
    constraints[2].kind = .syntactic;
    constraints[3].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify all patterns have corresponding rules
    try testing.expect(findRule(grammar, "async_function") != null);
    try testing.expect(findRule(grammar, "arrow_function") != null);
    try testing.expect(findRule(grammar, "class_declaration") != null);
    try testing.expect(findRule(grammar, "return_statement") != null);

    // Verify arrow function has both expression and block forms
    const arrow_count = countRules(grammar, "arrow_function");
    try testing.expect(arrow_count >= 2);

    // Verify class has method_list
    try testing.expect(findRule(grammar, "method_list") != null);

    // Verify statement includes all alternatives
    const statement_rule = findRule(grammar, "statement");
    try testing.expect(statement_rule != null);
    if (statement_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "function_declaration"));
        try testing.expect(rhsContains(rule.rhs, "arrow_function"));
        try testing.expect(rhsContains(rule.rhs, "class_declaration"));
        try testing.expect(rhsContains(rule.rhs, "return_statement"));
        // Always includes basic statements
        try testing.expect(rhsContains(rule.rhs, "assignment"));
        try testing.expect(rhsContains(rule.rhs, "expression_statement"));
    }
}

test "buildGrammar - complex nested structures" {
    const allocator = testing.allocator;

    // Create constraints with complex nested patterns
    var constraints = [_]Constraint{
        Constraint.init(1, "switch_case", "switch case statement"),
        Constraint.init(2, "if_else", "if else statement"),
        Constraint.init(3, "async_func", "async function with try catch"),
        Constraint.init(4, "class_method", "class with methods"),
    };
    constraints[0].kind = .syntactic;
    constraints[1].kind = .syntactic;
    constraints[2].kind = .syntactic;
    constraints[3].kind = .syntactic;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Verify switch statement rules
    const switch_rule = findRule(grammar, "switch_statement");
    try testing.expect(switch_rule != null);
    if (switch_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "SWITCH"));
        try testing.expect(rhsContains(rule.rhs, "case_list"));
    }

    // Verify case_list rules exist
    try testing.expect(findRule(grammar, "case_list") != null);
    try testing.expect(findRule(grammar, "case_clause") != null);

    const case_clause = findRule(grammar, "case_clause");
    if (case_clause) |rule| {
        try testing.expect(rhsContains(rule.rhs, "CASE"));
    }

    // Verify if statement with else
    const if_count = countRules(grammar, "if_statement");
    try testing.expect(if_count >= 2); // At least one with else, one without

    // Verify class has method structure
    const class_rule = findRule(grammar, "class_declaration");
    try testing.expect(class_rule != null);
    if (class_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "CLASS"));
        try testing.expect(rhsContains(rule.rhs, "class_body"));
    }

    // Verify composability - statement_list can contain nested statements
    try testing.expect(findRule(grammar, "statement_list") != null);
    try testing.expect(findRule(grammar, "statement_list_tail") != null);

    // Verify binary operators exist
    try testing.expect(findRule(grammar, "binary_op") != null);
    const binop_count = countRules(grammar, "binary_op");
    try testing.expect(binop_count >= 4); // PLUS, MINUS, STAR, SLASH

    // Verify literals
    try testing.expect(findRule(grammar, "literal") != null);
    const literal_count = countRules(grammar, "literal");
    try testing.expect(literal_count >= 3); // NUMBER, STRING, BOOLEAN

    // Verify parameters and arguments
    try testing.expect(findRule(grammar, "params") != null);
    try testing.expect(findRule(grammar, "param_list") != null);
    try testing.expect(findRule(grammar, "args") != null);
    try testing.expect(findRule(grammar, "arg_list") != null);

    // Grammar should be reasonably sized but comprehensive
    // For this complex example, we should have at least 40 rules
    try testing.expect(grammar.rules.len >= 40);
}

test "buildGrammar - empty constraints produces minimal grammar" {
    const allocator = testing.allocator;

    // Empty constraints array
    const constraints = [_]Constraint{};

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Should still have basic structure
    try testing.expectEqualStrings("program", grammar.start_symbol);
    try testing.expect(grammar.rules.len > 0);

    // Should have program and statement rules at minimum
    try testing.expect(findRule(grammar, "program") != null);
    try testing.expect(findRule(grammar, "statement") != null);

    // Should have basic expression support
    try testing.expect(findRule(grammar, "expression") != null);

    // Should always include assignment and expression_statement
    const statement_rule = findRule(grammar, "statement");
    try testing.expect(statement_rule != null);
    if (statement_rule) |rule| {
        try testing.expect(rhsContains(rule.rhs, "assignment"));
        try testing.expect(rhsContains(rule.rhs, "expression_statement"));
    }
}

test "buildGrammar - non-syntactic constraints ignored" {
    const allocator = testing.allocator;

    // Mix of syntactic and non-syntactic constraints
    var constraints = [_]Constraint{
        Constraint.init(1, "func", "function"),
        Constraint.init(2, "type_check", "type safety"),
        Constraint.init(3, "security", "no eval"),
    };
    constraints[0].kind = .syntactic;
    constraints[1].kind = .type_safety;
    constraints[2].kind = .security;

    const grammar = try buildGrammarFromConstraints(allocator, &constraints);
    defer freeGrammar(allocator, grammar);

    // Should only process syntactic constraints
    try testing.expect(findRule(grammar, "function_declaration") != null);

    // Grammar should not have extra rules from non-syntactic constraints
    // (type_safety and security constraints are ignored in grammar building)
}
