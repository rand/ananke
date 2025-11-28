# Library Integration Guide

This guide shows how to integrate Ananke as a library into your Zig projects.

## Overview

Ananke can be used in three ways:
1. **CLI Tool** - Standalone command-line tool (see QUICKSTART.md)
2. **Zig Library** - Import as a module in your Zig projects (this guide)
3. **Language Bindings** - C API for integration with other languages (coming soon)

## Quick Start

### 1. Project Setup

Create a new Zig project or use an existing one:

```bash
mkdir my-analyzer
cd my-analyzer
```

Create a basic project structure:
```
my-analyzer/
├── build.zig
├── build.zig.zon  (optional, for dependency management)
└── src/
    └── main.zig
```

### 2. Add Ananke Dependency

**Option A: Local Path (Development)**

In your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my-analyzer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add Ananke as a dependency using local path
    const ananke_path = "../ananke"; // Adjust to your path
    const ananke_module = b.addModule("ananke", .{
        .root_source_file = b.path(b.fmt("{s}/src/root.zig", .{ananke_path})),
    });
    exe.root_module.addImport("ananke", ananke_module);

    // Link tree-sitter (required for AST parsing)
    exe.linkSystemLibrary("tree-sitter");
    exe.linkLibC();

    b.installArtifact(exe);
}
```

**Option B: Package Manager (Production)**

Using Zig's package manager (coming soon):

```zig
// In build.zig.zon
.{
    .name = "my-analyzer",
    .version = "0.1.0",
    .dependencies = .{
        .ananke = .{
            .url = "https://github.com/your-org/ananke/archive/main.tar.gz",
            .hash = "...",
        },
    },
}
```

### 3. Basic Usage Example

Create `src/main.zig`:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Library Example ===\n\n", .{});

    // Read source code to analyze
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "sample.ts",
        1024 * 1024,
    );
    defer allocator.free(source);

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Extract constraints from TypeScript code
    const constraints = try ananke_instance.extract(source, "typescript");
    defer constraints.deinit();

    // Print results
    std.debug.print("Found {} constraints:\n", .{constraints.constraints.items.len});
    for (constraints.constraints.items) |constraint| {
        std.debug.print("  - {s}: {s}\n", .{
            constraint.name,
            constraint.description,
        });
    }
}
```

### 4. Build and Run

```bash
# Build your project
zig build

# Run it
./zig-out/bin/my-analyzer
```

## Advanced Usage

### Extract Constraints

```zig
// Extract from TypeScript
const ts_constraints = try ananke_instance.extract(ts_source, "typescript");
defer ts_constraints.deinit();

// Extract from Python
const py_constraints = try ananke_instance.extract(py_source, "python");
defer py_constraints.deinit();

// Supported languages: typescript, python, rust, go, zig, kotlin
```

### Compile Constraints to IR

```zig
// Compile constraints to intermediate representation
const ir = try ananke_instance.compile(constraints.constraints.items);

// Access IR components
std.debug.print("Priority: {d}\n", .{ir.priority});
std.debug.print("Grammar rules: {d}\n", .{ir.grammar.rules.len});

// Serialize IR to JSON
const json = try std.json.stringifyAlloc(
    allocator,
    ir,
    .{ .whitespace = .indent_2 },
);
defer allocator.free(json);
std.debug.print("{s}\n", .{json});
```

### Merge Multi-Language Constraints

```zig
// Extract from multiple languages
const ts_constraints = try ananke_instance.extract(ts_source, "typescript");
defer ts_constraints.deinit();

const py_constraints = try ananke_instance.extract(py_source, "python");
defer py_constraints.deinit();

// Merge into single constraint set
var merged = ananke.ConstraintSet.init(allocator, "multi_language");
defer merged.deinit();

for (ts_constraints.constraints.items) |c| {
    try merged.add(c);
}
for (py_constraints.constraints.items) |c| {
    try merged.add(c);
}

// Compile merged constraints
const unified_ir = try ananke_instance.compile(merged.constraints.items);
```

### Custom Constraint Creation

```zig
// Create custom constraints programmatically
var custom_set = ananke.ConstraintSet.init(allocator, "custom_rules");
defer custom_set.deinit();

const constraint = ananke.Constraint{
    .kind = .syntactic,
    .severity = .warning,
    .name = "no_var_keyword",
    .description = "Use 'const' or 'let' instead of 'var'",
    .source = .User_Defined,
    .confidence = 1.0,
};

try custom_set.add(constraint);

// Compile custom constraints
const ir = try ananke_instance.compile(custom_set.constraints.items);
```

## Complete Example: Code Analyzer

Here's a complete example that extracts constraints and generates a validation report:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read TypeScript file
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "app.ts",
        1024 * 1024,
    );
    defer allocator.free(source);

    // Initialize Ananke
    var analyzer = try ananke.Ananke.init(allocator);
    defer analyzer.deinit();

    // Extract constraints
    const constraints = try analyzer.extract(source, "typescript");
    defer constraints.deinit();

    // Print analysis report
    std.debug.print("=== Code Analysis Report ===\n\n", .{});
    std.debug.print("File: app.ts\n", .{});
    std.debug.print("Constraints Found: {}\n\n", .{constraints.constraints.items.len});

    // Categorize by kind
    var syntactic: u32 = 0;
    var type_safety: u32 = 0;
    var semantic: u32 = 0;

    for (constraints.constraints.items) |c| {
        switch (c.kind) {
            .syntactic => syntactic += 1,
            .type_safety => type_safety += 1,
            .semantic => semantic += 1,
            else => {},
        }
    }

    std.debug.print("Breakdown:\n", .{});
    std.debug.print("  Syntactic:   {}\n", .{syntactic});
    std.debug.print("  Type Safety: {}\n", .{type_safety});
    std.debug.print("  Semantic:    {}\n", .{semantic});
    std.debug.print("\n", .{});

    // Compile to IR
    const ir = try analyzer.compile(constraints.constraints.items);
    std.debug.print("Compiled to IR:\n", .{});
    std.debug.print("  Priority: {}\n", .{ir.priority});
    std.debug.print("  Grammar Rules: {}\n", .{ir.grammar.rules.len});
}
```

## API Reference

### Core Types

#### `Ananke`

Main analyzer instance.

```zig
pub const Ananke = struct {
    pub fn init(allocator: std.mem.Allocator) !Ananke;
    pub fn deinit(self: *Ananke) void;
    pub fn extract(self: *Ananke, source: []const u8, language: []const u8) !ConstraintSet;
    pub fn compile(self: *Ananke, constraints: []const Constraint) !ConstraintIR;
};
```

#### `ConstraintSet`

Collection of constraints with metadata.

```zig
pub const ConstraintSet = struct {
    name: []const u8,
    constraints: std.ArrayList(Constraint),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) ConstraintSet;
    pub fn deinit(self: *ConstraintSet) void;
    pub fn add(self: *ConstraintSet, constraint: Constraint) !void;
    pub fn clone(self: *const ConstraintSet, allocator: std.mem.Allocator) !ConstraintSet;
};
```

#### `Constraint`

Individual constraint definition.

```zig
pub const Constraint = struct {
    id: u32 = 0,
    kind: ConstraintKind,
    severity: Severity,
    name: []const u8,
    description: []const u8,
    source: ConstraintSource,
    enforcement: EnforcementLevel = .Semantic,
    priority: ConstraintPriority = .Medium,
    confidence: f32 = 1.0,
    frequency: u32 = 1,
    origin_line: ?u32 = null,
};
```

#### `ConstraintIR`

Compiled intermediate representation for llguidance.

```zig
pub const ConstraintIR = struct {
    priority: u32,
    json_schema: ?std.json.Value,
    grammar: Grammar,
    regex_patterns: []const RegexPattern,
    token_masks: ?TokenMasks,
};
```

### Enumerations

#### `ConstraintKind`

```zig
pub const ConstraintKind = enum {
    syntactic,      // Code structure and syntax
    type_safety,    // Type system constraints
    semantic,       // Meaning and behavior
    architectural,  // High-level design
    operational,    // Runtime and performance
    security,       // Security requirements
};
```

#### `Severity`

```zig
pub const Severity = enum {
    err,      // Must fix
    warning,  // Should fix
    info,     // Informational
    hint,     // Suggestion
};
```

#### `ConstraintSource`

```zig
pub const ConstraintSource = enum {
    AST_Pattern,   // Extracted from AST patterns
    Type_System,   // Inferred from type annotations
    Control_Flow,  // Derived from control flow
    LLM_Analysis,  // AI-powered semantic analysis
    Test_Mining,   // Extracted from test assertions
    Telemetry,     // Runtime telemetry data
    User_Defined,  // Manually specified
};
```

## Memory Management

Ananke follows Zig's manual memory management principles:

### Ownership Rules

1. **You own what you allocate**: If you create a `ConstraintSet`, you must call `deinit()`
2. **Extracted constraints**: `extract()` returns owned data - caller must `deinit()`
3. **Arena pattern for JSON**: Use arena allocators when parsing JSON constraints (see compile command source)

### Example with Proper Cleanup

```zig
pub fn analyzeFiles(allocator: std.mem.Allocator) !void {
    // Initialize analyzer
    var analyzer = try ananke.Ananke.init(allocator);
    defer analyzer.deinit(); // Cleanup #1

    // Read source
    const source = try std.fs.cwd().readFileAlloc(allocator, "app.ts", 1024 * 1024);
    defer allocator.free(source); // Cleanup #2

    // Extract constraints
    const constraints = try analyzer.extract(source, "typescript");
    defer constraints.deinit(); // Cleanup #3

    // Use constraints...
    for (constraints.constraints.items) |c| {
        std.debug.print("{s}\n", .{c.name});
    }

    // All memory automatically freed by defers in reverse order
}
```

### Arena Allocator Pattern

For large batches of constraints, use an arena:

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit(); // Frees everything at once
const arena_allocator = arena.allocator();

// Parse many constraints using arena
const constraints = try parseConstraintsJson(arena_allocator, json_data);
// No need to individually free constraint strings - arena handles it
```

## Troubleshooting

### Build Errors

**Error: `tree-sitter` not found**

```bash
# macOS (Homebrew)
brew install tree-sitter

# Ubuntu/Debian
sudo apt-get install libtree-sitter-dev

# Arch Linux
sudo pacman -S tree-sitter
```

**Error: `no field named 'root_source_file'`**

You're using old Zig API. Update to Zig 0.15.0+ and use:

```zig
// Old (Zig 0.13)
.root_source_file = .{ .path = "src/main.zig" },

// New (Zig 0.15+)
.root_source_file = b.path("src/main.zig"),
```

### Runtime Issues

**Memory Leaks Detected**

Ensure all `deinit()` calls are in place:

```zig
var analyzer = try ananke.Ananke.init(allocator);
defer analyzer.deinit(); // Don't forget this!

const constraints = try analyzer.extract(source, "typescript");
defer constraints.deinit(); // And this!
```

**Language Not Supported**

Check supported languages:

```zig
// Fully supported: typescript, python, rust, go, zig
// Fallback support: kotlin, java, cpp (pattern-based only)
```

For unsupported languages, Ananke falls back to pattern matching.

## Examples

See the `examples/` directory for complete working examples:

- `examples/01-simple-extraction/` - Basic constraint extraction
- `examples/02-full-pipeline/` - Extract → Compile → Generate workflow
- `examples/03-custom-constraints/` - Creating custom constraint rules
- `examples/04-multi-language/` - Analyzing multiple languages
- `examples/05-production/` - Production-ready analyzer with error handling

## Performance Considerations

### Caching

Ananke automatically caches extraction results for identical source code:

```zig
// First call: ~10ms (parses source)
const constraints1 = try analyzer.extract(source, "typescript");
defer constraints1.deinit();

// Second call with same source: ~0.3ms (cache hit, 30x faster)
const constraints2 = try analyzer.extract(source, "typescript");
defer constraints2.deinit();
```

### Batch Processing

For analyzing many files, reuse the Ananke instance:

```zig
var analyzer = try ananke.Ananke.init(allocator);
defer analyzer.deinit();

for (files) |file| {
    const source = try std.fs.cwd().readFileAlloc(allocator, file, 1024 * 1024);
    defer allocator.free(source);

    const constraints = try analyzer.extract(source, language);
    defer constraints.deinit();

    // Process constraints...
}
```

### Memory Usage

- Extraction: ~2-5MB per file (depends on file size)
- Caching: ~500KB per cached file
- Compilation: ~1-2MB for IR generation

## Further Reading

- [QUICKSTART.md](../QUICKSTART.md) - CLI tool usage
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System design overview
- [API.md](../API.md) - Complete API reference
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Development guide
