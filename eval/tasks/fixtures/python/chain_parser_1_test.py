"""Tests for Line Parser - Chain Parser Level 1"""

import pytest
from chain_parser_1 import (
    parse_line,
    parse_lines,
    extract_field,
    parse_key_value,
    filter_data_lines,
    count_fields,
    ParsedLine
)


class TestParseLine:
    def test_parses_csv_line(self):
        result = parse_line("a,b,c", 0)
        assert result.fields == ["a", "b", "c"]
        assert not result.is_empty
        assert not result.is_comment

    def test_parses_with_custom_delimiter(self):
        result = parse_line("a|b|c", 0, delimiter="|")
        assert result.fields == ["a", "b", "c"]

    def test_strips_whitespace(self):
        result = parse_line("  a , b , c  ", 0)
        assert result.fields == ["a", "b", "c"]

    def test_handles_empty_line(self):
        result = parse_line("", 0)
        assert result.is_empty
        assert result.fields == []

    def test_handles_whitespace_only_line(self):
        result = parse_line("   ", 0)
        assert result.is_empty

    def test_handles_comment_line(self):
        result = parse_line("# this is a comment", 0)
        assert result.is_comment
        assert result.fields == []

    def test_custom_comment_char(self):
        result = parse_line("// this is a comment", 0, comment_char="//")
        assert result.is_comment

    def test_preserves_raw_line(self):
        raw = "  a, b, c  "
        result = parse_line(raw, 5)
        assert result.raw == raw
        assert result.line_number == 5


class TestParseLines:
    def test_parses_multiple_lines(self):
        text = "a,b\nc,d\ne,f"
        results = parse_lines(text)
        assert len(results) == 3
        assert results[0].fields == ["a", "b"]
        assert results[1].fields == ["c", "d"]
        assert results[2].fields == ["e", "f"]

    def test_assigns_line_numbers(self):
        text = "a\nb\nc"
        results = parse_lines(text)
        assert results[0].line_number == 0
        assert results[1].line_number == 1
        assert results[2].line_number == 2

    def test_handles_mixed_content(self):
        text = "# header\na,b\n\nc,d"
        results = parse_lines(text)
        assert results[0].is_comment
        assert not results[1].is_comment and not results[1].is_empty
        assert results[2].is_empty
        assert not results[3].is_comment and not results[3].is_empty


class TestExtractField:
    def test_extracts_valid_index(self):
        parsed = ParsedLine(raw="a,b,c", fields=["a", "b", "c"], line_number=0, is_empty=False, is_comment=False)
        assert extract_field(parsed, 0) == "a"
        assert extract_field(parsed, 1) == "b"
        assert extract_field(parsed, 2) == "c"

    def test_returns_default_for_invalid_index(self):
        parsed = ParsedLine(raw="a,b", fields=["a", "b"], line_number=0, is_empty=False, is_comment=False)
        assert extract_field(parsed, 5) is None
        assert extract_field(parsed, 5, "default") == "default"

    def test_handles_negative_index(self):
        parsed = ParsedLine(raw="a,b", fields=["a", "b"], line_number=0, is_empty=False, is_comment=False)
        assert extract_field(parsed, -1) is None


class TestParseKeyValue:
    def test_parses_key_value_pair(self):
        key, value = parse_key_value("name=John")
        assert key == "name"
        assert value == "John"

    def test_strips_whitespace(self):
        key, value = parse_key_value("  name  =  John Doe  ")
        assert key == "name"
        assert value == "John Doe"

    def test_handles_missing_separator(self):
        key, value = parse_key_value("no separator here")
        assert key is None
        assert value is None

    def test_handles_empty_value(self):
        key, value = parse_key_value("key=")
        assert key == "key"
        assert value == ""

    def test_custom_separator(self):
        key, value = parse_key_value("key: value", separator=":")
        assert key == "key"
        assert value == "value"

    def test_handles_multiple_separators(self):
        key, value = parse_key_value("url=http://example.com")
        assert key == "url"
        assert value == "http://example.com"


class TestFilterDataLines:
    def test_filters_empty_and_comments(self):
        lines = [
            ParsedLine("# comment", [], 0, False, True),
            ParsedLine("a,b", ["a", "b"], 1, False, False),
            ParsedLine("", [], 2, True, False),
            ParsedLine("c,d", ["c", "d"], 3, False, False),
        ]
        result = filter_data_lines(lines)
        assert len(result) == 2
        assert result[0].line_number == 1
        assert result[1].line_number == 3


class TestCountFields:
    def test_counts_field_distribution(self):
        lines = [
            ParsedLine("a", ["a"], 0, False, False),
            ParsedLine("a,b", ["a", "b"], 1, False, False),
            ParsedLine("a,b", ["a", "b"], 2, False, False),
            ParsedLine("a,b,c", ["a", "b", "c"], 3, False, False),
        ]
        counts = count_fields(lines)
        assert counts == {1: 1, 2: 2, 3: 1}

    def test_ignores_empty_and_comments(self):
        lines = [
            ParsedLine("", [], 0, True, False),
            ParsedLine("# comment", [], 1, False, True),
            ParsedLine("a,b", ["a", "b"], 2, False, False),
        ]
        counts = count_fields(lines)
        assert counts == {2: 1}
