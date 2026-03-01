"""
Line Parser - Chain Parser Level 1
Basic line-by-line text parsing with field extraction
"""

from dataclasses import dataclass
from typing import Optional, List, Tuple


@dataclass
class ParsedLine:
    """Represents a parsed line with its components."""
    raw: str
    fields: List[str]
    line_number: int
    is_empty: bool
    is_comment: bool


def parse_line(line: str, line_number: int = 0, delimiter: str = ',', comment_char: str = '#') -> ParsedLine:
    """Parse a single line into its components."""
    stripped = line.strip()

    if not stripped:
        return ParsedLine(
            raw=line,
            fields=[],
            line_number=line_number,
            is_empty=True,
            is_comment=False
        )

    if stripped.startswith(comment_char):
        return ParsedLine(
            raw=line,
            fields=[],
            line_number=line_number,
            is_empty=False,
            is_comment=True
        )

    fields = [f.strip() for f in stripped.split(delimiter)]

    return ParsedLine(
        raw=line,
        fields=fields,
        line_number=line_number,
        is_empty=False,
        is_comment=False
    )


def parse_lines(text: str, delimiter: str = ',', comment_char: str = '#') -> List[ParsedLine]:
    """Parse multiple lines of text."""
    lines = text.split('\n')
    return [parse_line(line, i, delimiter, comment_char) for i, line in enumerate(lines)]


def extract_field(parsed: ParsedLine, index: int, default: Optional[str] = None) -> Optional[str]:
    """Extract a field by index from a parsed line."""
    if index < 0 or index >= len(parsed.fields):
        return default
    return parsed.fields[index]


def parse_key_value(line: str, separator: str = '=') -> Tuple[Optional[str], Optional[str]]:
    """Parse a line as a key-value pair."""
    if separator not in line:
        return (None, None)

    parts = line.split(separator, 1)
    key = parts[0].strip()
    value = parts[1].strip() if len(parts) > 1 else ''

    return (key, value)


def filter_data_lines(parsed_lines: List[ParsedLine]) -> List[ParsedLine]:
    """Filter out empty lines and comments, returning only data lines."""
    return [p for p in parsed_lines if not p.is_empty and not p.is_comment]


def count_fields(parsed_lines: List[ParsedLine]) -> dict:
    """Count how many lines have each number of fields."""
    counts: dict = {}
    for line in parsed_lines:
        if not line.is_empty and not line.is_comment:
            n = len(line.fields)
            counts[n] = counts.get(n, 0) + 1
    return counts
