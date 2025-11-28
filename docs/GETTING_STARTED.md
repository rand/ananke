# Ananke Getting Started Guide

**Welcome to Ananke!** This guide will get you from zero to extracting, compiling, and understanding constraints in about 45 minutes.

**What is Ananke?** A constraint-driven code generation system that transforms AI from probabilistic guessing into controlled search through valid program spaces. It extracts constraints from your existing code and enforces them during generation.

---

## Table of Contents

- [Prerequisites (5 minutes)](#prerequisites-5-minutes)
- [Quick Start (10 minutes)](#quick-start-10-minutes)
- [Core Concepts (5 minutes)](#core-concepts-5-minutes)
- [Tutorial Path (30 minutes)](#tutorial-path-30-minutes)
- [Production Usage](#production-usage)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

---

## Prerequisites (5 minutes)

### Required

**Zig 0.15.2 or later**

Ananke is built with Zig for speed and safety. Install Zig:

```bash
# macOS (Homebrew)
brew install zig

# Linux (direct download)
wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
tar xf zig-linux-x86_64-0.15.2.tar.xz
sudo mv zig-linux-x86_64-0.15.2 /usr/local/zig
export PATH=$PATH:/usr/local/zig

# Verify installation
zig version
# Expected: 0.15.2 or higher
```

**Build Tools**

Standard development tools for your platform:

```bash
# macOS: Xcode Command Line Tools (if not already installed)
xcode-select --install

# Linux: GCC/Clang and standard build tools
sudo apt-get install build-essential  # Debian/Ubuntu
sudo yum groupinstall "Development Tools"  # CentOS/RHEL
```

### Optional

**Claude API Key** (for semantic analysis)

Ananke works great without Claude, but semantic analysis adds deeper understanding:

1. Get a key from [Anthropic Console](https://console.anthropic.com/)
2. Set environment variable:
   ```bash
   export ANTHROPIC_API_KEY='sk-ant-api...'
   ```
3. Cost: ~$0.01-0.05 per extraction (depending on file size)

**Modal Account** (for code generation)

Required only if you want end-to-end generation (extract → compile → generate):

1. Sign up at [modal.com](https://modal.com/)
2. Install Modal CLI: `pip install modal`
3. Authenticate: `modal token new`

**Note**: Most of this guide works without any API keys. Start with the basics, add services later.

---

## Quick Start (10 minutes)

### 1. Clone and Build (3 minutes)

```bash
# Clone the repository
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# Build everything
zig build

# This compiles:
# - Clew (constraint extraction)
# - Braid (constraint compilation)
# - Maze (orchestration layer)
# - All example programs
# - CLI tool

# Expected build time: ~10-30 seconds
```

### 2. Verify Installation (1 minute)

```bash
# Check the CLI
./zig-out/bin/ananke --version
# Expected: ananke 0.1.0

# See available commands
./zig-out/bin/ananke --help
# Shows: extract, compile, generate, validate, init

# Optional: Add to PATH for convenience
export PATH="$PATH:$(pwd)/zig-out/bin"
ananke --version
```

### 3. Run Your First Example (5 minutes)

```bash
# Navigate to the simple extraction example
cd examples/01-simple-extraction

# Run the example
zig build run

# Expected: Extraction completes in <100ms
# You'll see constraints extracted from sample.ts
```

**What you should see:**

```
=== Ananke Example 01: Simple Constraint Extraction ===

Analyzing file: sample.ts
File size: 3515 bytes

Extracting constraints (without Claude)...

Found 15 constraints:

Constraint 1: Export statement
  Kind: architectural
  Severity: info
  Description: Export statement detected at line 8
  Source: AST_Pattern
  Confidence: 0.85

=== Summary by Kind ===
  syntactic: 5
  type_safety: 6
  semantic: 3
  architectural: 1
```

**Success!** You just extracted constraints from TypeScript code using pure static analysis (no external services, no API keys).

---

## Core Concepts (5 minutes)

### What Are Constraints?

Constraints are rules that code must follow. Ananke extracts them from your existing code and enforces them during generation.

**Example constraints:**
- "Functions must have explicit return types" (syntactic)
- "Password fields cannot be null" (type safety)
- "All API endpoints must validate input" (security)
- "Error responses must include status codes" (architectural)

### The Ananke Pipeline

Ananke has three main components:

```
1. CLEW (Extract)
   Your Code/Tests/Docs → Constraint Set
   - Static analysis with tree-sitter
   - Optional: Claude for semantic understanding
   - Output: Structured constraints

2. BRAID (Compile)
   Constraint Set → ConstraintIR
   - Optimize constraint checking
   - Resolve conflicts
   - Output: Efficient validation rules

3. MAZE (Generate)
   ConstraintIR + Intent → Valid Code
   - Token-level enforcement
   - Guarantees constraint satisfaction
   - Output: Code that MUST follow your rules
```

### Extract → Compile → Generate Workflow

**Step 1: Extract** - Learn from your existing code
```bash
ananke extract ./src --output constraints.json
# Finds patterns in your codebase
```

**Step 2: Compile** - Optimize for validation
```bash
ananke compile constraints.json --output compiled.cir
# Creates efficient constraint rules
```

**Step 3: Generate** - Create new code that follows the rules
```bash
ananke generate "add authentication endpoint" \
  --constraints compiled.cir \
  --output new_code.ts
# Generates code guaranteed to satisfy constraints
```

### When to Use Ananke vs. Other Tools

**Use Ananke when:**
- You need guaranteed adherence to coding patterns
- You're generating code for critical systems (auth, payments, etc.)
- You want to enforce architectural decisions
- You're building code generators for your team

**Use standard LLMs when:**
- You're exploring ideas without strict requirements
- You need creative/open-ended solutions
- Constraints are fuzzy or hard to formalize
- Speed matters more than correctness

**Key difference**: Ananke enforces constraints at the token level. Code that violates constraints cannot be generated. Standard LLMs can only "try" to follow instructions.

---

## Tutorial Path (30 minutes)

Work through these examples in order. Each builds on the previous one.

### Example 01: Simple Extraction (5 minutes)

**Location**: `examples/01-simple-extraction`

**What you'll learn:**
- How to extract constraints without any external services
- What kinds of constraints static analysis can find
- How to interpret constraint output

**Run it:**
```bash
cd examples/01-simple-extraction
zig build run
```

**Key insights:**
- Type systems encode many constraints
- Static analysis is fast (<100ms) and deterministic
- No API keys or external services needed

**Try this:**
```bash
# Analyze different sample files
# Edit main.zig to change file_path:
# const file_path = "sample_python.py";  // Python
# const file_path = "sample_go.go";      // Go
# const file_path = "sample_rust.rs";    // Rust

zig build run
```

**See**: `examples/01-simple-extraction/README.md` for detailed walkthrough

---

### Example 02: Claude-Enhanced Analysis (8 minutes)

**Location**: `examples/02-claude-analysis`

**What you'll learn:**
- How Claude adds semantic understanding
- Business rule extraction from code
- Comparison of static vs. semantic analysis

**Setup** (if you have Claude API key):
```bash
cd examples/02-claude-analysis

# Set your API key
export ANTHROPIC_API_KEY='sk-ant-api...'

# Run comparison
zig build run
```

**Without Claude**:
```bash
# Still works! Shows what Claude would add
zig build run
# Demonstrates static-only analysis
```

**What Claude adds:**
- Understanding of business logic
- Intent recognition from comments
- Implicit constraints (e.g., "payments should be idempotent")
- Domain-specific patterns

**Cost**: ~$0.01-0.05 per run

**See**: `examples/02-claude-analysis/README.md` for setup details

---

### Example 03: Ariadne DSL (7 minutes)

**Location**: `examples/03-ariadne-dsl`

**What you'll learn:**
- How to write constraints in Ariadne DSL
- Difference between DSL and JSON configuration
- When to use each approach

**Run it:**
```bash
cd examples/03-ariadne-dsl
zig build run
```

**Example constraint in Ariadne:**
```ariadne
constraint secure_api {
    requires: authentication;
    validates: input_schema;
    forbid: ["eval", "exec"];
    max_complexity: 10;
}
```

**vs. JSON:**
```json
{
  "name": "secure_api",
  "requires": ["authentication"],
  "validates": ["input_schema"],
  "forbid": ["eval", "exec"],
  "max_complexity": 10
}
```

**When to use DSL**: Complex constraint hierarchies, inheritance, macros
**When to use JSON**: Simple constraints, CI/CD integration, programmatic generation

**Note**: Ariadne is experimental in v0.1.0. Use JSON for production systems.

**See**: `examples/03-ariadne-dsl/README.md` for DSL syntax guide

---

### Example 04: Full Pipeline (5 minutes)

**Location**: `examples/04-full-pipeline`

**Status**: Planned for v0.2

**What it will show:**
- Complete extract → compile → generate workflow
- Integration with Modal inference service
- Validation of generated code

**Current status**: Available for review but requires Modal setup

**See**: `examples/04-full-pipeline/README.md` for roadmap

---

### Example 05: Mixed Mode (5 minutes)

**Location**: `examples/05-mixed-mode`

**What you'll learn:**
- Combining multiple constraint sources
- Merging extracted, JSON, and DSL constraints
- Conflict resolution

**Run it:**
```bash
cd examples/05-mixed-mode
zig build run
```

**This example merges:**
1. Constraints extracted from existing code
2. Security policies from JSON config
3. Architectural rules from Ariadne DSL
4. Manual constraints from command line

**Real-world use case**: Your project has:
- Legacy code with implicit patterns
- Explicit security requirements
- Team coding standards
- Project-specific rules

Mixed mode brings them all together.

**See**: `examples/05-mixed-mode/README.md` for integration patterns

---

## Production Usage

After completing the tutorials, explore production-ready examples.

### Production Examples Overview

**Location**: `examples/production/`

These are complete, runnable workflows demonstrating real-world value:

| Example | Language | Setup Time | Value Proposition |
|---------|----------|------------|-------------------|
| **01-openapi-route-generation** | TypeScript | 5 min | Eliminate boilerplate, ensure spec compliance |
| **02-database-migration-generator** | SQL/Python | 3 min | Automate migrations, prevent schema errors |
| **03-react-component-generator** | TypeScript/React | 7 min | Enforce design system, guarantee accessibility |
| **04-cli-tool-generator** | Python | 4 min | Consistent CLI patterns, robust error handling |
| **05-test-generator** | Python | 3 min | Comprehensive coverage from specs |

### Running Production Examples

```bash
# Pick an example
cd examples/production/01-openapi-route-generation

# Install dependencies (varies by example)
npm install  # or pip install -r requirements.txt

# Run the full pipeline
./run.sh

# Review generated code
cat output/*
```

Each example includes:
- Complete documentation
- Test suite
- Before/after comparisons
- ROI analysis

**See**: `examples/production/README.md` for detailed guides

### Customizing for Your Project

**1. Extract patterns from your codebase:**
```bash
ananke extract ./src --language typescript --output my-patterns.json
```

**2. Add project-specific constraints:**
```bash
# Create .ananke.toml in your project root
cat > .ananke.toml << EOF
[defaults]
language = "typescript"

[extract]
patterns = ["all"]
use_claude = false

[compile]
formats = ["json-schema"]
EOF
```

**3. Run extraction as part of CI/CD:**
```yaml
# .github/workflows/constraints.yml
name: Extract Constraints
on: [push]
jobs:
  extract:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Zig
        run: |
          wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
          tar xf zig-linux-x86_64-0.15.2.tar.xz
          echo "$PWD/zig-linux-x86_64-0.15.2" >> $GITHUB_PATH
      - name: Build Ananke
        run: zig build
      - name: Extract Constraints
        run: ./zig-out/bin/ananke extract ./src --output constraints.json
      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: constraints
          path: constraints.json
```

**4. Validate new code against constraints:**
```bash
ananke validate new-feature.ts constraints.json
# Returns: pass/fail with specific violations
```

---

## Troubleshooting

### Build Issues

**Issue**: `zig version` shows older than 0.15.2

**Solution**:
```bash
# Update Zig
brew upgrade zig  # macOS
# or download from https://ziglang.org/download/

# Verify
zig version
```

---

**Issue**: `zig build` fails with "dependency 'ananke' not found"

**Cause**: Running from wrong directory

**Solution**:
```bash
# Always build from ananke root
cd /path/to/ananke
zig build

# Not from subdirectories
```

---

**Issue**: Build fails with "out of memory"

**Cause**: Insufficient RAM for debug build

**Solution**:
```bash
# Build with optimizations
zig build -Doptimize=ReleaseSafe

# Or increase swap space (Linux)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### Runtime Issues

**Issue**: `FileNotFound` when running examples

**Cause**: Running from wrong directory

**Solution**:
```bash
# Examples must run from their own directory
cd examples/01-simple-extraction
zig build run

# NOT from ananke root:
# cd ananke && examples/01-simple-extraction/zig-out/bin/example  ← Wrong
```

---

**Issue**: "No constraints found"

**Cause**: Language not supported or file has no patterns

**Solution**:
```bash
# Check supported languages (v0.1.0)
# - TypeScript/JavaScript ✓
# - Python ✓
# - Rust, Go, Zig (planned for v0.2)

# Verify file has actual code
cat sample.ts  # Should contain real code, not just comments

# Try with verbose output
ananke extract sample.ts --verbose
```

---

**Issue**: Claude API errors

**Symptom**: `401 Unauthorized` or `Invalid API key`

**Solution**:
```bash
# Verify API key is set
echo $ANTHROPIC_API_KEY
# Should print: sk-ant-api...

# Test API key
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'

# Should return JSON response, not error
```

---

### Performance Issues

**Issue**: Extraction is slow (>5 seconds)

**Cause**: Large file or slow disk

**Solution**:
```bash
# Check file size
ls -lh sample.ts

# Files >100KB may take longer
# Split large files or extract in batches

# Profile extraction
time ananke extract large-file.ts
```

---

**Issue**: High memory usage

**Cause**: Large constraint set or memory leak

**Solution**:
```bash
# Monitor memory
/usr/bin/time -v ananke extract ./src  # Linux
/usr/bin/time -l ananke extract ./src  # macOS

# Reduce scope
ananke extract ./src/auth --output auth-constraints.json
ananke extract ./src/api --output api-constraints.json
# Process separately
```

---

### Getting Help

**Check existing documentation:**
- [FAQ](FAQ.md) - Common questions
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Comprehensive debugging
- [CLI Guide](CLI_GUIDE.md) - Command reference
- [API Reference](API_REFERENCE_ZIG.md) - Library API

**Search for similar issues:**
```bash
# GitHub Issues
https://github.com/ananke-ai/ananke/issues

# Search for error message
https://github.com/ananke-ai/ananke/issues?q=is%3Aissue+"your+error+message"
```

**Report a new issue:**

Include this information:
```bash
# Run diagnostics
bash << 'EOF'
echo "=== Ananke Diagnostics ==="
echo "Zig version:"
zig version
echo ""
echo "System:"
uname -a
echo ""
echo "Environment:"
env | grep -E 'ANTHROPIC|MODAL|ANANKE' || echo "No Ananke env vars"
echo ""
echo "Ananke version:"
./zig-out/bin/ananke --version || echo "ananke not built"
EOF

# Copy output and paste in issue
```

**Community:**
- GitHub Discussions: Share use cases and patterns
- Issues: Bug reports and feature requests
- Examples: Contribute your own examples

---

## Next Steps

### Learn More

**Deep Dives:**
- [Architecture](ARCHITECTURE.md) - System design and internals
- [User Guide](USER_GUIDE.md) - Comprehensive usage guide
- [API Reference](API_REFERENCE_ZIG.md) - Zig library API
- [CLI Guide](CLI_GUIDE.md) - Complete CLI reference

**Advanced Topics:**
- [FFI Guide](FFI_GUIDE.md) - Cross-language integration
- [Deployment](DEPLOYMENT.md) - Production deployment
- [Performance](../PERFORMANCE.md) - Optimization guide

### Extend Ananke

**Add custom constraint patterns:**
```zig
// src/clew/custom_patterns.zig
const CustomPattern = struct {
    name: []const u8,
    regex: []const u8,
    kind: ConstraintKind,
};

pub const my_patterns = [_]CustomPattern{
    .{
        .name = "no_console_log",
        .regex = "console\\.log\\(",
        .kind = .code_quality,
    },
};
```

**Integrate with your tools:**
- VSCode extension (planned)
- Pre-commit hooks
- CI/CD pipelines
- Code review automation

### Contribute

Ananke is open source and contributions are welcome!

**Good first contributions:**
- Add constraint patterns for your language
- Improve documentation
- Add examples for your use case
- Report bugs and suggest features

**See**: `CONTRIBUTING.md` (coming soon)

---

## Quick Reference

### Common Commands

```bash
# Extract constraints
ananke extract ./src --output constraints.json

# Extract with Claude
ananke extract ./src --use-claude --output constraints.json

# Compile constraints
ananke compile constraints.json --output compiled.cir

# Validate code
ananke validate new-code.ts compiled.cir

# Initialize config
ananke init
```

### Configuration

```toml
# .ananke.toml
[defaults]
language = "typescript"
output_format = "pretty"

[extract]
use_claude = false
patterns = ["all"]

[compile]
formats = ["json-schema"]
priority = "medium"
```

### Environment Variables

```bash
# Optional Claude API
export ANTHROPIC_API_KEY='sk-ant-api...'

# Optional Modal (for generation)
export ANANKE_MODAL_ENDPOINT='https://...'
export ANANKE_MODAL_API_KEY='...'

# Default language
export ANANKE_LANGUAGE='typescript'
```

---

**You're ready!** Start with Example 01 and work through the tutorial path. Happy constraining!
