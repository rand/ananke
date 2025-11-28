# Example 04: CLI Tool Generator

## Overview

Demonstrates generating robust CLI tools with Click by extracting patterns from existing commands and applying them to new specifications. Shows how Ananke ensures consistency, proper error handling, and comprehensive help text across CLI tools.

## Value Proposition

**Problem**: Writing CLI tools often results in inconsistent argument parsing, incomplete error handling, and poor help documentation. Each developer implements their own patterns, leading to varying user experiences.

**Solution**: Extract CLI patterns from well-designed existing commands and generate new commands that follow the same conventions. Ananke ensures consistency in:
- Argument and option parsing patterns
- Error handling and validation
- Help text format and examples
- Exit codes and error messages
- Input/output formatting

**ROI**:
- **Time Saved**: Reduces CLI command creation from 2-3 hours to 10 minutes
- **Consistency**: 100% adherence to established patterns
- **Quality**: Comprehensive error handling and validation from day one
- **Documentation**: Complete help text with examples automatically generated

## Prerequisites

- Python 3.11+
- Zig 0.15.1+ (for Ananke CLI)
- **Setup Time**: <5 minutes

## Quick Start

```bash
cd examples/production/04-cli-tool-generator
pip install -r requirements.txt
./run.sh
```

This will generate `output/validate_command.py`, a fully-functional Click command.

## Step-by-Step Guide

### 1. Input Preparation

This example uses two input files:

**`input/existing_cli.py`** - An example Click command showing established patterns:
- Argument/option handling
- Validation logic
- Error handling approach
- Help text structure
- Output formatting

**`input/cli_spec.yaml`** - Specification for the new `validate` command:
```yaml
command:
  name: validate
  description: Validate JSON files against a JSON Schema
  arguments:
    - name: json_file
      type: path
      required: true
      help: Path to JSON file to validate
  options:
    - name: schema
      type: path
      required: true
      help: Path to JSON Schema file
    - name: strict
      type: bool
      default: false
      help: Enable strict validation mode
```

### 2. Constraint Extraction

Extract CLI patterns from the existing command:

```bash
ananke extract input/existing_cli.py \
  --language python \
  -o constraints/extracted_patterns.json
```

**Extracted patterns include**:
- Click decorator usage (`@click.command()`, `@click.argument()`, `@click.option()`)
- Type annotations and validators
- Error handling patterns (try/except, click.echo errors)
- Exit code conventions (0=success, 1=validation failure, 2=error)
- Help text formatting

### 3. Specification Constraint Conversion

Convert the YAML specification to constraint format:

```bash
python scripts/cli_spec_to_constraints.py \
  input/cli_spec.yaml \
  -o constraints/spec_constraints.json
```

**Generated constraints specify**:
- Command name and description
- Required arguments with types
- Optional flags with defaults
- Help text for each parameter
- Validation requirements

### 4. Constraint Merging & Generation

Merge extracted patterns with specification constraints:

```bash
ananke generate \
  --constraints constraints/extracted_patterns.json \
  --constraints constraints/spec_constraints.json \
  --template cli_command \
  --language python \
  -o output/validate_command.py
```

**Result**: A complete Click command with:
- Proper argument parsing
- Input validation (file existence, schema validation)
- Comprehensive error handling
- Helpful error messages
- Complete help documentation
- Correct exit codes

### 5. Validation

Run tests to verify the generated command:

```bash
pytest tests/test_validate_command.py -v
```

Try the generated CLI:

```bash
# Show help
python output/validate_command.py --help

# Validate a JSON file (example)
python output/validate_command.py data.json --schema schema.json
```

## What Gets Generated

The output file `output/validate_command.py` includes:

### 1. Complete CLI Command Structure
```python
import click
import json
import sys
from pathlib import Path
from jsonschema import validate, ValidationError

@click.command()
@click.argument('json_file', type=click.Path(exists=True))
@click.option('--schema', '-s', required=True, type=click.Path(exists=True),
              help='Path to JSON Schema file')
@click.option('--strict/--no-strict', default=False,
              help='Enable strict validation mode')
def validate_json(json_file, schema, strict):
    """Validate JSON files against a JSON Schema.

    Examples:
        validate data.json --schema schema.json
        validate data.json -s schema.json --strict
    """
    # Implementation...
```

### 2. Robust Error Handling
```python
try:
    with open(json_file) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    click.echo(f"Error: Invalid JSON in {json_file}: {e}", err=True)
    sys.exit(2)
except FileNotFoundError:
    click.echo(f"Error: File not found: {json_file}", err=True)
    sys.exit(2)
```

### 3. Comprehensive Validation
```python
try:
    validate(instance=data, schema=schema_data)
    click.echo(f"✓ {json_file} is valid", fg='green')
    sys.exit(0)
except ValidationError as e:
    click.echo(f"✗ Validation failed: {e.message}", err=True, fg='red')
    if strict:
        click.echo(f"  Path: {'.'.join(str(p) for p in e.path)}", err=True)
    sys.exit(1)
```

### 4. Complete Help Documentation
```bash
$ python validate_command.py --help

Usage: validate_command.py [OPTIONS] JSON_FILE

  Validate JSON files against a JSON Schema.

  Examples:
      validate data.json --schema schema.json
      validate data.json -s schema.json --strict

Options:
  -s, --schema PATH       Path to JSON Schema file  [required]
  --strict / --no-strict  Enable strict validation mode
  --help                  Show this message and exit.
```

## CLI Patterns Demonstrated

### 1. Argument vs Option Usage
- **Arguments**: Required positional parameters (e.g., `json_file`)
- **Options**: Named flags with `--` prefix (e.g., `--schema`)
- **Boolean Flags**: `--flag/--no-flag` pattern for toggles

### 2. Type Validation
```python
# Path validation with existence check
@click.argument('file', type=click.Path(exists=True))

# Choice validation
@click.option('--format', type=click.Choice(['json', 'yaml', 'xml']))

# Integer with range
@click.option('--port', type=click.IntRange(1, 65535))
```

### 3. Error Handling Conventions

**Exit Codes**:
- `0` - Success
- `1` - Validation/business logic failure
- `2` - Runtime error (file not found, invalid input, etc.)

**Error Output**:
```python
# Use click.echo with err=True for errors
click.echo(f"Error: {message}", err=True)

# Optional: Add color for better UX
click.echo(click.style("Error:", fg='red') + f" {message}", err=True)
```

### 4. Help Text Best Practices

**Command Help**:
```python
def command():
    """Short description.

    Longer explanation if needed.

    Examples:
        command arg1 --option value
        command arg2 --flag
    """
```

**Option Help**:
```python
@click.option('--verbose', '-v', is_flag=True,
              help='Enable verbose output')
```

### 5. Input Validation Pattern
```python
# Validate early, fail fast
def validate_inputs(file_path, schema_path):
    """Validate inputs before processing."""
    if not Path(file_path).exists():
        click.echo(f"Error: File not found: {file_path}", err=True)
        sys.exit(2)

    if not Path(schema_path).exists():
        click.echo(f"Error: Schema not found: {schema_path}", err=True)
        sys.exit(2)
```

## Customization Guide

### Adding New Commands

1. **Update `cli_spec.yaml`** with your command specification:
```yaml
command:
  name: your_command
  description: What it does
  arguments:
    - name: input
      type: path
      required: true
  options:
    - name: output
      type: path
      help: Output file path
```

2. **Run the generation pipeline**:
```bash
./run.sh
```

3. **Review and test** the generated command:
```bash
pytest tests/test_your_command.py
```

### Modifying Patterns

To change CLI patterns across all generated commands:

1. **Edit `input/existing_cli.py`** with your preferred patterns
2. **Re-run extraction** to capture new patterns
3. **Regenerate commands** to apply changes

Example pattern modifications:
- Change error message format
- Add color to output
- Modify help text structure
- Update validation logic

### Advanced Features

**Progress Bars**:
```python
with click.progressbar(items) as bar:
    for item in bar:
        process(item)
```

**Prompts**:
```python
value = click.prompt('Enter value', type=int)
confirmed = click.confirm('Are you sure?')
```

**File Operations**:
```python
@click.option('--output', type=click.File('w'), default='-')
def command(output):
    output.write("result\n")
```

## Testing Strategy

### 1. Unit Tests
Test individual validation functions:
```python
def test_validate_json_schema():
    assert validate_schema(valid_data, schema) is True
    assert validate_schema(invalid_data, schema) is False
```

### 2. Integration Tests
Test CLI execution:
```python
from click.testing import CliRunner

def test_validate_command():
    runner = CliRunner()
    result = runner.invoke(validate_json, ['data.json', '--schema', 'schema.json'])
    assert result.exit_code == 0
```

### 3. Error Handling Tests
```python
def test_missing_file():
    runner = CliRunner()
    result = runner.invoke(validate_json, ['missing.json', '--schema', 'schema.json'])
    assert result.exit_code == 2
    assert 'File not found' in result.output
```

## Common Patterns

### Environment Variables
```python
@click.option('--api-key', envvar='API_KEY', help='API key (or set API_KEY env var)')
```

### Multiple Values
```python
@click.option('--tag', multiple=True, help='Tags (can be specified multiple times)')
```

### Callbacks for Validation
```python
def validate_port(ctx, param, value):
    if value < 1 or value > 65535:
        raise click.BadParameter('Port must be between 1 and 65535')
    return value

@click.option('--port', callback=validate_port, type=int)
```

## Troubleshooting

### Generated Command Doesn't Run

**Issue**: Import errors or syntax errors

**Solution**:
1. Check Python version: `python --version` (must be 3.11+)
2. Install dependencies: `pip install -r requirements.txt`
3. Validate syntax: `python -m py_compile output/validate_command.py`

### Validation Tests Fail

**Issue**: Generated code doesn't match expected patterns

**Solution**:
1. Check extraction: `cat constraints/extracted_patterns.json`
2. Verify spec: `cat constraints/spec_constraints.json`
3. Re-run generation with `--verbose` flag

### Help Text Incomplete

**Issue**: Missing help documentation

**Solution**:
1. Ensure `cli_spec.yaml` has `help` fields for all options
2. Check existing_cli.py has comprehensive docstrings
3. Review template configuration

## Performance Notes

- **Generation Time**: <5 seconds for typical CLI commands
- **Runtime Overhead**: None - generates pure Python Click code
- **Test Execution**: ~100ms for full test suite

## Related Examples

- **Example 05**: Test Generator - Generate test suites for CLI commands
- **Example 01**: OpenAPI Generator - Similar pattern extraction for API routes

## License

MIT License - see LICENSE file in repository root.
