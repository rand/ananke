#!/usr/bin/env python3
"""Tests for the generated validate_command.py CLI tool.

These tests verify that the generated CLI command has:
- Proper argument parsing
- Comprehensive error handling
- Correct exit codes
- Helpful error messages
- Working validation logic
"""

import json
import sys
import tempfile
from pathlib import Path

import pytest
from click.testing import CliRunner

# Add parent directory to path to import generated command
sys.path.insert(0, str(Path(__file__).parent.parent / "output"))

try:
    from validate_command import validate_json
except ImportError:
    pytest.skip("Generated command not available yet - run ./run.sh first", allow_module_level=True)


@pytest.fixture
def runner():
    """Provide a Click CLI test runner."""
    return CliRunner()


@pytest.fixture
def temp_dir(tmp_path):
    """Provide a temporary directory for test files."""
    return tmp_path


@pytest.fixture
def valid_json_file(temp_dir):
    """Create a valid JSON file for testing."""
    json_file = temp_dir / "valid.json"
    data = {
        "name": "John Doe",
        "age": 30,
        "email": "john@example.com"
    }
    json_file.write_text(json.dumps(data, indent=2))
    return json_file


@pytest.fixture
def simple_schema_file(temp_dir):
    """Create a simple JSON Schema file for testing."""
    schema_file = temp_dir / "schema.json"
    schema = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "number"},
            "email": {"type": "string"}
        },
        "required": ["name", "age"]
    }
    schema_file.write_text(json.dumps(schema, indent=2))
    return schema_file


@pytest.fixture
def invalid_json_file(temp_dir):
    """Create an invalid JSON file for testing validation failures."""
    json_file = temp_dir / "invalid.json"
    data = {
        "name": "John Doe",
        "age": "not a number",  # Should be a number
        "email": "john@example.com"
    }
    json_file.write_text(json.dumps(data, indent=2))
    return json_file


@pytest.fixture
def malformed_json_file(temp_dir):
    """Create a malformed JSON file for testing parse errors."""
    json_file = temp_dir / "malformed.json"
    json_file.write_text('{"name": "John", invalid json}')
    return json_file


class TestBasicFunctionality:
    """Test basic CLI functionality."""

    def test_help_option(self, runner):
        """Test that --help works and shows usage information."""
        result = runner.invoke(validate_json, ["--help"])

        assert result.exit_code == 0
        assert "Validate JSON files against a JSON Schema" in result.output
        assert "Examples:" in result.output
        assert "--schema" in result.output
        assert "--strict" in result.output
        assert "--verbose" in result.output

    def test_valid_json_validation(self, runner, valid_json_file, simple_schema_file):
        """Test validating a valid JSON file against a schema."""
        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 0
        assert "is valid" in result.output

    def test_short_option_syntax(self, runner, valid_json_file, simple_schema_file):
        """Test that short option -s works for --schema."""
        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "-s", str(simple_schema_file)]
        )

        assert result.exit_code == 0
        assert "is valid" in result.output


class TestValidationFailures:
    """Test validation failure cases."""

    def test_invalid_json_validation(self, runner, invalid_json_file, simple_schema_file):
        """Test validating an invalid JSON file."""
        result = runner.invoke(
            validate_json,
            [str(invalid_json_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 1
        assert "Validation failed" in result.output

    def test_strict_mode_shows_path(self, runner, invalid_json_file, simple_schema_file):
        """Test that --strict mode shows error paths."""
        result = runner.invoke(
            validate_json,
            [str(invalid_json_file), "--schema", str(simple_schema_file), "--strict"]
        )

        assert result.exit_code == 1
        assert "Validation failed" in result.output
        # Strict mode should show more details (exact format depends on implementation)


class TestErrorHandling:
    """Test error handling for various error conditions."""

    def test_missing_json_file(self, runner, simple_schema_file, temp_dir):
        """Test error when JSON file doesn't exist."""
        missing_file = temp_dir / "missing.json"

        result = runner.invoke(
            validate_json,
            [str(missing_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 2
        assert "not found" in result.output.lower() or "error" in result.output.lower()

    def test_missing_schema_file(self, runner, valid_json_file, temp_dir):
        """Test error when schema file doesn't exist."""
        missing_schema = temp_dir / "missing_schema.json"

        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "--schema", str(missing_schema)]
        )

        assert result.exit_code == 2
        assert "not found" in result.output.lower() or "error" in result.output.lower()

    def test_malformed_json_file(self, runner, malformed_json_file, simple_schema_file):
        """Test error when JSON file is malformed."""
        result = runner.invoke(
            validate_json,
            [str(malformed_json_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 2
        assert "invalid json" in result.output.lower() or "error" in result.output.lower()

    def test_malformed_schema_file(self, runner, valid_json_file, temp_dir):
        """Test error when schema file is malformed."""
        malformed_schema = temp_dir / "malformed_schema.json"
        malformed_schema.write_text('{"type": invalid}')

        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "--schema", str(malformed_schema)]
        )

        assert result.exit_code == 2

    def test_missing_required_schema_option(self, runner, valid_json_file):
        """Test error when --schema option is missing."""
        result = runner.invoke(validate_json, [str(valid_json_file)])

        assert result.exit_code != 0
        # Click should show error about missing required option


class TestVerboseMode:
    """Test verbose output mode."""

    def test_verbose_flag(self, runner, valid_json_file, simple_schema_file):
        """Test that -v/--verbose enables verbose output."""
        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "--schema", str(simple_schema_file), "--verbose"]
        )

        assert result.exit_code == 0
        # Verbose mode should show more output (exact format depends on implementation)

    def test_verbose_short_flag(self, runner, valid_json_file, simple_schema_file):
        """Test that -v works as shorthand for --verbose."""
        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "-s", str(simple_schema_file), "-v"]
        )

        assert result.exit_code == 0


class TestOutputFile:
    """Test output file generation."""

    def test_output_report_success(self, runner, valid_json_file, simple_schema_file, temp_dir):
        """Test generating output report for successful validation."""
        output_file = temp_dir / "report.json"

        result = runner.invoke(
            validate_json,
            [
                str(valid_json_file),
                "--schema", str(simple_schema_file),
                "--output", str(output_file)
            ]
        )

        assert result.exit_code == 0
        assert output_file.exists()

        # Verify report content
        report = json.loads(output_file.read_text())
        assert report["status"] == "valid"
        assert "file" in report
        assert "schema" in report

    def test_output_report_failure(self, runner, invalid_json_file, simple_schema_file, temp_dir):
        """Test generating output report for validation failure."""
        output_file = temp_dir / "report.json"

        result = runner.invoke(
            validate_json,
            [
                str(invalid_json_file),
                "--schema", str(simple_schema_file),
                "--output", str(output_file)
            ]
        )

        assert result.exit_code == 1
        assert output_file.exists()

        # Verify report content
        report = json.loads(output_file.read_text())
        assert report["status"] == "invalid"
        assert "error" in report

    def test_output_short_flag(self, runner, valid_json_file, simple_schema_file, temp_dir):
        """Test that -o works as shorthand for --output."""
        output_file = temp_dir / "report.json"

        result = runner.invoke(
            validate_json,
            [
                str(valid_json_file),
                "-s", str(simple_schema_file),
                "-o", str(output_file)
            ]
        )

        assert result.exit_code == 0
        assert output_file.exists()


class TestComplexSchemas:
    """Test validation with more complex schemas."""

    def test_nested_object_validation(self, runner, temp_dir):
        """Test validation of nested objects."""
        # Create schema with nested structure
        schema = {
            "type": "object",
            "properties": {
                "user": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "age": {"type": "number"}
                    },
                    "required": ["name"]
                }
            },
            "required": ["user"]
        }
        schema_file = temp_dir / "nested_schema.json"
        schema_file.write_text(json.dumps(schema))

        # Valid nested data
        valid_data = {
            "user": {
                "name": "John",
                "age": 30
            }
        }
        valid_file = temp_dir / "nested_valid.json"
        valid_file.write_text(json.dumps(valid_data))

        result = runner.invoke(
            validate_json,
            [str(valid_file), "--schema", str(schema_file)]
        )

        assert result.exit_code == 0

    def test_array_validation(self, runner, temp_dir):
        """Test validation of arrays."""
        schema = {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "number"},
                    "name": {"type": "string"}
                },
                "required": ["id"]
            }
        }
        schema_file = temp_dir / "array_schema.json"
        schema_file.write_text(json.dumps(schema))

        valid_data = [
            {"id": 1, "name": "Item 1"},
            {"id": 2, "name": "Item 2"}
        ]
        valid_file = temp_dir / "array_valid.json"
        valid_file.write_text(json.dumps(valid_data))

        result = runner.invoke(
            validate_json,
            [str(valid_file), "--schema", str(schema_file)]
        )

        assert result.exit_code == 0


class TestExitCodes:
    """Test that exit codes are correct for different scenarios."""

    def test_success_exit_code(self, runner, valid_json_file, simple_schema_file):
        """Test exit code 0 for successful validation."""
        result = runner.invoke(
            validate_json,
            [str(valid_json_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 0

    def test_validation_failure_exit_code(self, runner, invalid_json_file, simple_schema_file):
        """Test exit code 1 for validation failures."""
        result = runner.invoke(
            validate_json,
            [str(invalid_json_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 1

    def test_runtime_error_exit_code(self, runner, temp_dir, simple_schema_file):
        """Test exit code 2 for runtime errors."""
        missing_file = temp_dir / "missing.json"

        result = runner.invoke(
            validate_json,
            [str(missing_file), "--schema", str(simple_schema_file)]
        )

        assert result.exit_code == 2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
