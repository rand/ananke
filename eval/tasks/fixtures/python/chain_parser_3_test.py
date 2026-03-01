"""Tests for DSL Parser - Chain Parser Level 3"""

import pytest
from chain_parser_3 import (
    Lexer,
    Parser,
    parse_dsl,
    ast_to_dict,
    TokenType,
    Program,
    FunctionDef,
    FunctionCall,
    Assignment,
    BinaryOp,
    UnaryOp,
    IfStatement,
    WhileStatement,
    Identifier,
    Literal,
    Block
)


class TestLexer:
    def test_tokenizes_identifiers(self):
        lexer = Lexer("foo bar baz")
        tokens = lexer.tokenize()
        assert tokens[0].type == TokenType.IDENTIFIER
        assert tokens[0].value == "foo"
        assert tokens[1].value == "bar"
        assert tokens[2].value == "baz"

    def test_tokenizes_keywords(self):
        lexer = Lexer("if else while fn let return")
        tokens = lexer.tokenize()
        assert all(t.type == TokenType.KEYWORD for t in tokens[:-1])

    def test_tokenizes_numbers(self):
        lexer = Lexer("42 3.14 0")
        tokens = lexer.tokenize()
        assert tokens[0].type == TokenType.NUMBER
        assert tokens[0].value == "42"
        assert tokens[1].value == "3.14"

    def test_tokenizes_strings(self):
        lexer = Lexer('"hello" \'world\'')
        tokens = lexer.tokenize()
        assert tokens[0].type == TokenType.STRING
        assert tokens[0].value == "hello"
        assert tokens[1].value == "world"

    def test_tokenizes_operators(self):
        lexer = Lexer("+ - * / == != < > <= >=")
        tokens = lexer.tokenize()
        assert all(t.type == TokenType.OPERATOR for t in tokens[:-1])

    def test_tokenizes_punctuation(self):
        lexer = Lexer("( ) { } [ ] , : ;")
        tokens = lexer.tokenize()
        assert tokens[0].type == TokenType.LPAREN
        assert tokens[1].type == TokenType.RPAREN
        assert tokens[2].type == TokenType.LBRACE
        assert tokens[3].type == TokenType.RBRACE

    def test_handles_escape_sequences(self):
        lexer = Lexer(r'"hello\nworld"')
        tokens = lexer.tokenize()
        assert tokens[0].value == "hello\nworld"

    def test_skips_comments(self):
        lexer = Lexer("foo // this is a comment\nbar")
        tokens = lexer.tokenize()
        assert len(tokens) == 3  # foo, bar, EOF

    def test_tracks_line_numbers(self):
        lexer = Lexer("foo\nbar\nbaz")
        tokens = lexer.tokenize()
        assert tokens[0].line == 1
        assert tokens[1].line == 2
        assert tokens[2].line == 3


class TestParser:
    def test_parses_literal_number(self):
        program = parse_dsl("42")
        assert len(program.statements) == 1
        assert isinstance(program.statements[0], Literal)
        assert program.statements[0].value == 42

    def test_parses_literal_string(self):
        program = parse_dsl('"hello"')
        assert isinstance(program.statements[0], Literal)
        assert program.statements[0].value == "hello"

    def test_parses_literal_boolean(self):
        program = parse_dsl("true")
        assert isinstance(program.statements[0], Literal)
        assert program.statements[0].value is True

    def test_parses_identifier(self):
        program = parse_dsl("foo")
        assert isinstance(program.statements[0], Identifier)
        assert program.statements[0].name == "foo"

    def test_parses_binary_expression(self):
        program = parse_dsl("1 + 2")
        assert isinstance(program.statements[0], BinaryOp)
        assert program.statements[0].operator == "+"

    def test_parses_operator_precedence(self):
        program = parse_dsl("1 + 2 * 3")
        # Should parse as 1 + (2 * 3)
        stmt = program.statements[0]
        assert isinstance(stmt, BinaryOp)
        assert stmt.operator == "+"
        assert isinstance(stmt.right, BinaryOp)
        assert stmt.right.operator == "*"

    def test_parses_unary_expression(self):
        program = parse_dsl("!true")
        assert isinstance(program.statements[0], UnaryOp)
        assert program.statements[0].operator == "!"

    def test_parses_function_call(self):
        program = parse_dsl("foo(1, 2, 3)")
        assert isinstance(program.statements[0], FunctionCall)
        assert program.statements[0].name == "foo"
        assert len(program.statements[0].arguments) == 3

    def test_parses_assignment(self):
        program = parse_dsl("let x = 42")
        assert isinstance(program.statements[0], Assignment)
        assert program.statements[0].target == "x"

    def test_parses_function_definition(self):
        program = parse_dsl("fn add(a, b) { return a + b; }")
        assert isinstance(program.statements[0], FunctionDef)
        assert program.statements[0].name == "add"
        assert program.statements[0].parameters == ["a", "b"]

    def test_parses_if_statement(self):
        program = parse_dsl("if (x > 0) { y }")
        assert isinstance(program.statements[0], IfStatement)

    def test_parses_if_else_statement(self):
        program = parse_dsl("if (x > 0) { y } else { z }")
        stmt = program.statements[0]
        assert isinstance(stmt, IfStatement)
        assert stmt.else_block is not None

    def test_parses_while_statement(self):
        program = parse_dsl("while (x > 0) { x = x - 1 }")
        assert isinstance(program.statements[0], WhileStatement)

    def test_parses_nested_expressions(self):
        program = parse_dsl("(1 + 2) * 3")
        stmt = program.statements[0]
        assert isinstance(stmt, BinaryOp)
        assert stmt.operator == "*"
        assert isinstance(stmt.left, BinaryOp)

    def test_parses_comparison_chain(self):
        program = parse_dsl("a && b || c")
        stmt = program.statements[0]
        assert isinstance(stmt, BinaryOp)
        assert stmt.operator == "||"


class TestAstToDict:
    def test_converts_literal(self):
        node = Literal(value=42, literal_type="number")
        result = ast_to_dict(node)
        assert result["type"] == "Literal"
        assert result["value"] == 42

    def test_converts_binary_op(self):
        node = BinaryOp(
            left=Literal(value=1, literal_type="number"),
            operator="+",
            right=Literal(value=2, literal_type="number")
        )
        result = ast_to_dict(node)
        assert result["type"] == "BinaryOp"
        assert result["operator"] == "+"
        assert result["left"]["value"] == 1
        assert result["right"]["value"] == 2

    def test_converts_function_def(self):
        node = FunctionDef(
            name="add",
            parameters=["a", "b"],
            body=Block(statements=[])
        )
        result = ast_to_dict(node)
        assert result["type"] == "FunctionDef"
        assert result["name"] == "add"
        assert result["parameters"] == ["a", "b"]

    def test_converts_program(self):
        program = parse_dsl("let x = 42")
        result = ast_to_dict(program)
        assert result["type"] == "Program"
        assert len(result["statements"]) == 1


class TestIntegration:
    def test_parses_complete_program(self):
        source = """
        fn factorial(n) {
            if (n <= 1) {
                return 1
            } else {
                return n * factorial(n - 1)
            }
        }

        let result = factorial(5)
        """
        program = parse_dsl(source)
        assert len(program.statements) == 2
        assert isinstance(program.statements[0], FunctionDef)
        assert isinstance(program.statements[1], Assignment)

    def test_parses_arithmetic_expressions(self):
        source = "1 + 2 * 3 - 4 / 2"
        program = parse_dsl(source)
        result = ast_to_dict(program)
        assert result["type"] == "Program"

    def test_parses_logical_expressions(self):
        source = "a && b || c && !d"
        program = parse_dsl(source)
        assert len(program.statements) == 1

    def test_parses_while_loop(self):
        source = """
        let i = 0
        while (i < 10) {
            print(i)
            let i = i + 1
        }
        """
        program = parse_dsl(source)
        assert len(program.statements) == 2
        assert isinstance(program.statements[1], WhileStatement)

    def test_handles_nested_function_calls(self):
        source = "foo(bar(1), baz(2, 3))"
        program = parse_dsl(source)
        stmt = program.statements[0]
        assert isinstance(stmt, FunctionCall)
        assert len(stmt.arguments) == 2
        assert isinstance(stmt.arguments[0], FunctionCall)
        assert isinstance(stmt.arguments[1], FunctionCall)
