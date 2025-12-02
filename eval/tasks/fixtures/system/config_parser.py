"""INI configuration file parser."""

from typing import Any


def parse_config(content: str) -> dict[str, dict[str, Any]]:
    """Parse INI-style configuration file content.

    Args:
        content: INI file content as string

    Returns:
        Nested dictionary with structure {section: {key: value}}.
        Keys without sections are placed in 'default' section.
        Returns empty dict for empty input.
    """
    if not content or not content.strip():
        return {}

    config: dict[str, dict[str, Any]] = {}
    current_section = "default"

    for line in content.split('\n'):
        line = line.strip()

        # Skip empty lines
        if not line:
            continue

        # Skip comments
        if line.startswith('#') or line.startswith(';'):
            continue

        # Check for section header
        if line.startswith('[') and line.endswith(']'):
            current_section = line[1:-1].strip()
            if current_section not in config:
                config[current_section] = {}
            continue

        # Parse key=value pair
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()

            # Ensure current section exists
            if current_section not in config:
                config[current_section] = {}

            # Convert value to appropriate type
            config[current_section][key] = _convert_value(value)

    return config


def _convert_value(value: str) -> bool | int | float | str:
    """Convert a string value to the appropriate type.

    Args:
        value: String value to convert

    Returns:
        Converted value (bool, int, float, or original string)
    """
    # Check for boolean values
    lower_value = value.lower()
    if lower_value in ('true', 'yes', 'on', '1'):
        return True
    if lower_value in ('false', 'no', 'off', '0'):
        # Special case: '0' as string could be int, but we prioritize bool
        if value == '0':
            return False
        if lower_value in ('false', 'no', 'off'):
            return False

    # Try to convert to number
    try:
        if '.' in value:
            return float(value)
        else:
            return int(value)
    except ValueError:
        pass

    # Return as string if no conversion applies
    return value
