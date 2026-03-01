"""
DSL Parser - Chain Parser Level 3
Domain-specific language parsing with AST generation
"""

from dataclasses import dataclass, field
from typing import List, Optional, Union, Any
from enum import Enum, auto


class TokenType(Enum):
    IDENTIFIER = auto()
    NUMBER = auto()
    STRING = auto()
    OPERATOR = auto()
    KEYWORD = auto()
    LPAREN = auto()
    RPAREN = auto()
    LBRACE = auto()
    RBRACE = auto()
    LBRACKET = auto()
    RBRACKET = auto()
    COMMA = auto()
    COLON = auto()
    SEMICOLON = auto()
    DOT = auto()
    ARROW = auto()
    ASSIGN = auto()
    EOF = auto()


@dataclass
class Token:
    type: TokenType
    value: str
    line: int
    column: int


@dataclass
class ASTNode:
    """Base class for AST nodes."""
    line: int = 0
    column: int = 0


@dataclass
class Identifier(ASTNode):
    name: str = ""


@dataclass
class Literal(ASTNode):
    value: Any = None
    literal_type: str = "unknown"


@dataclass
class BinaryOp(ASTNode):
    left: ASTNode = field(default_factory=ASTNode)
    operator: str = ""
    right: ASTNode = field(default_factory=ASTNode)


@dataclass
class UnaryOp(ASTNode):
    operator: str = ""
    operand: ASTNode = field(default_factory=ASTNode)


@dataclass
class FunctionCall(ASTNode):
    name: str = ""
    arguments: List[ASTNode] = field(default_factory=list)


@dataclass
class Assignment(ASTNode):
    target: str = ""
    value: ASTNode = field(default_factory=ASTNode)


@dataclass
class Block(ASTNode):
    statements: List[ASTNode] = field(default_factory=list)


@dataclass
class IfStatement(ASTNode):
    condition: ASTNode = field(default_factory=ASTNode)
    then_block: Block = field(default_factory=Block)
    else_block: Optional[Block] = None


@dataclass
class WhileStatement(ASTNode):
    condition: ASTNode = field(default_factory=ASTNode)
    body: Block = field(default_factory=Block)


@dataclass
class FunctionDef(ASTNode):
    name: str = ""
    parameters: List[str] = field(default_factory=list)
    body: Block = field(default_factory=Block)


@dataclass
class Program(ASTNode):
    statements: List[ASTNode] = field(default_factory=list)


class Lexer:
    """Tokenizes DSL source code."""

    KEYWORDS = {"if", "else", "while", "fn", "let", "return", "true", "false", "null"}
    OPERATORS = {"+", "-", "*", "/", "%", "==", "!=", "<", ">", "<=", ">=", "&&", "||", "!"}

    def __init__(self, source: str):
        self.source = source
        self.pos = 0
        self.line = 1
        self.column = 1

    def tokenize(self) -> List[Token]:
        """Tokenize the entire source."""
        tokens: List[Token] = []
        while self.pos < len(self.source):
            token = self.next_token()
            if token:
                tokens.append(token)
        tokens.append(Token(TokenType.EOF, "", self.line, self.column))
        return tokens

    def next_token(self) -> Optional[Token]:
        self.skip_whitespace()
        if self.pos >= len(self.source):
            return None

        char = self.source[self.pos]
        start_line, start_col = self.line, self.column

        # Single character tokens
        single_chars = {
            '(': TokenType.LPAREN, ')': TokenType.RPAREN,
            '{': TokenType.LBRACE, '}': TokenType.RBRACE,
            '[': TokenType.LBRACKET, ']': TokenType.RBRACKET,
            ',': TokenType.COMMA, ':': TokenType.COLON,
            ';': TokenType.SEMICOLON, '.': TokenType.DOT
        }

        if char in single_chars:
            self.advance()
            return Token(single_chars[char], char, start_line, start_col)

        # Arrow and assignment
        if char == '-' and self.peek(1) == '>':
            self.advance()
            self.advance()
            return Token(TokenType.ARROW, "->", start_line, start_col)

        if char == '=':
            if self.peek(1) == '=':
                self.advance()
                self.advance()
                return Token(TokenType.OPERATOR, "==", start_line, start_col)
            self.advance()
            return Token(TokenType.ASSIGN, "=", start_line, start_col)

        # Skip comments - must be before operator handling
        if char == '/' and self.peek(1) == '/':
            self.skip_line_comment()
            return self.next_token()

        # Two-character operators
        two_char = self.source[self.pos:self.pos+2] if self.pos + 1 < len(self.source) else ""
        if two_char in self.OPERATORS:
            self.advance()
            self.advance()
            return Token(TokenType.OPERATOR, two_char, start_line, start_col)

        # Single character operators
        if char in self.OPERATORS:
            self.advance()
            return Token(TokenType.OPERATOR, char, start_line, start_col)

        # String literals
        if char == '"' or char == "'":
            return self.read_string(char)

        # Numbers
        if char.isdigit():
            return self.read_number()

        # Identifiers and keywords
        if char.isalpha() or char == '_':
            return self.read_identifier()

        # Unknown character - skip
        self.advance()
        return None

    def read_string(self, quote: str) -> Token:
        start_line, start_col = self.line, self.column
        self.advance()  # skip opening quote
        result = []

        while self.pos < len(self.source) and self.source[self.pos] != quote:
            if self.source[self.pos] == '\\' and self.pos + 1 < len(self.source):
                self.advance()
                escape_map = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', "'": "'"}
                if self.source[self.pos] in escape_map:
                    result.append(escape_map[self.source[self.pos]])
                else:
                    result.append(self.source[self.pos])
            else:
                result.append(self.source[self.pos])
            self.advance()

        if self.pos < len(self.source):
            self.advance()  # skip closing quote

        return Token(TokenType.STRING, ''.join(result), start_line, start_col)

    def read_number(self) -> Token:
        start_line, start_col = self.line, self.column
        result = []

        while self.pos < len(self.source) and (self.source[self.pos].isdigit() or self.source[self.pos] == '.'):
            result.append(self.source[self.pos])
            self.advance()

        return Token(TokenType.NUMBER, ''.join(result), start_line, start_col)

    def read_identifier(self) -> Token:
        start_line, start_col = self.line, self.column
        result = []

        while self.pos < len(self.source) and (self.source[self.pos].isalnum() or self.source[self.pos] == '_'):
            result.append(self.source[self.pos])
            self.advance()

        value = ''.join(result)
        token_type = TokenType.KEYWORD if value in self.KEYWORDS else TokenType.IDENTIFIER

        return Token(token_type, value, start_line, start_col)

    def skip_whitespace(self):
        while self.pos < len(self.source) and self.source[self.pos] in ' \t\n\r':
            if self.source[self.pos] == '\n':
                self.line += 1
                self.column = 1
            else:
                self.column += 1
            self.pos += 1

    def skip_line_comment(self):
        while self.pos < len(self.source) and self.source[self.pos] != '\n':
            self.pos += 1

    def advance(self):
        if self.pos < len(self.source):
            if self.source[self.pos] == '\n':
                self.line += 1
                self.column = 1
            else:
                self.column += 1
            self.pos += 1

    def peek(self, offset: int = 0) -> str:
        pos = self.pos + offset
        return self.source[pos] if pos < len(self.source) else ''


class Parser:
    """Parses tokens into an AST."""

    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos = 0

    def parse(self) -> Program:
        """Parse the entire program."""
        statements: List[ASTNode] = []
        while not self.is_at_end():
            stmt = self.parse_statement()
            if stmt:
                statements.append(stmt)
        return Program(statements=statements)

    def parse_statement(self) -> Optional[ASTNode]:
        """Parse a single statement."""
        if self.match(TokenType.KEYWORD, "let"):
            return self.parse_assignment()
        elif self.match(TokenType.KEYWORD, "fn"):
            return self.parse_function_def()
        elif self.match(TokenType.KEYWORD, "if"):
            return self.parse_if()
        elif self.match(TokenType.KEYWORD, "while"):
            return self.parse_while()
        elif self.match(TokenType.KEYWORD, "return"):
            return self.parse_return()
        else:
            return self.parse_expression_statement()

    def parse_assignment(self) -> Assignment:
        """Parse variable assignment: let name = value;"""
        token = self.current()
        name_token = self.expect(TokenType.IDENTIFIER)
        self.expect(TokenType.ASSIGN)
        value = self.parse_expression()
        self.match(TokenType.SEMICOLON)  # Optional semicolon
        return Assignment(target=name_token.value, value=value, line=token.line, column=token.column)

    def parse_function_def(self) -> FunctionDef:
        """Parse function definition: fn name(params) { body }"""
        token = self.current()
        name_token = self.expect(TokenType.IDENTIFIER)
        self.expect(TokenType.LPAREN)

        params: List[str] = []
        if not self.check(TokenType.RPAREN):
            params.append(self.expect(TokenType.IDENTIFIER).value)
            while self.match(TokenType.COMMA):
                params.append(self.expect(TokenType.IDENTIFIER).value)
        self.expect(TokenType.RPAREN)

        body = self.parse_block()
        return FunctionDef(name=name_token.value, parameters=params, body=body, line=token.line, column=token.column)

    def parse_if(self) -> IfStatement:
        """Parse if statement: if (condition) { then } else { else }"""
        token = self.current()
        self.expect(TokenType.LPAREN)
        condition = self.parse_expression()
        self.expect(TokenType.RPAREN)

        then_block = self.parse_block()
        else_block = None

        if self.match(TokenType.KEYWORD, "else"):
            else_block = self.parse_block()

        return IfStatement(condition=condition, then_block=then_block, else_block=else_block, line=token.line, column=token.column)

    def parse_while(self) -> WhileStatement:
        """Parse while statement: while (condition) { body }"""
        token = self.current()
        self.expect(TokenType.LPAREN)
        condition = self.parse_expression()
        self.expect(TokenType.RPAREN)
        body = self.parse_block()
        return WhileStatement(condition=condition, body=body, line=token.line, column=token.column)

    def parse_return(self) -> FunctionCall:
        """Parse return statement as a function call for simplicity."""
        token = self.current()
        value = self.parse_expression() if not self.check(TokenType.SEMICOLON) and not self.check(TokenType.RBRACE) else Literal(value=None, literal_type="null")
        self.match(TokenType.SEMICOLON)
        return FunctionCall(name="return", arguments=[value], line=token.line, column=token.column)

    def parse_block(self) -> Block:
        """Parse a block: { statements }"""
        self.expect(TokenType.LBRACE)
        statements: List[ASTNode] = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            stmt = self.parse_statement()
            if stmt:
                statements.append(stmt)
        self.expect(TokenType.RBRACE)
        return Block(statements=statements)

    def parse_expression_statement(self) -> Optional[ASTNode]:
        """Parse an expression statement."""
        expr = self.parse_expression()
        self.match(TokenType.SEMICOLON)
        return expr

    def parse_expression(self) -> ASTNode:
        """Parse an expression (operator precedence)."""
        return self.parse_or()

    def parse_or(self) -> ASTNode:
        left = self.parse_and()
        while self.match(TokenType.OPERATOR, "||"):
            op = self.previous().value
            right = self.parse_and()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_and(self) -> ASTNode:
        left = self.parse_equality()
        while self.match(TokenType.OPERATOR, "&&"):
            op = self.previous().value
            right = self.parse_equality()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_equality(self) -> ASTNode:
        left = self.parse_comparison()
        while self.match(TokenType.OPERATOR, "==") or self.match(TokenType.OPERATOR, "!="):
            op = self.previous().value
            right = self.parse_comparison()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_comparison(self) -> ASTNode:
        left = self.parse_term()
        while self.match(TokenType.OPERATOR, "<") or self.match(TokenType.OPERATOR, ">") or \
              self.match(TokenType.OPERATOR, "<=") or self.match(TokenType.OPERATOR, ">="):
            op = self.previous().value
            right = self.parse_term()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_term(self) -> ASTNode:
        left = self.parse_factor()
        while self.match(TokenType.OPERATOR, "+") or self.match(TokenType.OPERATOR, "-"):
            op = self.previous().value
            right = self.parse_factor()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_factor(self) -> ASTNode:
        left = self.parse_unary()
        while self.match(TokenType.OPERATOR, "*") or self.match(TokenType.OPERATOR, "/") or self.match(TokenType.OPERATOR, "%"):
            op = self.previous().value
            right = self.parse_unary()
            left = BinaryOp(left=left, operator=op, right=right)
        return left

    def parse_unary(self) -> ASTNode:
        if self.match(TokenType.OPERATOR, "!") or self.match(TokenType.OPERATOR, "-"):
            op = self.previous().value
            operand = self.parse_unary()
            return UnaryOp(operator=op, operand=operand)
        return self.parse_call()

    def parse_call(self) -> ASTNode:
        expr = self.parse_primary()

        while True:
            if self.match(TokenType.LPAREN):
                args: List[ASTNode] = []
                if not self.check(TokenType.RPAREN):
                    args.append(self.parse_expression())
                    while self.match(TokenType.COMMA):
                        args.append(self.parse_expression())
                self.expect(TokenType.RPAREN)
                if isinstance(expr, Identifier):
                    expr = FunctionCall(name=expr.name, arguments=args, line=expr.line, column=expr.column)
            else:
                break

        return expr

    def parse_primary(self) -> ASTNode:
        """Parse primary expression."""
        token = self.current()

        if self.match(TokenType.NUMBER):
            value = float(token.value) if '.' in token.value else int(token.value)
            return Literal(value=value, literal_type="number", line=token.line, column=token.column)

        if self.match(TokenType.STRING):
            return Literal(value=token.value, literal_type="string", line=token.line, column=token.column)

        if self.match(TokenType.KEYWORD, "true"):
            return Literal(value=True, literal_type="boolean", line=token.line, column=token.column)

        if self.match(TokenType.KEYWORD, "false"):
            return Literal(value=False, literal_type="boolean", line=token.line, column=token.column)

        if self.match(TokenType.KEYWORD, "null"):
            return Literal(value=None, literal_type="null", line=token.line, column=token.column)

        if self.match(TokenType.IDENTIFIER):
            return Identifier(name=token.value, line=token.line, column=token.column)

        if self.match(TokenType.LPAREN):
            expr = self.parse_expression()
            self.expect(TokenType.RPAREN)
            return expr

        # Return empty identifier as fallback
        self.advance()
        return Identifier(name="", line=token.line, column=token.column)

    # Helper methods
    def current(self) -> Token:
        return self.tokens[self.pos] if self.pos < len(self.tokens) else self.tokens[-1]

    def previous(self) -> Token:
        return self.tokens[self.pos - 1] if self.pos > 0 else self.tokens[0]

    def is_at_end(self) -> bool:
        return self.current().type == TokenType.EOF

    def check(self, token_type: TokenType, value: Optional[str] = None) -> bool:
        if self.is_at_end():
            return False
        current = self.current()
        if current.type != token_type:
            return False
        if value is not None and current.value != value:
            return False
        return True

    def match(self, token_type: TokenType, value: Optional[str] = None) -> bool:
        if self.check(token_type, value):
            self.advance()
            return True
        return False

    def advance(self) -> Token:
        if not self.is_at_end():
            self.pos += 1
        return self.previous()

    def expect(self, token_type: TokenType, value: Optional[str] = None) -> Token:
        if self.check(token_type, value):
            return self.advance()
        raise SyntaxError(f"Expected {token_type}, got {self.current().type} at line {self.current().line}")


def parse_dsl(source: str) -> Program:
    """Parse DSL source code into an AST."""
    lexer = Lexer(source)
    tokens = lexer.tokenize()
    parser = Parser(tokens)
    return parser.parse()


def ast_to_dict(node: ASTNode) -> dict:
    """Convert an AST node to a dictionary for serialization."""
    result = {"type": type(node).__name__}

    if isinstance(node, Program):
        result["statements"] = [ast_to_dict(s) for s in node.statements]
    elif isinstance(node, Block):
        result["statements"] = [ast_to_dict(s) for s in node.statements]
    elif isinstance(node, FunctionDef):
        result["name"] = node.name
        result["parameters"] = node.parameters
        result["body"] = ast_to_dict(node.body)
    elif isinstance(node, FunctionCall):
        result["name"] = node.name
        result["arguments"] = [ast_to_dict(a) for a in node.arguments]
    elif isinstance(node, Assignment):
        result["target"] = node.target
        result["value"] = ast_to_dict(node.value)
    elif isinstance(node, BinaryOp):
        result["left"] = ast_to_dict(node.left)
        result["operator"] = node.operator
        result["right"] = ast_to_dict(node.right)
    elif isinstance(node, UnaryOp):
        result["operator"] = node.operator
        result["operand"] = ast_to_dict(node.operand)
    elif isinstance(node, IfStatement):
        result["condition"] = ast_to_dict(node.condition)
        result["then_block"] = ast_to_dict(node.then_block)
        if node.else_block:
            result["else_block"] = ast_to_dict(node.else_block)
    elif isinstance(node, WhileStatement):
        result["condition"] = ast_to_dict(node.condition)
        result["body"] = ast_to_dict(node.body)
    elif isinstance(node, Identifier):
        result["name"] = node.name
    elif isinstance(node, Literal):
        result["value"] = node.value
        result["literal_type"] = node.literal_type

    return result
