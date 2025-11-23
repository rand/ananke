# Ananke User Guide

> Transform AI code generation from probabilistic guessing into controlled search through valid program spaces.

**Status**: Production-ready  
**Version**: 0.1.0  
**Last Updated**: November 2025

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Concepts](#core-concepts)
3. [Installation](#installation)
4. [Usage Patterns](#usage-patterns)
5. [Constraint Sources](#constraint-sources)
6. [Configuration](#configuration)
7. [Common Tasks](#common-tasks)
8. [Troubleshooting](#troubleshooting)

---

## Getting Started

### What is Ananke?

Ananke is a constraint-driven code generation system that ensures AI-generated code always satisfies your specifications. Instead of hoping language models follow your patterns, you define explicit constraints and Ananke enforces them **at the token level** during generation.

**Key insight**: Generated code that doesn't satisfy constraints simply cannot be produced.

### Quick Start (60 seconds)

**Prerequisites**: Python 3.8+, a Modal account (free tier), and 5 minutes

```bash
# 1. Install Ananke
pip install ananke-ai

# 2. Authenticate with Modal (one-time setup)
modal token new

# 3. Set HuggingFace token for model access
modal secret create huggingface-secret HUGGING_FACE_HUB_TOKEN=hf_...

# 4. Deploy inference service
ananke service deploy --model llama-3.1-8b

# 5. Extract constraints from your code
ananke extract ./src --output constraints.json

# 6. Generate code with constraints
ananke generate "Add pagination to user list endpoint" \
  --constraints constraints.json \
  --max-tokens 500

# Done! Check output.py for the generated code
```

---

## Core Concepts

### Constraint-Driven Generation

Traditional code generation looks like this:

```
User Intent → Language Model → Probabilistic Output (might violate your rules)
```

Ananke enforces constraints:

```
User Intent + Constraints → Analysis Layer → Compilation Layer → Constrained Generation Layer
                                   ↓               ↓                        ↓
                             Extract what      Compile for              Token-level
                             your code         validation               enforcement
                             already does      
```

### Constraint Types

Ananke extracts and applies constraints in six categories:

#### 1. **Syntactic Constraints** (Code Structure)
Enforce formatting, naming conventions, and code structure:

```json
{
  "syntactic": {
    "naming": "snake_case for functions",
    "formatting": "4-space indentation",
    "structure": "class with __init__ and methods"
  }
}
```

**Example**: "All function names must be lowercase with underscores"

#### 2. **Type Constraints** (Type Safety)
Enforce type safety, null checks, return types:

```json
{
  "type_safety": {
    "forbid": ["any", "unknown"],
    "require": ["explicit_returns", "type_annotations"],
    "nullable_handling": "explicit_null_checks"
  }
}
```

**Example**: "All variables must have explicit type annotations, no `any` types"

#### 3. **Semantic Constraints** (Behavior)
Enforce data flow, control flow, side effects:

```json
{
  "semantic": {
    "no_side_effects_in": ["pure_functions"],
    "data_flow": "validate_input_before_use",
    "control_flow": "single_exit_point"
  }
}
```

**Example**: "Database writes only occur in designated handler functions"

#### 4. **Architectural Constraints** (Structure)
Enforce module boundaries, layering, dependency directions:

```json
{
  "architectural": {
    "module_boundaries": "routes cannot import models directly",
    "layer_ordering": "handlers → services → repositories",
    "forbidden_imports": ["internal_impl"]
  }
}
```

**Example**: "No route handlers can directly access the database layer"

#### 5. **Operational Constraints** (Performance)
Enforce performance bounds, resource limits:

```json
{
  "operational": {
    "max_memory": "100MB",
    "max_complexity": 10,
    "max_execution_time": "1s",
    "cache_required": true
  }
}
```

**Example**: "Function complexity must stay below 10, use caching for database queries"

#### 6. **Security Constraints** (Safety)
Enforce authentication, input validation, secure patterns:

```json
{
  "security": {
    "requires": ["authentication", "input_validation"],
    "forbid": ["eval", "exec", "pickle.loads"],
    "sql_pattern": "parameterized_queries_only"
  }
}
```

**Example**: "All user input must pass validation, no SQL injection patterns allowed"

### How Ananke Works

Ananke is a four-layer system:

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Code/Tests/Docs                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Analysis Layer (Clew/Braid/Ariadne) - Runs Locally              │
│                                                                  │
│ 1. CLEW: Extract constraints from your codebase                 │
│    - Tree-sitter static analysis                                │
│    - Optional Claude API for semantic understanding             │
│    - Constraint reports in JSON                                 │
│                                                                  │
│ 2. BRAID: Compile constraints into execution format             │
│    - Build constraint dependency graph                          │
│    - Detect and resolve conflicts                               │
│    - Optimize for fast validation                               │
│    - Output: ConstraintIR (intermediate representation)         │
│                                                                  │
│ 3. ARIADNE: High-level constraint DSL (optional)                │
│    - Write constraints in natural language-like syntax          │
│    - Compile to ConstraintIR                                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Orchestration Layer (Maze) - Rust                               │
│                                                                  │
│ Coordinates generation, caches constraints, manages requests    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Generation Layer (Modal GPU Service)                            │
│                                                                  │
│ - vLLM: High-performance model inference                        │
│ - llguidance: Token-level constraint enforcement                │
│ - Ensures every token respects constraints                      │
│ - Output: Validated code                                        │
└─────────────────────────────────────────────────────────────────┘
```

### When to Use Claude API vs Inference Server

**Claude API** (Analysis Layer) - Good for:
- Extracting constraints from existing code
- Understanding test requirements  
- Resolving constraint conflicts
- Semantic code analysis
- No GPU needed, no setup required

**Inference Server** (Generation Layer) - Required for:
- Actual code generation with constraints
- Token-level enforcement
- Open models (Llama, Mistral, DeepSeek)
- Full control and transparency
- Requires GPU infrastructure (Modal, RunPod, local)

---

## Installation

### System Requirements

- **Minimum**: Python 3.8+, 2GB disk space
- **For Analysis Only** (Clew/Braid): MacOS/Linux/Windows
- **For Generation** (Maze): Linux or MacOS with Docker
- **For Inference**: GPU infrastructure (Modal account recommended)

### Option 1: Quick Install (Recommended)

```bash
# Install from PyPI
pip install ananke-ai

# Verify installation
ananke --version
# Output: ananke 0.1.0
```

### Option 2: From Source

```bash
# Clone repository
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# Install development version
pip install -e .

# Build Zig components (requires Zig 0.15.1+)
zig build -Doptimize=ReleaseFast

# Run tests
zig build test
```

### Option 3: Docker

```bash
# Build image
docker build -t ananke:latest .

# Run container
docker run -it -v $(pwd):/workspace ananke:latest

# Inside container
ananke extract /workspace/src --output constraints.json
```

### Set Up Modal (for Code Generation)

**One-time setup** (takes 5 minutes):

```bash
# 1. Create free Modal account
# Visit https://modal.com (free tier includes $30/month credits)

# 2. Install Modal CLI
pip install modal

# 3. Authenticate
modal token new
# Opens browser to complete authentication

# 4. Create HuggingFace secret for model access
# Get token from https://huggingface.co/settings/tokens
# Accept Llama 3.1 license at https://huggingface.co/meta-llama/...

modal secret create huggingface-secret \
  HUGGING_FACE_HUB_TOKEN=hf_your_token_here

# 5. Deploy inference service
ananke service deploy --model llama-3.1-8b

# 6. Verify deployment
modal app list
# Should show ananke-inference in the list
```

### Prerequisites for Development

If building from source:

- **Zig**: 0.15.1 or later (install from https://ziglang.org)
- **Rust**: Latest stable (install from https://rustup.rs)
- **Python**: 3.8+ with pip
- **Git**: For cloning the repository

```bash
# Verify prerequisites
zig version      # Should print 0.15.1+
rustc --version  # Should print 1.70+
python --version # Should print 3.8+
```

---

## Usage Patterns

### Pattern 1: CLI for Code Analysis

Fastest way to extract and analyze constraints from existing code.

```bash
# Extract constraints from a directory
ananke extract ./src \
  --language python \
  --output constraints.json

# View what constraints were found
cat constraints.json
# {
#   "syntactic": {...},
#   "type_safety": {...},
#   "security": {...},
#   ...
# }

# Compile constraints
ananke compile constraints.json \
  --output compiled.cir

# Validate code against constraints
ananke validate ./src/handlers/auth.py compiled.cir
# Output: ✓ 45 constraints satisfied
#         ✗ 2 constraints violated: ...
```

### Pattern 2: Library Integration in Build Tools

Integrate Ananke into your build pipeline:

```python
# In your build system
from ananke import Clew, Braid, Maze

# Extract constraints
clew = Clew()
constraints = clew.extract_from_directory("./src")

# Compile
braid = Braid()
compiled = braid.compile(constraints)

# Save for later use
import json
with open("constraints.json", "w") as f:
    json.dump(compiled, f)

print(f"Extracted {len(constraints)} constraints")
```

### Pattern 3: API Service for Teams

Run Ananke as a team service:

```bash
# Deploy API server (handles multiple concurrent requests)
ananke service deploy --mode api --workers 4

# From your team's tools
curl -X POST https://ananke-service.company.com/generate \
  -H "Content-Type: application/json" \
  -d '{
    "intent": "Add email validation to user signup",
    "constraints": "constraints.json",
    "max_tokens": 500
  }'
```

### Pattern 4: Pre-commit Hook

Validate code before commit:

```bash
# Install pre-commit hook
ananke hook install

# In .git/hooks/pre-commit (auto-generated):
#!/bin/bash
ananke validate $(git diff --cached --name-only) \
  --constraints .ananke/constraints.json || exit 1

# Now commit is blocked if code violates constraints
git commit -m "Add feature"
# ✗ Constraint violations detected!
# Fix and try again
```

### Pattern 5: Code Review Automation

Add to GitHub/GitLab:

```yaml
# .github/workflows/constraint-check.yml
name: Constraint Validation

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Check constraints
        run: |
          pip install ananke-ai
          ananke validate ./src --constraints .ananke/constraints.json
          
          if [ $? -ne 0 ]; then
            echo "PR violates constraints!"
            exit 1
          fi
```

---

## Constraint Sources

### Source 1: Automatic Extraction (Clew)

Ananke automatically extracts constraints from your existing code:

```bash
# Extract from source files
ananke extract ./src --output auto-constraints.json

# Extract from test files
ananke extract ./tests \
  --type tests \
  --output test-constraints.json

# Combine multiple sources
ananke extract ./src ./tests ./docs \
  --output all-constraints.json
```

Clew looks for patterns like:

- **Type hints**: `def func(x: int) -> str:` → Type constraint
- **Decorators**: `@require_auth` → Security constraint
- **Docstrings**: `"Validates email format"` → Semantic constraint
- **Exception handling**: `except ValueError:` → Error handling constraint
- **Test assertions**: `assert len(users) > 0` → Behavior constraint

### Source 2: Manual JSON Constraints

Define constraints explicitly:

```json
{
  "project": "user-service",
  "constraints": {
    "type_safety": {
      "forbid": ["any", "unknown"],
      "require": ["explicit_returns"]
    },
    "security": {
      "requires": ["authentication"],
      "forbid": ["eval", "exec"]
    },
    "architectural": {
      "module_boundaries": "routes → services → repositories"
    }
  }
}
```

### Source 3: YAML Constraints

More readable format:

```yaml
project: user-service

constraints:
  type_safety:
    forbid:
      - any
      - unknown
    require:
      - explicit_returns
      - type_annotations
  
  security:
    requires:
      - authentication
      - input_validation
    forbid:
      - eval
      - exec
      - pickle.loads
  
  performance:
    max_complexity: 10
    cache_required: true
```

### Source 4: Ariadne DSL

High-level constraint language:

```ariadne
# .ananke/secure-api.ariadne

constraint secure_api {
    # What this constraint requires
    requires:
        - authentication
        - input_validation;
    
    # What it forbids
    forbid: eval, exec, system;
    
    # Performance bounds
    max_complexity: 10;
    max_execution_time: 30s;
    
    # Temporal constraints
    temporal {
        timeout: 30s;
        retry_policy: exponential_backoff;
    }
}

constraint database_access {
    # Only designated services can access database
    allows: repository_layer;
    forbids: controllers, utils;
    
    # All queries must be parameterized
    pattern: "SELECT .* FROM .* WHERE .* = ?";
}
```

Compile to IR:

```bash
ananke compile .ananke/*.ariadne --output constraints.cir
```

### Source 5: Combining Multiple Sources

Mix and match constraint sources:

```bash
# Combine automatic extraction, manual JSON, and DSL
ananke extract ./src ./tests \
  --output auto.json

cat auto.json manual-constraints.json > combined.json

ananke compile combined.json .ananke/*.ariadne \
  --output constraints.cir

# Now use compiled constraints
ananke generate "Add new endpoint" \
  --constraints constraints.cir
```

### Source 6: Claude-Enhanced Extraction

Use Claude to understand complex constraints:

```bash
# Set Claude API key
export ANTHROPIC_API_KEY=sk_...

# Extract with Claude analysis
ananke extract ./src \
  --use-claude \
  --output constraints.json

# Claude helps understand:
# - Complex test requirements
# - Implicit architectural patterns
# - Security implications
# - Performance characteristics
```

---

## Configuration

### Environment Variables

```bash
# Modal service configuration
export MODAL_ENDPOINT="https://yourapp.modal.run"
export MODAL_API_KEY="your-modal-key"

# Claude API (optional, for analysis)
export ANTHROPIC_API_KEY="sk_..."

# Logging
export ANANKE_LOG_LEVEL="info"  # debug, info, warn, error

# Performance tuning
export ANANKE_CACHE_SIZE="1000"  # Cached constraints
export ANANKE_MAX_TOKENS="2048"
export ANANKE_TEMPERATURE="0.7"

# Inference service
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
export INFERENCE_GPU_MEMORY="0.9"  # 90% of available GPU
```

### Configuration File

Create `.ananke/config.yaml`:

```yaml
# Service configuration
service:
  endpoint: "https://yourapp.modal.run"
  api_key: "${MODAL_API_KEY}"
  
# Model configuration
model:
  name: "meta-llama/Meta-Llama-3.1-8B-Instruct"
  max_tokens: 2048
  temperature: 0.7
  
# Constraint configuration
constraints:
  # Cache compiled constraints
  cache_enabled: true
  cache_size: 1000
  
  # Automatically extract from these directories
  auto_extract_from:
    - src
    - tests
  
  # Use Claude for semantic analysis
  use_claude: false
  claude_model: "claude-3-sonnet"

# Logging
logging:
  level: "info"
  format: "json"
  file: ".ananke/logs/ananke.log"

# Development
development:
  debug_mode: false
  save_generation_traces: true
  mock_inference: false  # Use mock service if inference unavailable
```

### Per-Project Override

Override config for specific projects:

```bash
# Use different model for this project
ananke generate "feature" \
  --model meta-llama/Meta-Llama-3.1-70B-Instruct \
  --temperature 0.3 \
  --max-tokens 1000
```

---

## Common Tasks

### Task 1: Extract Constraints from Existing Code

```bash
# Basic extraction
ananke extract ./src --output constraints.json

# Extract with details
ananke extract ./src \
  --detailed \
  --include-patterns \
  --output constraints.json

# View extracted constraints
ananke constraints show constraints.json

# Extract only certain types
ananke extract ./src \
  --types "type_safety,security" \
  --output filtered.json
```

### Task 2: Generate Code with Constraints

```bash
# Simple generation
ananke generate "Implement user authentication" \
  --constraints constraints.json

# With options
ananke generate "Add pagination support" \
  --constraints constraints.json \
  --max-tokens 500 \
  --temperature 0.5 \
  --language python \
  --output generated.py

# Interactive mode (get feedback)
ananke generate "Add feature" --constraints constraints.json --interactive
# Then refine based on constraints report
```

### Task 3: Validate Code Against Constraints

```bash
# Check if code satisfies constraints
ananke validate ./src/handlers.py --constraints constraints.json

# Detailed report
ananke validate ./src \
  --constraints constraints.json \
  --detailed \
  --output validation-report.md

# Check only certain constraints
ananke validate ./src \
  --constraints constraints.json \
  --check "security,type_safety"
```

### Task 4: Set Up for CI/CD

```bash
# Add to your CI pipeline
ananke setup-ci --provider github  # or gitlab, circleci, etc

# This creates:
# - .github/workflows/ananke-check.yml
# - .ananke/constraints.json
# - .ananke/config.yaml
```

### Task 5: Share Constraints with Team

```bash
# Export constraints
ananke constraints export \
  --format json \
  --output team-constraints.json

# Or export as documentation
ananke constraints export \
  --format markdown \
  --output CONSTRAINTS.md

# Import shared constraints
ananke constraints import team-constraints.json
```

### Task 6: Debug Constraint Issues

```bash
# Show why constraint failed
ananke validate code.py \
  --constraints constraints.json \
  --debug

# This shows:
# - Which tokens violated constraints
# - Why they violated
# - Alternative tokens that would work
# - Constraint dependency chain

# Enable detailed logging
ANANKE_LOG_LEVEL=debug ananke generate "feature" --constraints constraints.json
```

---

## Troubleshooting

### Installation Issues

**Problem**: `ModuleNotFoundError: No module named 'ananke'`

**Solution**:
```bash
# Reinstall
pip install --upgrade ananke-ai

# Or from source
git clone https://github.com/ananke-ai/ananke.git
cd ananke
pip install -e .
```

**Problem**: `Zig not found` when building from source

**Solution**:
```bash
# Install Zig
curl https://ziglang.org/download/index.json | python3 -c \
  "import json, sys; v = json.load(sys.stdin)['master']; print(v['$(uname -m)']['tarball'])" | \
  xargs curl -O
tar xf zig-*.tar.xz
export PATH=$PWD/zig-*:$PATH

# Verify
zig version
```

### Modal Service Issues

**Problem**: `modal token new` fails or authentication timeout

**Solution**:
```bash
# Check Modal authentication
modal token list

# If empty, authenticate again
modal token new --force

# Verify endpoint
modal app list

# Check service logs
modal logs ananke-inference
```

**Problem**: `Out of memory (OOM)` on Modal

**Solution**:
```python
# In your config, reduce memory usage
# Either use smaller model:
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"

# Or reduce batch size
ananke generate "feature" --batch-size 1
```

**Problem**: Model download fails with `401 Unauthorized`

**Solution**:
```bash
# Verify HuggingFace secret
modal secret list

# Check token validity
# Visit https://huggingface.co/settings/tokens

# Recreate secret
modal secret create huggingface-secret \
  --force \
  HUGGING_FACE_HUB_TOKEN=hf_your_new_token

# Accept model license
# Visit https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct
```

### Constraint Issues

**Problem**: Constraints too restrictive, no valid outputs possible

**Solution**:
```bash
# Check for conflicting constraints
ananke constraints validate constraints.json

# Use Claude to suggest resolution
ananke constraints analyze constraints.json --use-claude

# Relax constraints
ananke constraints modify constraints.json \
  --relax "complexity_limit" \
  --output relaxed.json
```

**Problem**: Code violates constraints after generation

**Solution**:
```bash
# Debug which constraint failed
ananke validate generated.py \
  --constraints constraints.json \
  --debug

# This shows the failing constraint and why

# Try regenerating with stricter constraints
ananke generate "feature" \
  --constraints constraints.json \
  --temperature 0.3 \
  --strict-mode
```

### Performance Issues

**Problem**: Generation is slow (>10 seconds)

**Solution**:
```bash
# Reduce generation complexity
ananke generate "feature" \
  --max-tokens 256 \
  --temperature 0.5

# Check inference service health
modal logs ananke-inference | tail -50

# Use smaller model
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
```

**Problem**: Constraint extraction takes >5 seconds

**Solution**:
```bash
# Extract only needed types
ananke extract ./src --types "security,type_safety"

# Skip Claude analysis (if enabled)
ananke extract ./src --no-claude

# Extract from fewer files
ananke extract ./src/handlers ./src/models
```

### API Errors

**Problem**: `Connection refused` when calling Modal service

**Solution**:
```bash
# Verify service is deployed
modal app list

# Check service is healthy
curl https://yourapp.modal.run/health

# Check endpoint environment variable
echo $MODAL_ENDPOINT

# Redeploy if needed
modal deploy modal_inference/inference.py
```

**Problem**: `401 Unauthorized` API errors

**Solution**:
```bash
# Check API key
echo $MODAL_API_KEY

# Regenerate if needed
modal token new --force

# Or use authentication header
ananke generate "feature" \
  --auth-token "your-token-here"
```

---

## Getting Help

### Documentation
- **Architecture**: See `/docs/ARCHITECTURE.md`
- **Implementation Plan**: See `/docs/IMPLEMENTATION_PLAN.md`
- **API Reference**: See `/docs/API.md`
- **Tutorials**: See `/docs/tutorials/`

### Community
- **GitHub Issues**: Report bugs at https://github.com/ananke-ai/ananke/issues
- **Discussions**: Ask questions at https://github.com/ananke-ai/ananke/discussions
- **Discord**: Join our community (link in README)

### Support Options
- **Free tier**: GitHub issues and discussions
- **Email support**: support@ananke-ai.dev (paid plans)
- **Commercial**: enterprise@ananke-ai.dev

---

## Next Steps

1. **Complete Quick Start** (above)
2. **Run Tutorials** (in `/docs/tutorials/`)
   - Tutorial 1: Extract constraints from example code
   - Tutorial 2: Compile and optimize constraints
   - Tutorial 3: Generate your first constrained code
   - Tutorial 4: Write Ariadne DSL constraints
   - Tutorial 5: Integrate with CI/CD
3. **Read API Reference** (`/docs/API.md`)
4. **Explore Examples** (`/docs/examples/`)
5. **Join Community** - Ask questions, share patterns

---

**Made with care for developers who demand control over their AI systems.**
