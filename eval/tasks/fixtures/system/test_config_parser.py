"""Tests for INI config parser."""

import pytest
from config_parser import parse_config


def test_basic_section_with_keys():
    """Test basic section with key-value pairs."""
    config_text = """[database]
host=localhost
port=5432
name=mydb"""

    result = parse_config(config_text)

    assert result == {
        "database": {
            "host": "localhost",
            "port": 5432,
            "name": "mydb"
        }
    }


def test_multiple_sections():
    """Test multiple sections."""
    config_text = """[database]
host=localhost

[server]
port=8080
debug=true"""

    result = parse_config(config_text)

    assert result == {
        "database": {"host": "localhost"},
        "server": {"port": 8080, "debug": True}
    }


def test_default_section():
    """Test keys without section go to 'default'."""
    config_text = """key1=value1
key2=123

[section1]
key3=value3"""

    result = parse_config(config_text)

    assert result == {
        "default": {"key1": "value1", "key2": 123},
        "section1": {"key3": "value3"}
    }


def test_comments_with_hash():
    """Test that lines starting with # are ignored."""
    config_text = """# This is a comment
[database]
# Another comment
host=localhost
port=5432"""

    result = parse_config(config_text)

    assert result == {
        "database": {
            "host": "localhost",
            "port": 5432
        }
    }


def test_comments_with_semicolon():
    """Test that lines starting with ; are ignored."""
    config_text = """; This is a comment
[database]
; Another comment
host=localhost
port=5432"""

    result = parse_config(config_text)

    assert result == {
        "database": {
            "host": "localhost",
            "port": 5432
        }
    }


def test_whitespace_handling():
    """Test that whitespace is stripped from keys and values."""
    config_text = """[database]
  host  =  localhost
  port  =  5432  """

    result = parse_config(config_text)

    assert result == {
        "database": {
            "host": "localhost",
            "port": 5432
        }
    }


def test_boolean_conversion_true():
    """Test conversion of true-like values."""
    config_text = """[settings]
enabled1=true
enabled2=True
enabled3=yes
enabled4=on"""

    result = parse_config(config_text)

    assert result["settings"]["enabled1"] is True
    assert result["settings"]["enabled2"] is True
    assert result["settings"]["enabled3"] is True
    assert result["settings"]["enabled4"] is True


def test_boolean_conversion_false():
    """Test conversion of false-like values."""
    config_text = """[settings]
disabled1=false
disabled2=False
disabled3=no
disabled4=off"""

    result = parse_config(config_text)

    assert result["settings"]["disabled1"] is False
    assert result["settings"]["disabled2"] is False
    assert result["settings"]["disabled3"] is False
    assert result["settings"]["disabled4"] is False


def test_integer_conversion():
    """Test automatic conversion of integers."""
    config_text = """[settings]
port=8080
count=100
negative=-42"""

    result = parse_config(config_text)

    assert result["settings"]["port"] == 8080
    assert isinstance(result["settings"]["port"], int)
    assert result["settings"]["count"] == 100
    assert result["settings"]["negative"] == -42


def test_float_conversion():
    """Test automatic conversion of floats."""
    config_text = """[settings]
version=1.5
ratio=0.75
negative=-3.14"""

    result = parse_config(config_text)

    assert result["settings"]["version"] == 1.5
    assert isinstance(result["settings"]["version"], float)
    assert result["settings"]["ratio"] == 0.75
    assert result["settings"]["negative"] == -3.14


def test_string_values():
    """Test that non-convertible values remain strings."""
    config_text = """[settings]
name=MyApp
path=/usr/local/bin
mixed=abc123"""

    result = parse_config(config_text)

    assert result["settings"]["name"] == "MyApp"
    assert isinstance(result["settings"]["name"], str)
    assert result["settings"]["path"] == "/usr/local/bin"
    assert result["settings"]["mixed"] == "abc123"


def test_empty_input():
    """Test handling of empty input."""
    assert parse_config("") == {}
    assert parse_config("   ") == {}
    assert parse_config("\n\n\n") == {}


def test_empty_lines_ignored():
    """Test that empty lines are ignored."""
    config_text = """[database]

host=localhost

port=5432

"""

    result = parse_config(config_text)

    assert result == {
        "database": {
            "host": "localhost",
            "port": 5432
        }
    }


def test_section_header_with_spaces():
    """Test section headers with spaces."""
    config_text = """[ database ]
host=localhost"""

    result = parse_config(config_text)

    assert "database" in result
    assert result["database"]["host"] == "localhost"


def test_value_with_equals_sign():
    """Test values that contain equals signs."""
    config_text = """[settings]
equation=x=y+z
url=http://example.com?param=value"""

    result = parse_config(config_text)

    assert result["settings"]["equation"] == "x=y+z"
    assert result["settings"]["url"] == "http://example.com?param=value"


def test_mixed_types_in_section():
    """Test section with mixed value types."""
    config_text = """[app]
name=MyApp
version=1.5
port=8080
debug=true
empty_string="""

    result = parse_config(config_text)

    assert result["app"]["name"] == "MyApp"
    assert result["app"]["version"] == 1.5
    assert result["app"]["port"] == 8080
    assert result["app"]["debug"] is True
    assert result["app"]["empty_string"] == ""


def test_duplicate_keys_in_section():
    """Test that duplicate keys overwrite previous values."""
    config_text = """[settings]
key=first
key=second"""

    result = parse_config(config_text)

    assert result["settings"]["key"] == "second"


def test_only_comments():
    """Test file with only comments."""
    config_text = """# Comment 1
; Comment 2
# Comment 3"""

    result = parse_config(config_text)

    assert result == {}


def test_section_without_keys():
    """Test section with no keys."""
    config_text = """[empty_section]

[section_with_data]
key=value"""

    result = parse_config(config_text)

    assert result == {
        "empty_section": {},
        "section_with_data": {"key": "value"}
    }


def test_complex_config():
    """Test complex configuration with multiple features."""
    config_text = """# Application Configuration
app_name=MyApp
version=2.0

[database]
; Database settings
host=localhost
port=5432
enabled=true
max_connections=100

[server]
host=0.0.0.0
port=8080
debug=false
timeout=30.5

[paths]
home=/home/user
temp=/tmp"""

    result = parse_config(config_text)

    assert result["default"]["app_name"] == "MyApp"
    assert result["default"]["version"] == 2.0
    assert result["database"]["host"] == "localhost"
    assert result["database"]["port"] == 5432
    assert result["database"]["enabled"] is True
    assert result["server"]["debug"] is False
    assert result["server"]["timeout"] == 30.5
    assert result["paths"]["home"] == "/home/user"
