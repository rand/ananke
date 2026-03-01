"""
JSON Parser - Chain Parser Level 2
Recursive JSON parsing with validation
"""

from dataclasses import dataclass
from typing import Any, Optional, List, Union
from enum import Enum


class JsonType(Enum):
    NULL = "null"
    BOOLEAN = "boolean"
    NUMBER = "number"
    STRING = "string"
    ARRAY = "array"
    OBJECT = "object"


@dataclass
class ParseError:
    message: str
    position: int
    context: str


@dataclass
class ParseResult:
    success: bool
    value: Any
    error: Optional[ParseError]
    position: int


class JsonParser:
    def __init__(self, text: str):
        self.text = text
        self.pos = 0

    def parse(self) -> ParseResult:
        """Parse the JSON text and return a ParseResult."""
        self.skip_whitespace()
        if self.pos >= len(self.text):
            return ParseResult(False, None, ParseError("Unexpected end of input", self.pos, ""), self.pos)

        result = self.parse_value()
        if result.success:
            self.skip_whitespace()
            if self.pos < len(self.text):
                return ParseResult(False, None, ParseError(f"Unexpected character after value: {self.text[self.pos]}", self.pos, self.get_context()), self.pos)
        return result

    def parse_value(self) -> ParseResult:
        """Parse any JSON value."""
        self.skip_whitespace()
        if self.pos >= len(self.text):
            return ParseResult(False, None, ParseError("Unexpected end of input", self.pos, ""), self.pos)

        char = self.text[self.pos]

        if char == 'n':
            return self.parse_null()
        elif char == 't' or char == 'f':
            return self.parse_boolean()
        elif char == '"':
            return self.parse_string()
        elif char == '[':
            return self.parse_array()
        elif char == '{':
            return self.parse_object()
        elif char == '-' or char.isdigit():
            return self.parse_number()
        else:
            return ParseResult(False, None, ParseError(f"Unexpected character: {char}", self.pos, self.get_context()), self.pos)

    def parse_null(self) -> ParseResult:
        if self.text[self.pos:self.pos+4] == 'null':
            self.pos += 4
            return ParseResult(True, None, None, self.pos)
        return ParseResult(False, None, ParseError("Expected 'null'", self.pos, self.get_context()), self.pos)

    def parse_boolean(self) -> ParseResult:
        if self.text[self.pos:self.pos+4] == 'true':
            self.pos += 4
            return ParseResult(True, True, None, self.pos)
        elif self.text[self.pos:self.pos+5] == 'false':
            self.pos += 5
            return ParseResult(True, False, None, self.pos)
        return ParseResult(False, None, ParseError("Expected 'true' or 'false'", self.pos, self.get_context()), self.pos)

    def parse_string(self) -> ParseResult:
        if self.text[self.pos] != '"':
            return ParseResult(False, None, ParseError("Expected '\"'", self.pos, self.get_context()), self.pos)

        self.pos += 1
        start = self.pos
        result = []

        while self.pos < len(self.text):
            char = self.text[self.pos]
            if char == '"':
                self.pos += 1
                return ParseResult(True, ''.join(result), None, self.pos)
            elif char == '\\':
                self.pos += 1
                if self.pos >= len(self.text):
                    return ParseResult(False, None, ParseError("Unexpected end of string", self.pos, self.get_context()), self.pos)
                escape_char = self.text[self.pos]
                escape_map = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', '/': '/'}
                if escape_char in escape_map:
                    result.append(escape_map[escape_char])
                elif escape_char == 'u':
                    if self.pos + 4 >= len(self.text):
                        return ParseResult(False, None, ParseError("Invalid unicode escape", self.pos, self.get_context()), self.pos)
                    hex_str = self.text[self.pos+1:self.pos+5]
                    try:
                        result.append(chr(int(hex_str, 16)))
                        self.pos += 4
                    except ValueError:
                        return ParseResult(False, None, ParseError("Invalid unicode escape", self.pos, self.get_context()), self.pos)
                else:
                    return ParseResult(False, None, ParseError(f"Invalid escape character: {escape_char}", self.pos, self.get_context()), self.pos)
            else:
                result.append(char)
            self.pos += 1

        return ParseResult(False, None, ParseError("Unterminated string", start, self.get_context()), self.pos)

    def parse_number(self) -> ParseResult:
        start = self.pos
        if self.text[self.pos] == '-':
            self.pos += 1

        if self.pos >= len(self.text) or not self.text[self.pos].isdigit():
            return ParseResult(False, None, ParseError("Expected digit", self.pos, self.get_context()), self.pos)

        if self.text[self.pos] == '0':
            self.pos += 1
        else:
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1

        # Decimal part
        if self.pos < len(self.text) and self.text[self.pos] == '.':
            self.pos += 1
            if self.pos >= len(self.text) or not self.text[self.pos].isdigit():
                return ParseResult(False, None, ParseError("Expected digit after decimal", self.pos, self.get_context()), self.pos)
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1

        # Exponent part
        if self.pos < len(self.text) and self.text[self.pos] in 'eE':
            self.pos += 1
            if self.pos < len(self.text) and self.text[self.pos] in '+-':
                self.pos += 1
            if self.pos >= len(self.text) or not self.text[self.pos].isdigit():
                return ParseResult(False, None, ParseError("Expected digit in exponent", self.pos, self.get_context()), self.pos)
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1

        num_str = self.text[start:self.pos]
        try:
            if '.' in num_str or 'e' in num_str or 'E' in num_str:
                return ParseResult(True, float(num_str), None, self.pos)
            else:
                return ParseResult(True, int(num_str), None, self.pos)
        except ValueError:
            return ParseResult(False, None, ParseError(f"Invalid number: {num_str}", start, self.get_context()), self.pos)

    def parse_array(self) -> ParseResult:
        if self.text[self.pos] != '[':
            return ParseResult(False, None, ParseError("Expected '['", self.pos, self.get_context()), self.pos)

        self.pos += 1
        result: List[Any] = []

        self.skip_whitespace()
        if self.pos < len(self.text) and self.text[self.pos] == ']':
            self.pos += 1
            return ParseResult(True, result, None, self.pos)

        while True:
            value_result = self.parse_value()
            if not value_result.success:
                return value_result
            result.append(value_result.value)

            self.skip_whitespace()
            if self.pos >= len(self.text):
                return ParseResult(False, None, ParseError("Unterminated array", self.pos, self.get_context()), self.pos)

            if self.text[self.pos] == ']':
                self.pos += 1
                return ParseResult(True, result, None, self.pos)
            elif self.text[self.pos] == ',':
                self.pos += 1
            else:
                return ParseResult(False, None, ParseError("Expected ',' or ']'", self.pos, self.get_context()), self.pos)

    def parse_object(self) -> ParseResult:
        if self.text[self.pos] != '{':
            return ParseResult(False, None, ParseError("Expected '{'", self.pos, self.get_context()), self.pos)

        self.pos += 1
        result: dict = {}

        self.skip_whitespace()
        if self.pos < len(self.text) and self.text[self.pos] == '}':
            self.pos += 1
            return ParseResult(True, result, None, self.pos)

        while True:
            self.skip_whitespace()
            key_result = self.parse_string()
            if not key_result.success:
                return ParseResult(False, None, ParseError("Expected string key", self.pos, self.get_context()), self.pos)

            self.skip_whitespace()
            if self.pos >= len(self.text) or self.text[self.pos] != ':':
                return ParseResult(False, None, ParseError("Expected ':'", self.pos, self.get_context()), self.pos)
            self.pos += 1

            value_result = self.parse_value()
            if not value_result.success:
                return value_result

            result[key_result.value] = value_result.value

            self.skip_whitespace()
            if self.pos >= len(self.text):
                return ParseResult(False, None, ParseError("Unterminated object", self.pos, self.get_context()), self.pos)

            if self.text[self.pos] == '}':
                self.pos += 1
                return ParseResult(True, result, None, self.pos)
            elif self.text[self.pos] == ',':
                self.pos += 1
            else:
                return ParseResult(False, None, ParseError("Expected ',' or '}'", self.pos, self.get_context()), self.pos)

    def skip_whitespace(self):
        while self.pos < len(self.text) and self.text[self.pos] in ' \t\n\r':
            self.pos += 1

    def get_context(self) -> str:
        start = max(0, self.pos - 10)
        end = min(len(self.text), self.pos + 10)
        return self.text[start:end]


def parse_json(text: str) -> ParseResult:
    """Convenience function to parse JSON text."""
    parser = JsonParser(text)
    return parser.parse()


def get_json_type(value: Any) -> JsonType:
    """Determine the JSON type of a value."""
    if value is None:
        return JsonType.NULL
    elif isinstance(value, bool):
        return JsonType.BOOLEAN
    elif isinstance(value, (int, float)):
        return JsonType.NUMBER
    elif isinstance(value, str):
        return JsonType.STRING
    elif isinstance(value, list):
        return JsonType.ARRAY
    elif isinstance(value, dict):
        return JsonType.OBJECT
    else:
        raise ValueError(f"Unknown type: {type(value)}")
