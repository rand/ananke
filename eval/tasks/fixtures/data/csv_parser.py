"""CSV parser with automatic type conversion."""

import re
from typing import Any


def parse_csv(content: str) -> list[dict[str, Any]]:
    """Parse CSV content into a list of dictionaries.

    Args:
        content: CSV string content with headers in first row

    Returns:
        List of dictionaries, one per data row. Returns empty list
        for empty input or header-only CSV.
    """
    if not content or not content.strip():
        return []

    lines = content.strip().split('\n')

    # Filter out empty lines
    lines = [line for line in lines if line.strip()]

    if not lines:
        return []

    # Parse headers
    headers = _parse_row(lines[0])

    # Parse data rows
    result = []
    for line in lines[1:]:
        if not line.strip():
            continue

        values = _parse_row(line)

        # Convert to dictionary with type conversion
        row_dict = {}
        for i, header in enumerate(headers):
            if i < len(values):
                row_dict[header] = _convert_type(values[i])
            else:
                row_dict[header] = None

        result.append(row_dict)

    return result


def _parse_row(row: str) -> list[str]:
    """Parse a single CSV row, handling quoted fields.

    Args:
        row: A single CSV row string

    Returns:
        List of field values with whitespace stripped
    """
    fields = []
    current_field = []
    in_quotes = False

    for char in row:
        if char == '"':
            in_quotes = not in_quotes
        elif char == ',' and not in_quotes:
            fields.append(''.join(current_field).strip())
            current_field = []
        else:
            current_field.append(char)

    # Add the last field
    fields.append(''.join(current_field).strip())

    return fields


def _convert_type(value: str) -> int | float | str:
    """Convert a string value to int, float, or leave as string.

    Args:
        value: String value to convert

    Returns:
        Converted value (int, float, or original string)
    """
    value = value.strip()

    if not value:
        return value

    # Try to convert to number
    try:
        # Check if it contains a decimal point
        if '.' in value:
            return float(value)
        else:
            return int(value)
    except ValueError:
        return value
