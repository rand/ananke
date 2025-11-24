# Ananke CLI Guide

Complete guide to using the Ananke command-line interface for constraint-driven code generation.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Commands](#commands)
  - [extract](#extract)
  - [compile](#compile)
  - [generate](#generate)
  - [validate](#validate)
  - [init](#init)
  - [version](#version)
  - [help](#help)
- [Workflows](#workflows)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/your-org/ananke.git
cd ananke

# Build and install
zig build install

# Verify installation
ananke --version
```

The binary will be installed to `zig-out/bin/ananke`. Add this to your PATH:

```bash
export PATH="$PWD/zig-out/bin:$PATH"
```

### Requirements

- Zig 0.15.1 or later
- Modal account (for code generation features)
- Rust 1.70+ (for Maze orchestrator)

## Quick Start

1. **Initialize configuration**:
   ```bash
   ananke init
   ```

2. **Extract constraints from code**:
   ```bash
   ananke extract src/main.ts --format pretty
   ```

3. **Save constraints to file**:
   ```bash
   ananke extract src/main.ts --format json -o constraints.json
   ```

4. **Compile constraints to IR**:
   ```bash
   ananke compile constraints.json -o compiled.cir
   ```

5. **Validate code**:
   ```bash
   ananke validate src/main.ts -c constraints.json
   ```

## Configuration

Ananke uses `.ananke.toml` for configuration. Create it with:

```bash
ananke init
```

### Configuration File Format

```toml
# .ananke.toml

[modal]
# Modal inference endpoint (required for generation)
endpoint = "https://your-app.modal.run"
# API key (preferably set via environment variable)
# api_key = "your-key-here"

[defaults]
# Default source language
language = "typescript"

# Generation parameters
max_tokens = 4096
temperature = 0.7

# Extraction parameters
confidence_threshold = 0.5

# Output format: json, yaml, pretty, ariadne
output_format = "pretty"

[extract]
# Enable Claude API for semantic analysis
use_claude = false

# Pattern groups to extract
patterns = ["all"]

[compile]
# Constraint priority: low, medium, high, critical
priority = "medium"

# Output formats for compilation
formats = ["json-schema"]
```

### Environment Variables

Override configuration with environment variables:

```bash
export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"
export ANANKE_MODAL_API_KEY="your-api-key"
export ANANKE_LANGUAGE="python"
```

## Commands

### extract

Extract constraints from source code using pattern matching and optional LLM analysis.

**Usage:**
```bash
ananke extract <file> [options]
```

**Arguments:**
- `<file>` - Source file to extract constraints from

**Options:**
- `--language <lang>` - Source language (auto-detected if not specified)
- `--format <fmt>` - Output format: json, yaml, pretty, ariadne (default: pretty)
- `--output, -o <file>` - Write output to file instead of stdout
- `--confidence <min>` - Minimum confidence threshold 0.0-1.0 (default: 0.5)
- `--use-claude` - Enable Claude API for semantic analysis
- `--verbose, -v` - Verbose output
- `--help, -h` - Show help message

**Examples:**

Extract with pretty output:
```bash
ananke extract src/main.ts
```

Extract to JSON file:
```bash
ananke extract src/auth.py --format json -o constraints.json
```

Extract with confidence filtering:
```bash
ananke extract lib.rs --confidence 0.7 --format pretty
```

Extract using Claude analysis:
```bash
ananke extract src/complex.ts --use-claude --format ariadne
```

**Supported Languages:**
- TypeScript/JavaScript (.ts, .tsx, .js, .jsx)
- Python (.py)
- Rust (.rs)
- Go (.go)
- Zig (.zig)
- Java (.java)
- C/C++ (.c, .cpp, .cc)

### compile

Compile constraints to intermediate representation (IR) for use with llguidance.

**Usage:**
```bash
ananke compile <constraints-file> [options]
```

**Arguments:**
- `<constraints-file>` - JSON/YAML file containing constraints

**Options:**
- `--format <fmt>` - Output format: json, yaml (default: json)
- `--output, -o <file>` - Write compiled IR to file
- `--priority <level>` - Priority: low, medium, high, critical (default: medium)
- `--verbose, -v` - Verbose output
- `--help, -h` - Show help message

**Examples:**

Compile constraints:
```bash
ananke compile constraints.json
```

Compile with high priority:
```bash
ananke compile rules.yaml --priority high -o compiled.cir
```

Verbose compilation:
```bash
ananke compile constraints.json --verbose --format json
```

**Constraint File Format:**

```json
{
  "name": "my_constraints",
  "constraints": [
    {
      "kind": "type_safety",
      "severity": "error",
      "name": "avoid_any_type",
      "description": "Avoid using 'any' type in TypeScript",
      "confidence": 0.95
    },
    {
      "kind": "security",
      "severity": "warning",
      "name": "validate_input",
      "description": "Always validate user input",
      "confidence": 0.85
    }
  ]
}
```

### generate

Generate code with constraints using Modal inference service.

**Usage:**
```bash
ananke generate <prompt> [options]
```

**Arguments:**
- `<prompt>` - Natural language prompt describing what to generate

**Options:**
- `--constraints, -c <file>` - Load constraints from file
- `--language <lang>` - Target language (default: from config)
- `--output, -o <file>` - Write generated code to file
- `--max-tokens <n>` - Maximum tokens to generate (default: 4096)
- `--temperature <f>` - Sampling temperature 0.0-1.0 (default: 0.7)
- `--verbose, -v` - Verbose output
- `--help, -h` - Show help message

**Examples:**

Generate with constraints:
```bash
ananke generate "create authentication handler" -c rules.json -o auth.ts
```

Generate in specific language:
```bash
ananke generate "implement binary search" --language rust -o search.rs
```

Custom generation parameters:
```bash
ananke generate "build REST API client" \
  --language python \
  --max-tokens 2048 \
  --temperature 0.5 \
  -c api_constraints.json
```

**Note:** This command requires Maze inference service deployed on Modal. See deployment guide for setup.

### validate

Validate code against a set of constraints.

**Usage:**
```bash
ananke validate <code-file> [options]
```

**Arguments:**
- `<code-file>` - Source code file to validate

**Options:**
- `--constraints, -c <file>` - Validate against constraints from file
- `--strict` - Treat warnings as errors
- `--report <file>` - Write validation report to file
- `--verbose, -v` - Verbose output
- `--help, -h` - Show help message

**Examples:**

Validate against constraints:
```bash
ananke validate src/auth.ts -c constraints.json
```

Strict validation:
```bash
ananke validate lib.rs --strict -c rules.json
```

Generate report:
```bash
ananke validate src/api.py -c constraints.json --report validation.txt
```

Auto-extract constraints:
```bash
# If no constraints file provided, extracts from code itself
ananke validate src/main.ts --verbose
```

**Exit Codes:**
- `0` - Validation passed
- `1` - User error (missing arguments, etc.)
- `5` - Validation failed (constraint violations found)

### init

Initialize `.ananke.toml` configuration file.

**Usage:**
```bash
ananke init [options]
```

**Options:**
- `--config <file>` - Configuration file path (default: .ananke.toml)
- `--modal-endpoint <url>` - Set Modal inference endpoint
- `--force` - Overwrite existing configuration file
- `--help, -h` - Show help message

**Examples:**

Create default config:
```bash
ananke init
```

Custom config location:
```bash
ananke init --config my-config.toml
```

Initialize with Modal endpoint:
```bash
ananke init --modal-endpoint https://my-app.modal.run
```

Force overwrite:
```bash
ananke init --force
```

### version

Show version information.

**Usage:**
```bash
ananke version [options]
```

**Options:**
- `--verbose, -v` - Show detailed version information
- `--help, -h` - Show help message

**Examples:**

Basic version:
```bash
ananke version
```

Detailed version:
```bash
ananke version --verbose
```

### help

Show help for commands.

**Usage:**
```bash
ananke help [command]
```

**Examples:**

General help:
```bash
ananke help
```

Command-specific help:
```bash
ananke help extract
ananke help compile
ananke help validate
```

## Workflows

### Basic Extract-Compile-Validate Workflow

```bash
# 1. Extract constraints
ananke extract src/main.ts --format json -o constraints.json

# 2. Compile to IR
ananke compile constraints.json -o compiled.cir

# 3. Validate code
ananke validate src/main.ts -c constraints.json
```

### Constraint-Driven Development

```bash
# 1. Extract constraints from existing high-quality code
ananke extract reference/best_practices.ts --confidence 0.8 -o rules.json

# 2. Use constraints to validate new code
ananke validate new_feature/handler.ts -c rules.json --strict

# 3. Generate code following extracted patterns
ananke generate "create similar handler for users" \
  -c rules.json \
  --language typescript \
  -o new_feature/user_handler.ts
```

### Multi-Language Project

```bash
# Extract constraints from multiple languages
ananke extract backend/api.py --format json -o python_rules.json
ananke extract frontend/app.ts --format json -o ts_rules.json

# Compile separately
ananke compile python_rules.json -o python.cir
ananke compile ts_rules.json -o typescript.cir

# Validate each part
ananke validate backend/**/*.py -c python_rules.json
ananke validate frontend/**/*.ts -c ts_rules.json
```

### CI/CD Integration

```bash
#!/bin/bash
# .github/workflows/validate.sh

set -e

echo "Extracting constraints from main branch..."
ananke extract src/main.ts --format json -o constraints.json

echo "Validating new code..."
for file in $(git diff --name-only main...HEAD | grep '\.ts$'); do
  echo "Validating $file..."
  ananke validate "$file" -c constraints.json --strict || exit 1
done

echo "All files validated successfully!"
```

## Advanced Usage

### Custom Output Formats

**JSON** - Machine-readable format for tools:
```bash
ananke extract src/main.ts --format json | jq '.constraints[] | select(.severity=="error")'
```

**YAML** - Human-readable format:
```bash
ananke extract src/main.ts --format yaml > constraints.yaml
```

**Pretty** - Colored terminal output:
```bash
ananke extract src/main.ts --format pretty | less -R
```

**Ariadne** - DSL format for constraint composition:
```bash
ananke extract src/main.ts --format ariadne > constraints.ar
```

### Piping and Chaining

Extract and compile in one command:
```bash
ananke extract src/main.ts --format json | \
ananke compile /dev/stdin -o compiled.cir
```

Filter constraints by confidence:
```bash
ananke extract src/main.ts --format json | \
jq '.constraints[] | select(.confidence > 0.8)' | \
ananke compile /dev/stdin
```

### Batch Processing

Process multiple files:
```bash
for file in src/**/*.ts; do
  echo "Processing $file..."
  ananke extract "$file" --format json >> all_constraints.json
done
```

Validate entire directory:
```bash
find src -name '*.ts' -exec ananke validate {} -c constraints.json \;
```

### Using with Git Hooks

Pre-commit hook (`.git/hooks/pre-commit`):
```bash
#!/bin/bash

# Extract constraints from main.ts
ananke extract src/main.ts --format json -o /tmp/constraints.json

# Validate staged TypeScript files
for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.ts$'); do
  if ! ananke validate "$file" -c /tmp/constraints.json --strict; then
    echo "Validation failed for $file"
    exit 1
  fi
done
```

## Troubleshooting

### Common Issues

**1. "File not found" error**

Make sure the file path is correct and the file exists:
```bash
ls -la src/main.ts
ananke extract src/main.ts
```

**2. "Permission denied" error**

Check file permissions:
```bash
chmod +r src/main.ts
```

**3. "Invalid format" error**

Use one of the supported formats:
```bash
ananke extract src/main.ts --format json  # ✓ Valid
ananke extract src/main.ts --format xml   # ✗ Invalid
```

**4. "Modal endpoint not configured" error**

Set the Modal endpoint:
```bash
export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"
# or
ananke init --modal-endpoint https://your-app.modal.run
```

**5. "Validation failed" with no details**

Use verbose mode to see details:
```bash
ananke validate src/main.ts -c constraints.json --verbose
```

### Debug Mode

Enable verbose output for all commands:
```bash
ananke extract src/main.ts --verbose
ananke compile constraints.json --verbose
ananke validate src/main.ts -c constraints.json --verbose
```

### Getting Help

- Run `ananke help <command>` for command-specific help
- Check GitHub issues: https://github.com/your-org/ananke/issues
- Read the docs: https://ananke.dev/docs

### Performance Tips

1. **Use confidence filtering** to reduce constraint count:
   ```bash
   ananke extract src/main.ts --confidence 0.7
   ```

2. **Cache compiled IR** instead of recompiling:
   ```bash
   # Compile once
   ananke compile constraints.json -o cached.cir

   # Reuse for multiple validations
   ananke validate file1.ts -c cached.cir
   ananke validate file2.ts -c cached.cir
   ```

3. **Process files in parallel**:
   ```bash
   find src -name '*.ts' | parallel ananke extract {} --format json
   ```

## Exit Codes

- `0` - Success
- `1` - User error (invalid arguments, missing files)
- `2` - System error (unexpected error)
- `3` - File not found
- `4` - Permission denied
- `5` - Validation failed

## Output Format Reference

### JSON Schema

```json
{
  "name": "string",
  "constraints": [
    {
      "id": "number",
      "kind": "syntactic|type_safety|semantic|architectural|operational|security",
      "severity": "error|warning|info|hint",
      "name": "string",
      "description": "string",
      "source": "string",
      "priority": "Low|Medium|High|Critical",
      "confidence": "number (0.0-1.0)",
      "frequency": "number"
    }
  ]
}
```

### YAML Format

```yaml
name: constraint_set_name
constraints:
  - id: 1
    kind: type_safety
    severity: error
    name: avoid_any_type
    description: Avoid using 'any' type
    confidence: 0.95
```

### Ariadne DSL

```ariadne
constraint_set "my_constraints" {
  type_safety error "avoid_any_type" {
    description: "Avoid using 'any' type in TypeScript"
    confidence: 0.95
    priority: High
  }

  security warning "validate_input" {
    description: "Always validate user input"
    confidence: 0.85
    priority: High
  }
}
```

## Further Reading

- [Architecture Guide](ARCHITECTURE.md)
- [API Documentation](API.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Contributing Guide](CONTRIBUTING.md)
