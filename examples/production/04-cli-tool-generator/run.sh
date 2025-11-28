#!/usr/bin/env bash
#
# CLI Tool Generator - Complete Pipeline
#
# This script demonstrates the full workflow of generating a robust CLI tool:
# 1. Extract patterns from existing CLI code
# 2. Convert specification to constraints
# 3. Merge constraints and generate new CLI command
# 4. Validate generated code
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Directories
INPUT_DIR="$SCRIPT_DIR/input"
CONSTRAINTS_DIR="$SCRIPT_DIR/constraints"
OUTPUT_DIR="$SCRIPT_DIR/output"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Files
EXISTING_CLI="$INPUT_DIR/existing_cli.py"
CLI_SPEC="$INPUT_DIR/cli_spec.yaml"
EXTRACTED_CONSTRAINTS="$CONSTRAINTS_DIR/extracted_patterns.json"
SPEC_CONSTRAINTS="$CONSTRAINTS_DIR/spec_constraints.json"
MERGED_CONSTRAINTS="$CONSTRAINTS_DIR/merged_constraints.json"
GENERATED_CLI="$OUTPUT_DIR/validate_command.py"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Print banner
echo ""
echo "========================================"
echo "  CLI Tool Generator Pipeline"
echo "========================================"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! check_command python3; then
    log_error "Python 3 is required but not installed"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
log_info "Python version: $PYTHON_VERSION"

# Create output directories
mkdir -p "$CONSTRAINTS_DIR" "$OUTPUT_DIR"

# ============================================================================
# Phase 1: Extract Patterns from Existing CLI
# ============================================================================
echo ""
log_info "Phase 1: Extracting patterns from existing CLI code..."

if [ ! -f "$EXISTING_CLI" ]; then
    log_error "Existing CLI file not found: $EXISTING_CLI"
    exit 1
fi

# For this example, we simulate extraction by creating a constraint file
# In a real scenario, this would use: ananke extract input/existing_cli.py
cat > "$EXTRACTED_CONSTRAINTS" << 'EOF'
{
  "version": "1.0",
  "type": "cli_patterns",
  "metadata": {
    "source": "existing_cli.py",
    "extracted_at": "2024-01-01T00:00:00Z"
  },
  "patterns": [
    {
      "type": "import_pattern",
      "imports": [
        "import click",
        "import json",
        "import sys",
        "from pathlib import Path",
        "from typing import Optional"
      ]
    },
    {
      "type": "error_handling_pattern",
      "pattern": "click.echo with style",
      "example": "click.echo(click.style('Error:', fg='red', bold=True) + message, err=True)"
    },
    {
      "type": "exit_code_pattern",
      "codes": {
        "success": 0,
        "validation_failure": 1,
        "runtime_error": 2
      }
    },
    {
      "type": "file_validation_pattern",
      "uses_pathlib": true,
      "checks_exists": true,
      "checks_is_file": true
    },
    {
      "type": "help_text_pattern",
      "includes_examples": true,
      "includes_exit_codes": true,
      "docstring_format": "google"
    },
    {
      "type": "output_pattern",
      "uses_click_echo": true,
      "colors_enabled": true,
      "stderr_for_errors": true
    }
  ]
}
EOF

log_success "Pattern extraction complete: $EXTRACTED_CONSTRAINTS"

# ============================================================================
# Phase 2: Convert Specification to Constraints
# ============================================================================
echo ""
log_info "Phase 2: Converting CLI specification to constraints..."

if [ ! -f "$CLI_SPEC" ]; then
    log_error "CLI specification not found: $CLI_SPEC"
    exit 1
fi

# Check if conversion script exists
if [ ! -f "$SCRIPTS_DIR/cli_spec_to_constraints.py" ]; then
    log_error "Conversion script not found: $SCRIPTS_DIR/cli_spec_to_constraints.py"
    exit 1
fi

# Check for PyYAML
if ! python3 -c "import yaml" 2>/dev/null; then
    log_warning "PyYAML not found. Creating spec constraints manually..."

    # Create spec constraints manually without PyYAML
    cat > "$SPEC_CONSTRAINTS" << 'SPEC_EOF'
{
  "version": "1.0",
  "type": "cli_command",
  "metadata": {
    "command_name": "validate",
    "function_name": "validate_json",
    "description": "Validate JSON files against a JSON Schema",
    "help_text": "Validate JSON files against a JSON Schema.",
    "dependencies": ["click", "jsonschema"]
  },
  "constraints": [
    {
      "type": "click_command",
      "name": "validate",
      "function_name": "validate_json",
      "description": "Validate JSON files against a JSON Schema"
    },
    {
      "type": "click_argument",
      "name": "json_file",
      "click_type": "click.Path",
      "required": true,
      "help": "Path to JSON file to validate",
      "path_exists": true
    },
    {
      "type": "click_option",
      "name": "schema",
      "short": "s",
      "click_type": "click.Path",
      "required": true,
      "help": "Path to JSON Schema file",
      "path_exists": true
    },
    {
      "type": "click_option",
      "name": "strict",
      "click_type": "bool",
      "required": false,
      "default": false,
      "is_flag": true,
      "help": "Enable strict validation mode (shows detailed error paths)"
    },
    {
      "type": "click_option",
      "name": "verbose",
      "short": "v",
      "click_type": "bool",
      "required": false,
      "default": false,
      "is_flag": true,
      "help": "Enable verbose output"
    },
    {
      "type": "click_option",
      "name": "output",
      "short": "o",
      "click_type": "click.Path",
      "required": false,
      "help": "Output validation report to file (optional)"
    }
  ]
}
SPEC_EOF
else
    # Run conversion with PyYAML
    python3 "$SCRIPTS_DIR/cli_spec_to_constraints.py" \
        "$CLI_SPEC" \
        -o "$SPEC_CONSTRAINTS" \
        --pretty
fi

log_success "Specification conversion complete: $SPEC_CONSTRAINTS"

# ============================================================================
# Phase 3: Merge Constraints and Generate CLI Command
# ============================================================================
echo ""
log_info "Phase 3: Merging constraints and generating CLI command..."

# Merge constraints (simple merge for demonstration)
# In real scenario, this would be done by Ananke
python3 << EOF
import json

# Load constraints
with open("$EXTRACTED_CONSTRAINTS") as f:
    extracted = json.load(f)

with open("$SPEC_CONSTRAINTS") as f:
    spec = json.load(f)

# Merge
merged = {
    "version": "1.0",
    "type": "cli_command_generation",
    "patterns": extracted.get("patterns", []),
    "command": spec
}

# Save merged constraints
with open("$MERGED_CONSTRAINTS", "w") as f:
    json.dump(merged, f, indent=2)

print("Merged constraints created")
EOF

log_success "Constraint merging complete: $MERGED_CONSTRAINTS"

# Generate CLI command
# In real scenario: ananke generate --constraints merged_constraints.json -o output/validate_command.py
# For demonstration, we'll create a complete working CLI command
cat > "$GENERATED_CLI" << 'EOF'
#!/usr/bin/env python3
"""Validate JSON files against a JSON Schema.

Generated by Ananke CLI Tool Generator.
"""

import click
import json
import sys
from pathlib import Path
from typing import Optional

try:
    from jsonschema import validate, ValidationError
except ImportError:
    print("Error: jsonschema is required. Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(2)


def validate_file_exists(file_path: str, file_type: str = "File") -> Path:
    """Validate that a file exists and is readable.

    Args:
        file_path: Path to the file to validate
        file_type: Type of file for error messages

    Returns:
        Path object if valid

    Raises:
        SystemExit: If file doesn't exist or isn't readable
    """
    path = Path(file_path)
    if not path.exists():
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" {file_type} not found: {file_path}",
            err=True,
        )
        sys.exit(2)

    if not path.is_file():
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" Not a file: {file_path}",
            err=True,
        )
        sys.exit(2)

    return path


def load_json_file(file_path: Path, file_type: str = "File") -> dict:
    """Load and parse a JSON file.

    Args:
        file_path: Path to the JSON file
        file_type: Type of file for error messages

    Returns:
        Parsed JSON data

    Raises:
        SystemExit: If JSON is malformed
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        click.echo(
            click.style("Error:", fg="red", bold=True)
            + f" Invalid JSON in {file_path}: {e.msg} at line {e.lineno}, column {e.colno}",
            err=True,
        )
        sys.exit(2)
    except IOError as e:
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" Cannot read {file_path}: {e}",
            err=True,
        )
        sys.exit(2)


@click.command()
@click.argument("json_file", type=click.Path())
@click.option(
    "--schema",
    "-s",
    required=True,
    type=click.Path(),
    help="Path to JSON Schema file",
)
@click.option(
    "--strict",
    is_flag=True,
    help="Enable strict validation mode (shows detailed error paths)",
)
@click.option(
    "--verbose",
    "-v",
    is_flag=True,
    help="Enable verbose output",
)
@click.option(
    "--output",
    "-o",
    type=click.Path(),
    help="Output validation report to file (optional)",
)
def validate_json(
    json_file: str,
    schema: str,
    strict: bool,
    verbose: bool,
    output: Optional[str],
) -> None:
    """Validate JSON files against a JSON Schema.

    This command reads a JSON file and validates it against a provided
    JSON Schema file. Returns exit code 0 for valid files, 1 for validation
    failures, and 2 for runtime errors.

    Examples:

        # Basic validation
        validate data.json --schema schema.json

        # Strict mode with detailed error paths
        validate data.json --schema schema.json --strict

        # Short option syntax
        validate data.json -s schema.json -v

    Exit Codes:

        0 - JSON is valid according to schema
        1 - Validation failed
        2 - Runtime error (file not found, invalid JSON, etc.)
    """
    # Verbose logging
    if verbose:
        click.echo(f"Validating JSON file: {json_file}", err=True)
        click.echo(f"Using schema: {schema}", err=True)
        if strict:
            click.echo("Strict mode: enabled", err=True)

    # Validate files exist
    json_path = validate_file_exists(json_file, "JSON file")
    schema_path = validate_file_exists(schema, "Schema file")

    # Load JSON file
    if verbose:
        click.echo("Loading JSON file...", err=True)

    json_data = load_json_file(json_path, "JSON file")

    # Load schema file
    if verbose:
        click.echo("Loading schema file...", err=True)

    schema_data = load_json_file(schema_path, "Schema file")

    # Perform validation
    if verbose:
        click.echo("Validating...", err=True)

    try:
        validate(instance=json_data, schema=schema_data)

        # Validation successful
        success_msg = click.style("✓", fg="green", bold=True) + f" {json_file} is valid"
        click.echo(success_msg)

        # Write report if requested
        if output:
            report = {
                "status": "valid",
                "file": str(json_file),
                "schema": str(schema),
                "strict_mode": strict,
            }

            try:
                output_path = Path(output)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, "w", encoding="utf-8") as f:
                    json.dump(report, f, indent=2)

                if verbose:
                    click.echo(f"Report written to: {output}", err=True)
            except IOError as e:
                click.echo(
                    click.style("Warning:", fg="yellow", bold=True)
                    + f" Cannot write report to {output}: {e}",
                    err=True,
                )

        sys.exit(0)

    except ValidationError as e:
        # Validation failed
        error_msg = click.style("✗", fg="red", bold=True) + f" Validation failed: {e.message}"
        click.echo(error_msg, err=True)

        if strict and e.path:
            path_str = ".".join(str(p) for p in e.path)
            click.echo(f"  Path: {path_str}", err=True)
            if e.schema_path:
                schema_path_str = ".".join(str(p) for p in e.schema_path)
                click.echo(f"  Schema path: {schema_path_str}", err=True)

        # Write error report if requested
        if output:
            report = {
                "status": "invalid",
                "file": str(json_file),
                "schema": str(schema),
                "error": e.message,
                "path": [str(p) for p in e.path] if e.path else [],
            }

            try:
                output_path = Path(output)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, "w", encoding="utf-8") as f:
                    json.dump(report, f, indent=2)
            except IOError:
                pass  # Silent failure for error case

        sys.exit(1)


if __name__ == "__main__":
    validate_json()
EOF

chmod +x "$GENERATED_CLI"

log_success "CLI command generation complete: $GENERATED_CLI"

# ============================================================================
# Phase 4: Validate Generated Code
# ============================================================================
echo ""
log_info "Phase 4: Validating generated code..."

# Syntax validation
log_info "Checking Python syntax..."
if python3 -m py_compile "$GENERATED_CLI"; then
    log_success "Syntax validation passed"
else
    log_error "Syntax validation failed"
    exit 1
fi

# Check if help works (only if dependencies are installed)
log_info "Testing --help output..."
if python3 -c "import click" 2>/dev/null; then
    if python3 "$GENERATED_CLI" --help > /dev/null 2>&1; then
        log_success "Help generation works"
    else
        log_error "Help generation failed"
        exit 1
    fi
else
    log_warning "Click not installed - skipping runtime validation"
    log_info "Install dependencies with: pip install -r requirements.txt"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================"
echo "  Pipeline Complete!"
echo "========================================"
echo ""
echo "Generated CLI command: $GENERATED_CLI"
echo ""
echo "Try it out:"
echo "  python3 $GENERATED_CLI --help"
echo ""
echo "Example usage:"
echo "  python3 $GENERATED_CLI sample.json --schema schema.json"
echo ""
echo "Run tests:"
echo "  pytest tests/test_validate_command.py -v"
echo ""
