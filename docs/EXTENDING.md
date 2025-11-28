# Extending Ananke

This guide covers how to extend Ananke with new constraint types, language support, and custom extractors.

## Table of Contents

- [Overview](#overview)
- [Adding New Constraint Types](#adding-new-constraint-types)
- [Adding Language Support](#adding-language-support)
- [Creating Custom Extractors](#creating-custom-extractors)
- [Contributing Patterns](#contributing-patterns)
- [Testing Extensions](#testing-extensions)
- [Performance Considerations](#performance-considerations)

---

## Overview

Ananke's architecture supports several extension points:

```
Clew (Extraction)
├── Language Parsers: Add lexical/syntactic analyzers
├── Pattern Library: Add constraint detection patterns
└── Custom Extractors: Add domain-specific constraint mining

Braid (Compilation)
├── IR Components: Extend ConstraintIR with new constraint types
├── Validators: Add constraint-specific validation logic
└── Optimizers: Improve compilation for specific patterns

Ariadne (DSL)
├── Grammar: Extend DSL syntax for new constraint types
└── Semantic Actions: Add compilation rules for new syntax
```

---

## Adding New Constraint Types

### Step 1: Define Constraint Kind

Edit `/Users/rand/src/ananke/src/types/constraint.zig`:

```zig
pub const ConstraintKind = enum {
    // Existing types...
    type_safety,
    security,
    performance,
    
    // Add your new type here
    custom_rule,  // Your new constraint kind
};
```

### Step 2: Define Constraint Structure

In the same file, add a structure for your constraint:

```zig
pub const CustomRule = struct {
    /// Rule identifier (e.g., "custom_rule_1")
    id: []const u8,
    
    /// Human-readable description
    description: []const u8,
    
    /// Rule expression or pattern
    rule_expr: []const u8,
    
    /// Severity level
    severity: ConstraintSeverity = .warning,
    
    /// Whether this rule is enforced
    enabled: bool = true,
};
```

### Step 3: Add to ConstraintIR

Update the `ConstraintIR` union to handle your constraint:

```zig
pub const ConstraintIR = union(ConstraintKind) {
    // Existing types...
    type_safety: JsonSchema,
    security: Grammar,
    performance: TokenMaskRules,
    
    // Add your new IR representation
    custom_rule: CustomRuleIR,
};
```

### Step 4: Implement Compilation Logic

In `/Users/rand/src/ananke/src/braid/braid.zig`, add compilation for your constraint:

```zig
pub fn compileCustomRule(
    self: *Braid,
    rule: CustomRule,
) !CustomRuleIR {
    // Validate the rule
    try self.validateCustomRule(rule);
    
    // Compile to IR representation
    const ir = try self.customRuleToIR(rule);
    
    return ir;
}

fn validateCustomRule(self: *Braid, rule: CustomRule) !void {
    if (rule.rule_expr.len == 0) {
        return error.EmptyRuleExpression;
    }
    
    // Add custom validation logic
    // ...
}

fn customRuleToIR(self: *Braid, rule: CustomRule) !CustomRuleIR {
    // Translate rule expression to IR
    // ...
}
```

### Step 5: Add Tests

Create a test file `/Users/rand/src/braid/custom_rule_test.zig`:

```zig
const std = @import("std");
const ananke = @import("ananke");

const Braid = ananke.braid.Braid;
const CustomRule = ananke.types.constraint.CustomRule;

test "compile custom rule successfully" {
    const allocator = std.testing.allocator;
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const rule = CustomRule{
        .id = "test_rule",
        .description = "Test custom rule",
        .rule_expr = "pattern matches input",
        .severity = .error,
    };
    
    const ir = try braid.compileCustomRule(rule);
    defer ir.deinit();
    
    try std.testing.expect(ir.enabled);
}

test "custom rule validation catches invalid rules" {
    const allocator = std.testing.allocator;
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const invalid_rule = CustomRule{
        .id = "invalid",
        .description = "Invalid rule",
        .rule_expr = "",  // Empty expression should fail
    };
    
    try std.testing.expectError(
        error.EmptyRuleExpression,
        braid.compileCustomRule(invalid_rule)
    );
}
```

### Step 6: Document the Constraint Type

Add documentation to `/Users/rand/src/ananke/docs/PATTERN_REFERENCE.md`:

```markdown
## Custom Rules

Custom rules allow you to enforce arbitrary constraints on generated code.

### Syntax

```json
{
  "kind": "custom_rule",
  "id": "rule_name",
  "description": "What this rule enforces",
  "rule_expr": "pattern or expression",
  "severity": "error|warning|info",
  "enabled": true
}
```

### Example

```json
{
  "kind": "custom_rule",
  "id": "no_globals",
  "description": "Forbids global variable declarations",
  "rule_expr": "forbid global_var_declaration",
  "severity": "error"
}
```

### Validation

Custom rules are validated at compile time. Invalid expressions will cause compilation to fail with a descriptive error message.
```

---

## Adding Language Support

### Step 1: Implement Language Parser

Create `/Users/rand/src/ananke/src/clew/parsers/your_language.zig`:

```zig
const std = @import("std");

/// Parser for your language
pub const YourLanguageParser = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) YourLanguageParser {
        return .{ .allocator = allocator };
    }
    
    /// Tokenize source code
    pub fn tokenize(self: YourLanguageParser, source: []const u8) ![]Token {
        var tokens = std.ArrayList(Token).init(self.allocator);
        defer tokens.deinit();
        
        var i: usize = 0;
        while (i < source.len) {
            const token = try self.nextToken(source, &i);
            try tokens.append(token);
        }
        
        return tokens.toOwnedSlice();
    }
    
    /// Parse single token
    fn nextToken(self: YourLanguageParser, source: []const u8, pos: *usize) !Token {
        // Skip whitespace
        while (pos.* < source.len and std.ascii.isWhitespace(source[pos.*])) {
            pos.* += 1;
        }
        
        if (pos.* >= source.len) {
            return Token{ .kind = .eof };
        }
        
        const start = pos.*;
        const char = source[pos.*];
        
        // Implement language-specific tokenization
        if (std.ascii.isAlpha(char)) {
            // Parse identifier or keyword
            while (pos.* < source.len and 
                   (std.ascii.isAlphaNumeric(source[pos.*]) or source[pos.*] == '_')) {
                pos.* += 1;
            }
            
            const text = source[start..pos.*];
            return Token{
                .kind = .identifier,
                .text = text,
            };
        }
        
        // Handle other token types...
        pos.* += 1;
        return Token{ .kind = .unknown };
    }
};

pub const Token = struct {
    kind: TokenKind,
    text: []const u8 = "",
    line: usize = 0,
    column: usize = 0,
};

pub const TokenKind = enum {
    identifier,
    keyword,
    number,
    string,
    symbol,
    eof,
    unknown,
};
```

### Step 2: Register Language

In `/Users/rand/src/ananke/src/clew/clew.zig`, add to language detection:

```zig
pub fn getParser(allocator: std.mem.Allocator, language: []const u8) !Parser {
    if (std.mem.eql(u8, language, "your_language")) {
        return .{ .your_language = YourLanguageParser.init(allocator) };
    }
    
    return error.UnsupportedLanguage;
}

pub const Parser = union(enum) {
    typescript: TypeScriptParser,
    python: PythonParser,
    your_language: YourLanguageParser,
};
```

### Step 3: Implement Pattern Extractors

In `/Users/rand/src/ananke/src/clew/patterns/`, create language-specific patterns:

```zig
pub const YourLanguagePatterns = struct {
    pub fn extractFunctions(source: []const u8) ![]FunctionConstraint {
        // Parse function definitions and extract constraints
    }
    
    pub fn extractClasses(source: []const u8) ![]ClassConstraint {
        // Parse class definitions and extract constraints
    }
    
    pub fn extractTypeAnnotations(source: []const u8) ![]TypeConstraint {
        // Parse type annotations and extract constraints
    }
};
```

### Step 4: Add Language-Specific Tests

Create `/Users/rand/src/ananke/test/clew/your_language_test.zig`:

```zig
test "parse simple function in your language" {
    const allocator = std.testing.allocator;
    const source = "fn hello() { print('Hello'); }";  // Adjust for your language
    
    var parser = YourLanguageParser.init(allocator);
    defer parser.deinit();
    
    const constraints = try parser.extractConstraints(source);
    defer allocator.free(constraints);
    
    try std.testing.expect(constraints.len > 0);
}
```

### Step 5: Document Language Support

Update `/Users/rand/src/ananke/docs/USER_GUIDE.md`:

```markdown
### Supported Languages (v0.1.0)

| Language | Status | Notes |
|----------|--------|-------|
| TypeScript/JavaScript | Production | Full extraction support |
| Python | Production | Full extraction support |
| Your Language | Experimental | Community contribution |
```

---

## Creating Custom Extractors

### Use Case: Domain-Specific Constraint Mining

Example: Extract API constraints from OpenAPI specifications.

### Implementation

Create `/Users/rand/src/ananke/src/clew/extractors/openapi.zig`:

```zig
const std = @import("std");
const json = std.json;

pub const OpenAPIExtractor = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) OpenAPIExtractor {
        return .{ .allocator = allocator };
    }
    
    /// Extract API constraints from OpenAPI spec
    pub fn extract(self: OpenAPIExtractor, spec_json: []const u8) ![]Constraint {
        var constraints = std.ArrayList(Constraint).init(self.allocator);
        defer constraints.deinit();
        
        // Parse JSON
        var parser = json.Parser.init(self.allocator, false);
        defer parser.deinit();
        
        const root = try parser.parse(spec_json);
        defer root.deinit();
        
        // Extract from paths
        if (root.root.Object.get("paths")) |paths| {
            var path_iter = paths.Object.iterator();
            while (path_iter.next()) |entry| {
                try self.extractPathConstraints(entry.key_ptr.*, entry.value_ptr.*, &constraints);
            }
        }
        
        return constraints.toOwnedSlice();
    }
    
    fn extractPathConstraints(
        self: OpenAPIExtractor,
        path: []const u8,
        path_item: json.Value,
        constraints: *std.ArrayList(Constraint),
    ) !void {
        // Extract method constraints
        if (path_item.Object.get("get")) |get_op| {
            try self.extractOperationConstraints(path, "GET", get_op, constraints);
        }
        
        if (path_item.Object.get("post")) |post_op| {
            try self.extractOperationConstraints(path, "POST", post_op, constraints);
        }
    }
    
    fn extractOperationConstraints(
        self: OpenAPIExtractor,
        path: []const u8,
        method: []const u8,
        operation: json.Value,
        constraints: *std.ArrayList(Constraint),
    ) !void {
        // Extract request body constraints
        if (operation.Object.get("requestBody")) |req_body| {
            if (req_body.Object.get("content")) |content| {
                if (content.Object.get("application/json")) |json_content| {
                    if (json_content.Object.get("schema")) |schema| {
                        const constraint = Constraint{
                            .kind = .type_safety,
                            .source = .api_spec,
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "API {s} {s} request must match schema",
                                .{ method, path }
                            ),
                        };
                        try constraints.append(constraint);
                    }
                }
            }
        }
    }
};
```

### Register Custom Extractor

In `/Users/rand/src/ananke/src/clew/clew.zig`:

```zig
pub fn extractFromOpenAPI(self: *Clew, spec_json: []const u8) !ConstraintSet {
    var extractor = OpenAPIExtractor.init(self.allocator);
    defer extractor.deinit();
    
    const constraints = try extractor.extract(spec_json);
    defer self.allocator.free(constraints);
    
    var constraint_set = try ConstraintSet.init(self.allocator);
    for (constraints) |constraint| {
        try constraint_set.add(constraint);
    }
    
    return constraint_set;
}
```

---

## Contributing Patterns

### Pattern Library Structure

Patterns are pattern templates for common constraint types. Located in `/Users/rand/src/ananke/src/clew/patterns/`:

```zig
pub const PatternLibrary = struct {
    patterns: []Pattern,
    
    pub fn init(allocator: std.mem.Allocator) !PatternLibrary {
        var patterns = std.ArrayList(Pattern).init(allocator);
        
        // Register all built-in patterns
        try patterns.append(Pattern{
            .name = "null_check_required",
            .description = "Generate null-safe code",
            .regex = "// null-check: required",
        });
        
        return .{ .patterns = patterns.toOwnedSlice() };
    }
};

pub const Pattern = struct {
    name: []const u8,
    description: []const u8,
    regex: []const u8,
    examples: []Example = &[_]Example{},
};

pub const Example = struct {
    code: []const u8,
    extracted_constraints: [][]const u8,
};
```

### Contributing New Pattern

1. Add pattern to appropriate language file
2. Add test cases with code examples
3. Document pattern in PATTERN_REFERENCE.md
4. Submit PR with pattern + tests

---

## Testing Extensions

### Unit Test Template

```zig
test "my extension handles valid input" {
    const allocator = std.testing.allocator;
    
    // Setup
    var extension = try MyExtension.init(allocator);
    defer extension.deinit();
    
    // Test
    const input = "test input";
    const result = try extension.process(input);
    defer allocator.free(result);
    
    // Verify
    try std.testing.expectEqual(@as(usize, 1), result.len);
}

test "my extension rejects invalid input" {
    const allocator = std.testing.allocator;
    
    var extension = try MyExtension.init(allocator);
    defer extension.deinit();
    
    try std.testing.expectError(
        error.InvalidInput,
        extension.process("")
    );
}
```

### Integration Tests

```bash
# Extract constraints using custom language
zig build test -- "src/clew/your_language_test.zig"

# Compile custom constraints
zig build test -- "src/braid/custom_rule_test.zig"

# Full pipeline
zig build test -- "test/integration/custom_test.zig"
```

### Benchmarking

For performance-critical extensions, add benchmark:

```zig
const BenchTimer = struct {
    start: i64,
    
    fn start_time() BenchTimer {
        return .{ .start = std.time.milliTimestamp() };
    }
    
    fn elapsed_ms(self: BenchTimer) i64 {
        return std.time.milliTimestamp() - self.start;
    }
};

test "benchmark custom rule compilation" {
    const allocator = std.testing.allocator;
    const timer = BenchTimer.start_time();
    
    // ... run compilation N times ...
    
    std.debug.print("Compilation took {}ms\n", .{timer.elapsed_ms()});
}
```

---

## Performance Considerations

### Memory Management

Always consider allocator usage:

```zig
// BAD: Unbounded memory allocation
var all_constraints = std.ArrayList(Constraint).init(allocator);
for (0..10000) |_| {
    try all_constraints.append(constraint);  // Could OOM
}

// GOOD: Stream processing
for (chunks) |chunk| {
    var constraints = try extractConstraints(allocator, chunk);
    defer constraints.deinit();
    try processConstraints(constraints);
}
```

### Caching Strategy

Implement caching for expensive operations:

```zig
pub const CachedExtractor = struct {
    cache: std.StringHashMap([]Constraint),
    
    pub fn extractCached(self: *CachedExtractor, source: []const u8) ![]Constraint {
        // Check cache first
        if (self.cache.get(source)) |cached| {
            return cached;
        }
        
        // Extract and cache
        const result = try self.extract(source);
        try self.cache.put(source, result);
        return result;
    }
};
```

### Complexity Analysis

For new algorithms, document complexity:

- **Extraction**: O(n) where n = source code length
- **Compilation**: O(c²) worst case where c = constraint count
- **Validation**: O(k) where k = constraint rule count

Use topological sort (O(n log n)) for optimization.

---

## Examples

See complete examples in `/Users/rand/src/ananke/examples/`:

- **01-simple-extraction**: Basic constraint extraction
- **02-claude-analysis**: LLM-enhanced extraction
- **03-ariadne-dsl**: Custom DSL constraints
- **04-full-pipeline**: Complete workflow

---

## Getting Help

- **Documentation**: See /docs/ for comprehensive guides
- **Issues**: Report bugs on GitHub
- **Discussions**: Ask questions in GitHub Discussions
- **Community**: Join our community for support

---

**Guide Version**: 0.1.0  
**Last Updated**: November 2025
