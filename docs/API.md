# Ananke API Reference

Complete documentation of all public APIs: CLI, Python, Zig, and HTTP.

---

## Command Line Interface (CLI)

### extract

Extract constraints from code.

```bash
ananke extract <path> [OPTIONS]
```

**Arguments:**
- `<path>`: File or directory to analyze

**Options:**
- `--output, -o`: Output file (default: constraints.json)
- `--language, -l`: Source language (auto-detect if not specified)
- `--detailed`: Include pattern details
- `--use-claude`: Use Claude for semantic analysis
- `--types`: Comma-separated constraint types to extract
- `--include-patterns`: Include code patterns in report

**Examples:**
```bash
ananke extract ./src --output constraints.json
ananke extract auth.py --language python --detailed
ananke extract src/ --types security,type_safety
```

---

### compile

Compile constraints to ConstraintIR.

```bash
ananke compile <constraints> [OPTIONS]
```

**Arguments:**
- `<constraints>`: JSON/YAML/Ariadne constraint file

**Options:**
- `--output, -o`: Output file (default: constraints.cir)
- `--optimize`: Optimize for performance
- `--analyze`: Show dependency analysis
- `--verbose`: Detailed output
- `--report`: Save optimization report

**Examples:**
```bash
ananke compile constraints.json --output compiled.cir
ananke compile constraints.yaml --optimize --analyze
```

---

### generate

Generate code with constraints.

```bash
ananke generate <prompt> [OPTIONS]
```

**Arguments:**
- `<prompt>`: Description of code to generate

**Options:**
- `--constraints, -c`: Compiled constraints file
- `--output, -o`: Output file (default: generated.py)
- `--language, -l`: Target language
- `--max-tokens`: Maximum tokens (default: 2048)
- `--temperature`: Generation temperature (default: 0.7)
- `--model`: Inference model to use
- `--interactive`: Interactive generation mode
- `--strict-mode`: Fail if constraints violated

**Examples:**
```bash
ananke generate "Add validation" --constraints compiled.cir
ananke generate "Create API endpoint" \
  --constraints compiled.cir \
  --language typescript \
  --max-tokens 500
```

---

### validate

Validate code against constraints.

```bash
ananke validate <code> [OPTIONS]
```

**Arguments:**
- `<code>`: File or directory to validate

**Options:**
- `--constraints, -c`: Compiled constraints file
- `--detailed`: Show detailed violations
- `--debug`: Show constraint chain
- `--check`: Specific constraint types to check
- `--output, -o`: Output report file

**Examples:**
```bash
ananke validate generated.py --constraints compiled.cir
ananke validate ./src --constraints compiled.cir --detailed
```

---

### constraints

Constraint management utilities.

```bash
ananke constraints <command> [OPTIONS]
```

**Commands:**

#### show
View constraint contents

```bash
ananke constraints show constraints.json [--pattern] [--type TYPE]
```

#### validate
Check for conflicts

```bash
ananke constraints validate constraints.json [--details] [--use-claude]
```

#### analyze
Show dependency analysis

```bash
ananke constraints analyze constraints.json
```

#### merge
Combine multiple constraint files

```bash
ananke constraints merge file1.json file2.json --output merged.json
```

#### export
Export constraints as documentation

```bash
ananke constraints export constraints.cir \
  --format markdown \
  --output CONSTRAINTS.md
```

---

## Python API

### Clew (Constraint Extraction)

```python
from ananke import Clew

# Initialize
clew = Clew(claude_api_key=None)

# Extract from file
constraints = await clew.extract_from_file("auth.py")

# Extract from directory
constraints = await clew.extract_from_directory("./src")

# Extract from code string
constraints = await clew.extract_from_code(source_code)

# With Claude analysis
constraints = await clew.extract_from_code(
    source_code,
    use_claude=True,
    claude_model="claude-3-sonnet"
)
```

### Braid (Constraint Compilation)

```python
from ananke import Braid

# Initialize
braid = Braid()

# Compile constraints
compiled = await braid.compile(constraints)

# With optimization
compiled = await braid.compile(
    constraints,
    optimize=True,
    analyze=True
)

# Get optimization report
report = compiled.get_optimization_report()
```

### Maze (Code Generation)

```python
from ananke import Maze

# Initialize with Modal endpoint
maze = Maze(
    endpoint="https://yourapp.modal.run",
    model="meta-llama/Meta-Llama-3.1-8B-Instruct"
)

# Generate code
result = await maze.generate(
    prompt="Implement user signup",
    constraints=compiled,
    max_tokens=500,
    temperature=0.7
)

# Access results
print(result.code)
print(result.constraint_violations)
print(result.generation_time_ms)
```

---

## Zig API

### Clew Module

```zig
const ananke = @import("ananke");

// Extract constraints from code
var clew = try ananke.Clew.init(allocator);
defer clew.deinit();

const constraints = try clew.extractFromCode(source_code);

// Work with constraints
for (constraints) |constraint| {
    std.debug.print("Found: {s}\n", .{constraint.name});
}
```

### Braid Module

```zig
// Compile constraints
var braid = try ananke.Braid.init(allocator);
const compiled = try braid.compile(constraints);

// Get dependency graph
const graph = compiled.getDependencyGraph();
```

### Ariadne Module

```zig
// Compile Ariadne DSL
const ariadne_source = @embedFile("constraints.ariadne");
const compiled = try ananke.Ariadne.compile(
    allocator,
    ariadne_source
);
```

---

## HTTP API (Modal Service)

### POST /generate

Generate code with constraints.

**Request:**
```json
{
  "prompt": "Generate a payment validator",
  "constraints": {
    "type": "json",
    "schema": {
      "type": "object",
      "properties": {
        "amount": {"type": "number"},
        "currency": {"type": "string"}
      }
    }
  },
  "max_tokens": 512,
  "temperature": 0.7,
  "metadata": {
    "request_id": "req-001"
  }
}
```

**Response:**
```json
{
  "generated_code": "def validate_payment(amount, currency):\n...",
  "tokens_generated": 287,
  "generation_time_ms": 3200,
  "constraint_violations": 0,
  "confidence": 0.98,
  "provenance": {
    "model": "meta-llama/Meta-Llama-3.1-8B-Instruct",
    "timestamp": "2025-11-23T12:34:56Z"
  }
}
```

---

### POST /validate

Validate code against constraints.

**Request:**
```json
{
  "code": "def validate(x): return isinstance(x, int)",
  "constraints": {...}
}
```

**Response:**
```json
{
  "valid": true,
  "violations": [],
  "confidence": 0.99
}
```

---

## Configuration

### Environment Variables

```bash
# Modal
export MODAL_ENDPOINT="https://yourapp.modal.run"
export MODAL_API_KEY="your-key"

# Claude
export ANTHROPIC_API_KEY="sk_..."

# Inference
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"

# Logging
export ANANKE_LOG_LEVEL="info"
```

### Config File

Create `.ananke/config.yaml`:

```yaml
service:
  endpoint: "https://yourapp.modal.run"
  api_key: "${MODAL_API_KEY}"

model:
  name: "meta-llama/Meta-Llama-3.1-8B-Instruct"
  max_tokens: 2048
  temperature: 0.7

constraints:
  cache_enabled: true
  use_claude: false
```

---

## Error Handling

### Common Errors

#### `ConstraintError`
Constraints are invalid or conflicting.

```python
try:
    compiled = await braid.compile(constraints)
except ananke.ConstraintError as e:
    print(f"Constraint error: {e}")
    # Handle conflict resolution
```

#### `GenerationError`
Code generation failed.

```python
try:
    result = await maze.generate(prompt, constraints)
except ananke.GenerationError as e:
    print(f"Generation failed: {e}")
    # Retry with different parameters
```

#### `ValidationError`
Code doesn't satisfy constraints.

```python
if result.constraint_violations > 0:
    print("Code violates constraints")
    for violation in result.violations:
        print(f"  - {violation.constraint}: {violation.reason}")
```

---

**See User Guide for more examples and patterns.**
