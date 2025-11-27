# Ananke CLI Guide

Complete guide to using the Ananke command-line interface for constraint-driven code generation via Modal inference.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
- [Commands](#commands)
  - [config](#config) - Show configuration
  - [generate](#generate) - Generate code with optional constraints
  - [compile](#compile) - Compile constraints to llguidance format
  - [health](#health) - Check inference service health
  - [cache](#cache) - View or clear constraint compilation cache
- [Common Workflows](#common-workflows)
  - [Basic Code Generation](#basic-code-generation)
  - [Generation with Constraints](#generation-with-constraints)
  - [Cache Management](#cache-management)
  - [Batch Processing](#batch-processing)
  - [CI/CD Integration](#cicd-integration)
- [Constraint Format](#constraint-format)
- [Tips and Best Practices](#tips-and-best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The Ananke CLI provides command-line access to constraint-driven code generation powered by vLLM and llguidance. It allows you to:

- Generate code based on natural language prompts
- Apply constraints (JSON schemas, grammars, regex patterns) to guide generation
- Compile constraints for reuse and validation
- Check inference service health
- Manage constraint compilation cache for performance

The CLI communicates with a Modal inference endpoint to perform actual code generation and constraint compilation.

## Installation

### Python Package

```bash
# From the Ananke project root
cd maze
maturin develop

# Verify installation
ananke --version
```

### Requirements

- Python 3.8+
- Click (for CLI framework)
- Ananke Python bindings (installed via `maturin develop`)
- Modal account and deployment (for inference)

### Help and Version

```bash
# Show version
ananke --version

# Show general help
ananke --help

# Show help for a specific command
ananke <command> --help
```

## Configuration

The Ananke CLI uses environment variables for configuration. No configuration file is needed.

### Environment Variables

Set these variables to configure the CLI:

```bash
# Modal inference endpoint (required)
export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"

# Modal API key (optional, some endpoints may not require it)
export ANANKE_MODAL_API_KEY="your-api-key"

# Model name (optional, defaults to meta-llama/Llama-3.1-8B-Instruct)
export ANANKE_MODEL="meta-llama/Llama-3.1-8B-Instruct"
```

#### ANANKE_MODAL_ENDPOINT

The URL of your Modal inference endpoint. This must be set before using `generate` or `compile` commands.

```bash
export ANANKE_MODAL_ENDPOINT="https://your-org-ananke.modal.run"
```

#### ANANKE_MODAL_API_KEY

Optional API key for authentication with your Modal endpoint. Not always required, depending on endpoint configuration.

```bash
export ANANKE_MODAL_API_KEY="modal_token_abc123"
```

#### ANANKE_MODEL

The LLM model to use for generation. Defaults to `meta-llama/Llama-3.1-8B-Instruct`.

```bash
export ANANKE_MODEL="meta-llama/Llama-3.1-8B-Instruct"
```

### Quick Setup Script

Create a `.env.local` file in your project:

```bash
#!/bin/bash
# .env.local - Source this to set up CLI environment
export ANANKE_MODAL_ENDPOINT="https://your-org-ananke.modal.run"
export ANANKE_MODAL_API_KEY="your-api-key"
export ANANKE_MODEL="meta-llama/Llama-3.1-8B-Instruct"
```

Then source it before running commands:

```bash
source .env.local
ananke config
```

## Commands

### config

Display current Ananke configuration settings.

**Usage:**
```bash
ananke config [OPTIONS]
```

**Options:**
- `--endpoint` - Modal inference endpoint URL (from ANANKE_MODAL_ENDPOINT env var)
- `--api-key` - Modal API key (from ANANKE_MODAL_API_KEY env var)
- `--model` - Model name (from ANANKE_MODEL env var)

**Description:**

Shows the current configuration including the Modal endpoint, selected model, and whether an API key is configured. Useful for verifying your setup is correct.

**Examples:**

```bash
# Show configuration from environment variables
ananke config

# Override endpoint for this command
ananke config --endpoint https://different-endpoint.modal.run
```

**Output:**

```
Ananke Configuration:
  Endpoint: https://your-app.modal.run
  Model:    meta-llama/Llama-3.1-8B-Instruct
  API Key:  (configured)
```

---

### generate

Generate code based on a prompt, with optional constraints.

**Usage:**
```bash
ananke generate <PROMPT> [OPTIONS]
```

**Arguments:**
- `<PROMPT>` - Natural language description of code to generate (required, quoted string)

**Options:**
- `--max-tokens N` - Maximum tokens to generate (default: 2048, range: 1-8192)
- `--temperature F` - Sampling temperature 0.0-2.0 (default: 0.7, higher = more creative)
- `--constraints FILE` - JSON file containing constraints to apply
- `--output, -o FILE` - Save output to file (default: stdout)
- `--endpoint URL` - Modal inference endpoint (overrides ANANKE_MODAL_ENDPOINT)
- `--api-key KEY` - Modal API key (overrides ANANKE_MODAL_API_KEY)
- `--model NAME` - Model name (overrides ANANKE_MODEL)

**Description:**

Generates code using the specified prompt and optional constraints. The generation is performed by the Modal inference service. Output includes the generated code, token count, constraint satisfaction status, and metadata.

**Examples:**

Simple code generation:

```bash
ananke generate "Write a Python function to calculate factorial"
```

With output file:

```bash
ananke generate "Create a TypeScript REST API handler" -o handler.ts
```

With constraints:

```bash
ananke generate "Write a function to parse JSON" \
  --constraints schema.json \
  --max-tokens 1024
```

Custom sampling:

```bash
# Deterministic (low temperature)
ananke generate "Implement binary search in Rust" \
  --temperature 0.2 \
  --max-tokens 2048 \
  -o search.rs

# Creative (high temperature)
ananke generate "Generate creative variable names for a data structure" \
  --temperature 1.5
```

Saving to JSON:

```bash
ananke generate "Write a hello world program" -o output.json
```

If output file ends with `.json`, the full response is saved as JSON:

```json
{
  "generated_text": "...",
  "finish_reason": "length|stop_sequence",
  "tokens_generated": 256,
  "constraint_satisfied": true,
  "model": "meta-llama/Llama-3.1-8B-Instruct",
  "timestamp": "2024-11-26T10:30:45Z"
}
```

If output file has a different extension, only the generated code is saved.

**Output Format:**

By default, output is sent to stdout with a formatted display:

```
================================================================================
Generated Code:
================================================================================
<generated code here>
================================================================================
Tokens: 342 | Finish: length | Constraints: satisfied
```

---

### compile

Compile constraints to llguidance format for reuse and validation.

**Usage:**
```bash
ananke compile <CONSTRAINTS_FILE> [OPTIONS]
```

**Arguments:**
- `<CONSTRAINTS_FILE>` - JSON file containing constraints (required)

**Options:**
- `--output, -o FILE` - Write compiled constraints to file (default: stdout)
- `--endpoint URL` - Modal inference endpoint (overrides ANANKE_MODAL_ENDPOINT)
- `--api-key KEY` - Modal API key (overrides ANANKE_MODAL_API_KEY)
- `--model NAME` - Model name (overrides ANANKE_MODEL)

**Description:**

Compiles constraints from a JSON file to the llguidance format used by the inference engine. Useful for:
- Validating constraint syntax before use
- Caching compiled constraints for faster generation
- Inspecting the compiled output

The compilation hash can be used to identify identical constraint sets.

**Examples:**

Basic compilation:

```bash
ananke compile constraints.json
```

Save compiled constraints:

```bash
ananke compile constraints.json -o compiled.json
```

Verify constraints before use:

```bash
ananke compile my-rules.json
# If successful, no errors are shown
# If there are syntax errors, error message is displayed
```

**Output Format:**

Default (stdout):

```json
{
  "hash": "sha256_hash_of_constraints",
  "compiled_at": "2024-11-26T10:30:45Z",
  "schema_preview": "..."
}
```

---

### health

Check the health status of the Modal inference service.

**Usage:**
```bash
ananke health [OPTIONS]
```

**Options:**
- `--endpoint URL` - Modal inference endpoint (overrides ANANKE_MODAL_ENDPOINT)
- `--api-key KEY` - Modal API key (overrides ANANKE_MODAL_API_KEY)
- `--model NAME` - Model name (overrides ANANKE_MODEL)

**Description:**

Performs a health check against the Modal inference service to verify it is running and accessible. Returns exit code 0 if healthy, 1 if unhealthy.

**Examples:**

Check service health:

```bash
ananke health
```

Output on success:

```
Status: HEALTHY
Endpoint: https://your-app.modal.run
Model: meta-llama/Llama-3.1-8B-Instruct
```

Output on failure:

```
Status: UNHEALTHY
```

Using in scripts:

```bash
if ananke health; then
  echo "Service is ready, starting generation..."
  ananke generate "Create a user model"
else
  echo "Service is down, aborting"
  exit 1
fi
```

---

### cache

View or clear the constraint compilation cache.

**Usage:**
```bash
ananke cache [OPTIONS]
```

**Options:**
- `--clear` - Clear the cache (boolean flag)
- `--endpoint URL` - Modal inference endpoint (overrides ANANKE_MODAL_ENDPOINT)
- `--api-key KEY` - Modal API key (overrides ANANKE_MODAL_API_KEY)
- `--model NAME` - Model name (overrides ANANKE_MODEL)

**Description:**

Shows statistics about the constraint compilation cache, or clears it if `--clear` is specified. The cache stores compiled constraints for faster subsequent compilations.

**Examples:**

View cache statistics:

```bash
ananke cache
```

Output:

```
Cache Statistics:
  Size:  42 entries
  Limit: 1000 entries
  Usage: 4.2%
```

Clear the cache:

```bash
ananke cache --clear
```

Output:

```
Cache cleared successfully
```

When to clear cache:

- After updating constraint definitions
- When cache hits the limit
- When troubleshooting constraint-related issues

---

## Common Workflows

### Basic Code Generation

Generate code with just a prompt:

```bash
# Set up environment
export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"

# Generate simple function
ananke generate "Create a function that reverses a string in Python"

# Save to file
ananke generate "Write a REST API handler" -o handler.py
```

### Generation with Constraints

Define constraints in a JSON file and use them to guide generation:

**constraints.json:**
```json
{
  "name": "api_constraints",
  "json_schema": {
    "type": "object",
    "properties": {
      "method": {"enum": ["GET", "POST", "PUT", "DELETE"]},
      "status_code": {"type": "integer"}
    },
    "required": ["method", "status_code"]
  }
}
```

Generate with constraints:

```bash
ananke generate "Create an API handler" --constraints constraints.json -o api.py
```

Multiple constraints:

```json
[
  {
    "name": "type_safety",
    "json_schema": {"type": "object", "additionalProperties": false}
  },
  {
    "name": "naming_conventions",
    "regex_patterns": ["^[a-z_][a-z0-9_]*$"]
  }
]
```

### Cache Management

For repeated generation with the same constraints:

```bash
# Compile once and cache
ananke compile my-constraints.json -o compiled.json

# Use cached constraints multiple times
ananke generate "Create user handler" --constraints compiled.json
ananke generate "Create product handler" --constraints compiled.json
ananke generate "Create order handler" --constraints compiled.json

# Check cache statistics
ananke cache

# Clear cache if needed
ananke cache --clear
```

### Batch Processing

Generate multiple pieces of code in sequence:

```bash
#!/bin/bash
set -e

export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"

# Create output directory
mkdir -p generated

# Generate multiple related files
ananke generate "Create user model class" -o generated/user.py
ananke generate "Create user repository interface" -o generated/user_repo.py
ananke generate "Create user service" -o generated/user_service.py

echo "Generated files:"
ls -la generated/
```

### CI/CD Integration

Integrate code generation into your CI/CD pipeline:

**.github/workflows/generate.yml:**
```yaml
name: Generate Code

on: [push]

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Ananke
        run: |
          cd maze
          pip install maturin
          maturin develop

      - name: Check service health
        env:
          ANANKE_MODAL_ENDPOINT: ${{ secrets.ANANKE_MODAL_ENDPOINT }}
          ANANKE_MODAL_API_KEY: ${{ secrets.ANANKE_MODAL_API_KEY }}
        run: ananke health

      - name: Generate code
        env:
          ANANKE_MODAL_ENDPOINT: ${{ secrets.ANANKE_MODAL_ENDPOINT }}
          ANANKE_MODAL_API_KEY: ${{ secrets.ANANKE_MODAL_API_KEY }}
        run: |
          ananke generate "Create user handler" -o src/handlers/user.py
          ananke generate "Create product handler" -o src/handlers/product.py

      - name: Commit generated files
        run: |
          git config user.name "Ananke Bot"
          git config user.email "bot@ananke.dev"
          git add src/handlers/
          git commit -m "chore: regenerated code with Ananke" || true
          git push
```

---

## Constraint Format

Constraints guide code generation to ensure output follows specific patterns, schemas, or rules.

### JSON Schema Constraints

Define what the generated output should match:

```json
{
  "name": "json_output",
  "json_schema": {
    "type": "object",
    "properties": {
      "id": {"type": "integer"},
      "name": {"type": "string"},
      "email": {"type": "string", "format": "email"},
      "status": {"enum": ["active", "inactive"]}
    },
    "required": ["id", "name", "email"]
  }
}
```

### Grammar Constraints

Specify BNF-style grammar:

```json
{
  "name": "function_signature",
  "grammar": "def <name>(<params>) -> <return_type>: ..."
}
```

### Regex Pattern Constraints

Match output against regular expressions:

```json
{
  "name": "naming_convention",
  "regex_patterns": [
    "^def [a-z_][a-z0-9_]*.*:",
    "^class [A-Z][a-zA-Z0-9_]*.*:"
  ]
}
```

### Multiple Constraints

Combine different constraint types:

```json
[
  {
    "name": "schema_validation",
    "json_schema": {
      "type": "object",
      "properties": {"method": {"type": "string"}},
      "required": ["method"]
    }
  },
  {
    "name": "naming_patterns",
    "regex_patterns": ["^[a-z_][a-z0-9_]*"]
  }
]
```

---

## Tips and Best Practices

### Generation Quality

**Use specific, detailed prompts:**
```bash
# Good - specific and detailed
ananke generate "Create a Python async function to fetch user data from a REST API with retry logic and timeout handling"

# Less effective - vague
ananke generate "Create a function"
```

**Adjust temperature for task type:**
```bash
# Deterministic tasks (parsing, calculation)
ananke generate "Parse CSV data to JSON" --temperature 0.2

# Creative tasks (naming, design)
ananke generate "Generate creative class names for a game" --temperature 1.2

# Balanced (default for most tasks)
ananke generate "Write a REST API handler" --temperature 0.7
```

**Use appropriate token limits:**
```bash
# Small functions
ananke generate "Write a hash function" --max-tokens 256

# Medium implementations
ananke generate "Implement a data parser" --max-tokens 1024

# Complex modules
ananke generate "Build a caching layer" --max-tokens 4096
```

### Constraint Design

**Start with broad constraints, refine iteratively:**

```bash
# First pass - basic structure
ananke compile constraints.json

# Inspect output, refine constraints.json
# Second pass - refined
ananke compile constraints.json
```

**Validate constraints before heavy use:**

```bash
# Test compilation
ananke compile constraints.json

# Generate a small test
ananke generate "Small test prompt" --constraints constraints.json --max-tokens 100

# Then use for full generation
ananke generate "Full prompt" --constraints constraints.json
```

### Performance Optimization

**Reuse compiled constraints:**

```bash
# Compile once
ananke compile constraints.json -o cached.json

# Reuse many times (faster than recompiling)
for i in {1..10}; do
  ananke generate "Prompt $i" --constraints cached.json
done
```

**Cache frequently used constraint sets:**

```bash
# Keep compiled versions in version control
git add cached_constraints/
git commit -m "Add compiled constraint cache"

# Reuse in CI/CD
ananke generate "Prompt" --constraints cached_constraints/api_rules.json
```

**Monitor cache usage:**

```bash
# Check cache size
ananke cache

# Clear if needed
ananke cache --clear
```

### Service Health Monitoring

**Check health before batch operations:**

```bash
#!/bin/bash
set -e

if ! ananke health; then
  echo "Service unavailable, aborting batch"
  exit 1
fi

# Proceed with generation
for file in prompts/*.txt; do
  ananke generate "$(cat $file)" -o "output/$(basename $file).py"
done
```

---

## Troubleshooting

### Common Issues

**ANANKE_MODAL_ENDPOINT not set**

```
Error: Ananke module not installed or endpoint not configured.
```

Solution: Set the environment variable before running commands:

```bash
export ANANKE_MODAL_ENDPOINT="https://your-app.modal.run"
ananke config  # Verify it's set
ananke generate "Your prompt"
```

**Connection refused**

```
Error: Generation failed: Connection refused
```

Solution: Check your endpoint URL is correct and the service is running:

```bash
ananke health  # Check if service is responsive
```

Verify the endpoint URL:

```bash
ananke config --endpoint https://your-app.modal.run
```

**Constraint compilation fails**

```
Error: Compilation failed: Invalid constraint format
```

Solution: Validate your constraint file format:

```bash
# Check file is valid JSON
jq . constraints.json

# Look for required fields
cat constraints.json | jq 'keys'
```

**Out of memory during generation**

```
Error: Generation failed: Out of memory
```

Solution: Reduce `--max-tokens`:

```bash
# Current (too large)
ananke generate "Prompt" --max-tokens 8192

# Reduced
ananke generate "Prompt" --max-tokens 2048
```

**Timeout during generation**

```
Error: Generation failed: Request timeout
```

Solution: Check service health and try with a shorter prompt:

```bash
ananke health

# Simpler prompt might be faster
ananke generate "Small focused prompt" --max-tokens 1024
```

### Debug Techniques

**Verify configuration:**

```bash
ananke config
# Output should show your endpoint and model
```

**Test with minimal input:**

```bash
# Simplest possible generation
ananke generate "Hello" --max-tokens 10
```

**Check service health:**

```bash
ananke health
# Should show HEALTHY status
```

**Inspect constraint format:**

```bash
# Validate JSON
jq . constraints.json

# Try compilation
ananke compile constraints.json
```

**Enable verbose output (if available):**

```bash
# Some commands support verbose flags
ananke generate "Prompt" -v
```

### Getting Help

- **Command help**: `ananke <command> --help`
- **General help**: `ananke --help`
- **Version**: `ananke --version`
- **Service status**: `ananke health`
