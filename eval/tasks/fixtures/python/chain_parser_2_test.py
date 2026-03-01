"""Tests for JSON Parser - Chain Parser Level 2"""

import pytest
from chain_parser_2 import (
    JsonParser,
    parse_json,
    get_json_type,
    JsonType,
    ParseResult
)


class TestParseNull:
    def test_parses_null(self):
        result = parse_json("null")
        assert result.success
        assert result.value is None

    def test_fails_on_invalid_null(self):
        result = parse_json("nul")
        assert not result.success


class TestParseBoolean:
    def test_parses_true(self):
        result = parse_json("true")
        assert result.success
        assert result.value is True

    def test_parses_false(self):
        result = parse_json("false")
        assert result.success
        assert result.value is False

    def test_fails_on_invalid_boolean(self):
        result = parse_json("tru")
        assert not result.success


class TestParseString:
    def test_parses_simple_string(self):
        result = parse_json('"hello"')
        assert result.success
        assert result.value == "hello"

    def test_parses_empty_string(self):
        result = parse_json('""')
        assert result.success
        assert result.value == ""

    def test_parses_escape_sequences(self):
        result = parse_json(r'"hello\nworld"')
        assert result.success
        assert result.value == "hello\nworld"

        result = parse_json(r'"tab\there"')
        assert result.success
        assert result.value == "tab\there"

    def test_parses_unicode_escape(self):
        result = parse_json(r'"\u0041"')
        assert result.success
        assert result.value == "A"

    def test_fails_on_unterminated_string(self):
        result = parse_json('"hello')
        assert not result.success
        assert "Unterminated" in result.error.message

    def test_fails_on_invalid_escape(self):
        result = parse_json(r'"\x"')
        assert not result.success


class TestParseNumber:
    def test_parses_integer(self):
        result = parse_json("42")
        assert result.success
        assert result.value == 42

    def test_parses_negative_integer(self):
        result = parse_json("-42")
        assert result.success
        assert result.value == -42

    def test_parses_float(self):
        result = parse_json("3.14")
        assert result.success
        assert result.value == 3.14

    def test_parses_exponent(self):
        result = parse_json("1e10")
        assert result.success
        assert result.value == 1e10

        result = parse_json("1E-5")
        assert result.success
        assert result.value == 1e-5

    def test_parses_zero(self):
        result = parse_json("0")
        assert result.success
        assert result.value == 0

    def test_parses_negative_zero(self):
        result = parse_json("-0")
        assert result.success
        assert result.value == 0


class TestParseArray:
    def test_parses_empty_array(self):
        result = parse_json("[]")
        assert result.success
        assert result.value == []

    def test_parses_simple_array(self):
        result = parse_json("[1, 2, 3]")
        assert result.success
        assert result.value == [1, 2, 3]

    def test_parses_mixed_array(self):
        result = parse_json('[1, "hello", true, null]')
        assert result.success
        assert result.value == [1, "hello", True, None]

    def test_parses_nested_array(self):
        result = parse_json("[[1, 2], [3, 4]]")
        assert result.success
        assert result.value == [[1, 2], [3, 4]]

    def test_fails_on_unterminated_array(self):
        result = parse_json("[1, 2")
        assert not result.success

    def test_fails_on_trailing_comma(self):
        result = parse_json("[1, 2,]")
        assert not result.success


class TestParseObject:
    def test_parses_empty_object(self):
        result = parse_json("{}")
        assert result.success
        assert result.value == {}

    def test_parses_simple_object(self):
        result = parse_json('{"name": "John", "age": 30}')
        assert result.success
        assert result.value == {"name": "John", "age": 30}

    def test_parses_nested_object(self):
        result = parse_json('{"person": {"name": "John"}}')
        assert result.success
        assert result.value == {"person": {"name": "John"}}

    def test_parses_object_with_array(self):
        result = parse_json('{"items": [1, 2, 3]}')
        assert result.success
        assert result.value == {"items": [1, 2, 3]}

    def test_fails_on_unterminated_object(self):
        result = parse_json('{"key": "value"')
        assert not result.success

    def test_fails_on_missing_colon(self):
        result = parse_json('{"key" "value"}')
        assert not result.success

    def test_fails_on_non_string_key(self):
        result = parse_json('{42: "value"}')
        assert not result.success


class TestWhitespace:
    def test_handles_leading_whitespace(self):
        result = parse_json("   42")
        assert result.success
        assert result.value == 42

    def test_handles_trailing_whitespace(self):
        result = parse_json("42   ")
        assert result.success
        assert result.value == 42

    def test_handles_whitespace_in_array(self):
        result = parse_json("[ 1 , 2 , 3 ]")
        assert result.success
        assert result.value == [1, 2, 3]

    def test_handles_whitespace_in_object(self):
        result = parse_json('{ "key" : "value" }')
        assert result.success
        assert result.value == {"key": "value"}

    def test_handles_newlines(self):
        result = parse_json('{\n  "key": "value"\n}')
        assert result.success
        assert result.value == {"key": "value"}


class TestGetJsonType:
    def test_identifies_null(self):
        assert get_json_type(None) == JsonType.NULL

    def test_identifies_boolean(self):
        assert get_json_type(True) == JsonType.BOOLEAN
        assert get_json_type(False) == JsonType.BOOLEAN

    def test_identifies_number(self):
        assert get_json_type(42) == JsonType.NUMBER
        assert get_json_type(3.14) == JsonType.NUMBER

    def test_identifies_string(self):
        assert get_json_type("hello") == JsonType.STRING

    def test_identifies_array(self):
        assert get_json_type([1, 2, 3]) == JsonType.ARRAY

    def test_identifies_object(self):
        assert get_json_type({"key": "value"}) == JsonType.OBJECT


class TestParseErrors:
    def test_error_contains_position(self):
        result = parse_json('{"key": }')
        assert not result.success
        assert result.error.position > 0

    def test_error_contains_context(self):
        result = parse_json('{"valid": 1, invalid: 2}')
        assert not result.success
        assert result.error.context != ""

    def test_fails_on_extra_content(self):
        result = parse_json('42 extra')
        assert not result.success
        assert "Unexpected character" in result.error.message


class TestComplexJson:
    def test_parses_complex_document(self):
        json_text = '''
        {
            "name": "John Doe",
            "age": 30,
            "active": true,
            "address": {
                "street": "123 Main St",
                "city": "Anytown"
            },
            "tags": ["developer", "python"],
            "nullable": null
        }
        '''
        result = parse_json(json_text)
        assert result.success
        assert result.value["name"] == "John Doe"
        assert result.value["age"] == 30
        assert result.value["active"] is True
        assert result.value["address"]["city"] == "Anytown"
        assert result.value["tags"] == ["developer", "python"]
        assert result.value["nullable"] is None
