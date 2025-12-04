# Contributing to Ananke

Thank you for your interest in contributing to Ananke! This guide will help you get started with development, code standards, and the contribution process.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Code Style](#code-style)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Commit Guidelines](#commit-guidelines)
- [Issue Reporting](#issue-reporting)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- **Zig 0.15.2 or later**: [Download Zig](https://ziglang.org/download/)
- **Git**: For version control
- **Text Editor/IDE**: VS Code with Zig extension recommended

### Quick Start

```bash
# Clone the repository
git clone https://github.com/rand/ananke.git
cd ananke

# Set up configuration (one-time)
cp .ananke.toml.example .ananke.toml
cp .env.example .env
# Edit these files with your Modal workspace and API keys

# Build the project
zig build

# Run tests
zig build test

# Run the CLI
zig build run
```

## Development Setup

### 1. Install Zig

Download and install Zig from [ziglang.org](https://ziglang.org/download/). Verify installation:

```bash
zig version
# Should output: 0.15.2 or later
```

### 2. Clone and Build

```bash
git clone https://github.com/rand/ananke.git
cd ananke
zig build
```

### 3. Verify Setup

```bash
# Run all tests
zig build test

# Check formatting
zig fmt --check src/

# Build optimized release
zig build -Doptimize=ReleaseFast
```

### 4. IDE Configuration

#### VS Code

Install the [Zig Language extension](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig).

Recommended `.vscode/settings.json`:

```json
{
  "zig.path": "zig",
  "zig.zls.path": "zls",
  "zig.initialSetupDone": true,
  "editor.formatOnSave": true,
  "[zig]": {
    "editor.defaultFormatter": "ziglang.vscode-zig"
  }
}
```

#### Other Editors

- **Vim/Neovim**: Install [zig.vim](https://github.com/ziglang/zig.vim)
- **Emacs**: Install [zig-mode](https://github.com/ziglang/zig-mode)
- **Sublime Text**: Install Zig package from Package Control

### 5. Configuration Files

Ananke uses local configuration files that are not tracked in git:

```bash
# Copy configuration templates
cp .ananke.toml.example .ananke.toml
cp .env.example .env

# Edit with your values
# - Update Modal endpoint with your workspace name
# - Add API keys as needed
```

**Required for Modal inference:**
- Edit `.ananke.toml` and replace `<YOUR_MODAL_WORKSPACE>` with your Modal workspace name
- Or set `ANANKE_MODAL_ENDPOINT` environment variable

**Optional for Claude integration:**
- Set `ANTHROPIC_API_KEY` in `.env` or environment

See `.env.example` for all available configuration options.

## Project Structure

```
ananke/
├── src/
│   ├── main.zig              # CLI entry point
│   ├── root.zig              # Library root
│   ├── types/                # Core type definitions
│   │   ├── intent.zig        # Intent representations
│   │   └── constraint.zig    # Constraint definitions
│   ├── clew/                 # Constraint extraction engine
│   │   └── clew.zig
│   ├── braid/                # Constraint compilation
│   │   └── braid.zig
│   └── ariadne/              # DSL compiler
│       └── ariadne.zig
├── examples/                 # Example usage
│   ├── pure-local/
│   ├── with-claude-analysis/
│   └── full-pipeline/
├── docs/                     # Documentation
├── build.zig                 # Build configuration
├── build.zig.zon             # Package dependencies
└── README.md
```

## Code Style

### Zig Formatting

We use the standard Zig formatter. **All code must be formatted before committing.**

```bash
# Format all files
zig fmt src/

# Check formatting without modifying
zig fmt --check src/
```

### Naming Conventions

- **Functions**: `camelCase`
- **Types**: `PascalCase`
- **Constants**: `SCREAMING_SNAKE_CASE` or `camelCase` for compile-time values
- **Variables**: `snake_case` or `camelCase`

```zig
// Good
const MAX_BUFFER_SIZE = 4096;
const MyStruct = struct { ... };
fn processRequest() void { ... }
var itemCount: usize = 0;

// Avoid
const max_buffer_size = 4096;  // Constants should be SCREAMING_SNAKE_CASE
const myStruct = struct { ... };  // Types should be PascalCase
fn ProcessRequest() void { ... }  // Functions should be camelCase
```

### Documentation

All public APIs must have documentation comments:

```zig
/// Extracts constraints from the given source code.
///
/// This function analyzes the AST and identifies constraint patterns
/// that can be enforced during code generation.
///
/// Arguments:
///   - allocator: Memory allocator for temporary storage
///   - source: Source code to analyze
///
/// Returns:
///   - A list of extracted constraints, or an error
///
/// Example:
/// ```zig
/// const constraints = try extractConstraints(allocator, source_code);
/// defer constraints.deinit();
/// ```
pub fn extractConstraints(
    allocator: std.mem.Allocator,
    source: []const u8,
) !ConstraintList {
    // Implementation
}
```

### Error Handling

- Use error unions for fallible operations: `!ReturnType`
- Define specific error sets rather than using `anyerror`
- Clean up resources with `defer` and `errdefer`

```zig
const ParseError = error{
    InvalidSyntax,
    UnexpectedToken,
    EndOfFile,
};

fn parseConstraint(input: []const u8) ParseError!Constraint {
    const data = try allocator.alloc(u8, size);
    errdefer allocator.free(data);

    // Parse logic

    return Constraint{ .data = data };
}
```

### Memory Management

- Always specify the allocator explicitly
- Use `defer` for cleanup
- Avoid memory leaks (verify with `zig build test`)

```zig
fn processData(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try buffer.appendSlice(input);
    return buffer.toOwnedSlice();
}
```

## Testing Requirements

### Writing Tests

All new code must include tests. Place tests in the same file as the code being tested.

```zig
test "extractConstraints handles empty input" {
    const allocator = std.testing.allocator;

    const result = try extractConstraints(allocator, "");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.items.len);
}

test "extractConstraints parses simple constraint" {
    const allocator = std.testing.allocator;
    const source = "constraint: type = String";

    const result = try extractConstraints(allocator, source);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.items.len);
    try std.testing.expectEqualStrings("String", result.items[0].type_name);
}
```

### Running Tests

```bash
# Run all tests
zig build test

# Run tests with verbose output
zig build test --summary all

# Run specific test
zig test src/clew/clew.zig
```

### Test Coverage

While Zig doesn't have built-in coverage tools yet, aim for:

- **Unit tests**: Test individual functions in isolation
- **Integration tests**: Test module interactions
- **Edge cases**: Empty inputs, boundary values, error conditions

### Continuous Integration

All PRs must pass:

- ✅ All tests
- ✅ Code formatting check
- ✅ Builds on Linux, macOS, Windows
- ✅ No compiler warnings

## Pull Request Process

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

### 2. Make Changes

- Write code following the style guide
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Format and Test

```bash
# Format code
zig fmt src/

# Run tests
zig build test

# Build release to check for warnings
zig build -Doptimize=ReleaseSafe
```

### 4. Commit Changes

Follow the [commit guidelines](#commit-guidelines) below.

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:

- **Clear title**: Describe what the PR does
- **Description**: Explain why the change is needed
- **Testing**: Describe how you tested the changes
- **Breaking changes**: Note any API changes

### 6. Code Review

- Address reviewer feedback
- Keep the PR focused and reasonably sized
- Update tests if implementation changes

### 7. Merge

Once approved and all checks pass, a maintainer will merge your PR.

## Commit Guidelines

We follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic changes)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks
- **perf**: Performance improvements

### Examples

```bash
feat(clew): add support for regex constraints

Implements pattern matching constraints using Zig's regex library.
This enables more expressive constraint definitions.

Closes #123

---

fix(braid): resolve memory leak in constraint compilation

The constraint compiler was not properly freeing temporary allocations.
Added errdefer cleanup and verified with tests.

---

docs(api): update constraint extraction examples

Added more detailed examples showing edge cases and error handling.
```

## Issue Reporting

### Bug Reports

Include:

- **Zig version**: Output of `zig version`
- **OS and version**: e.g., Ubuntu 22.04, macOS 13.0
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Minimal reproduction**: Smallest code example that shows the bug
- **Stack trace**: If applicable

### Feature Requests

Include:

- **Use case**: Why is this feature needed?
- **Proposed solution**: How might it work?
- **Alternatives**: Other approaches you've considered
- **Examples**: Code examples if applicable

## Development Workflow

### Daily Development

```bash
# Update main branch
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/my-feature

# Make changes, test frequently
zig build test

# Format before committing
zig fmt src/

# Commit with conventional format
git commit -m "feat(module): add new functionality"

# Push and create PR
git push origin feature/my-feature
```

### Debugging

```bash
# Build with debug symbols
zig build -Doptimize=Debug

# Run with verbose logging
zig build run -- --verbose

# Use Zig's built-in debugger
zig build test --debug
```

## Additional Resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Standard Library Documentation](https://ziglang.org/documentation/master/std/)
- [Zig Build System](https://ziglang.org/learn/build-system/)
- [Project README](README.md)
- [Architecture Documentation](docs/architecture.md)

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bugs**: Create an Issue


Thank you for contributing to Ananke!
