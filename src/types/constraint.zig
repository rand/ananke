// Core constraint types for the Ananke system
const std = @import("std");

/// Categories of constraints that can be extracted and enforced
pub const ConstraintKind = enum {
    syntactic,    // Code structure, formatting, naming
    type_safety,  // Type annotations, null safety, generics
    semantic,     // Data flow, control flow, side effects
    architectural, // Module boundaries, dependencies, layering
    operational,  // Performance, memory, concurrency
    security,     // Input validation, auth, dangerous ops
};

/// Severity levels for constraint violations
pub const Severity = enum {
    err,     // Must be fixed (renamed from 'error' which is reserved)
    warning, // Should be addressed
    info,    // Informational
    hint,    // Suggestion
};

/// A single constraint that can be validated
pub const Constraint = struct {
    kind: ConstraintKind,
    severity: Severity,
    name: []const u8,
    description: []const u8,

    // Function pointers for constraint operations (typed holes)
    validate: ?*const fn (token: []const u8) bool = null,
    compile: ?*const fn (self: *const Constraint) ConstraintIR = null,

    // Metadata
    source: ConstraintSource,
    confidence: f32 = 1.0, // 0.0 to 1.0

    pub fn init(kind: ConstraintKind, name: []const u8) Constraint {
        return .{
            .kind = kind,
            .severity = .err,
            .name = name,
            .description = "",
            .source = .{ .static_analysis = {} },
        };
    }
};

/// Source of a constraint
pub const ConstraintSource = union(enum) {
    static_analysis: void,
    test_mining: TestSource,
    telemetry: TelemetrySource,
    llm_analysis: LLMSource,
    user_defined: void,
};

pub const TestSource = struct {
    file_path: []const u8,
    line_number: u32,
};

pub const TelemetrySource = struct {
    metric_name: []const u8,
    threshold: f64,
};

pub const LLMSource = struct {
    provider: []const u8,
    prompt: []const u8,
    confidence: f32,
};

/// Compiled constraint representation for efficient validation
pub const ConstraintIR = struct {
    /// JSON Schema for structured constraints
    json_schema: ?JsonSchema = null,

    /// Context-free grammar for syntax constraints
    grammar: ?Grammar = null,

    /// Regular expression patterns
    regex_patterns: []const Regex = &.{},

    /// Direct token masking rules
    token_masks: ?TokenMaskRules = null,

    /// Priority for conflict resolution
    priority: u32 = 0,

    /// Serialize to format compatible with llguidance
    pub fn serialize(self: ConstraintIR, allocator: std.mem.Allocator) ![]u8 {
        // TODO: Implement serialization to llguidance format
        _ = allocator;
        _ = self;
        return error.NotImplemented;
    }
};

/// JSON Schema representation
pub const JsonSchema = struct {
    type: []const u8,
    properties: ?std.json.ObjectMap = null,
    required: []const []const u8 = &.{},
    additional_properties: bool = true,
};

/// Context-free grammar
pub const Grammar = struct {
    rules: []const GrammarRule,
    start_symbol: []const u8,
};

pub const GrammarRule = struct {
    lhs: []const u8,
    rhs: []const []const u8,
};

/// Regular expression pattern
pub const Regex = struct {
    pattern: []const u8,
    flags: []const u8 = "",
};

/// Token masking rules for llguidance
pub const TokenMaskRules = struct {
    allowed_tokens: ?[]const u32 = null,
    forbidden_tokens: ?[]const u32 = null,

    /// Apply mask to token probabilities
    pub fn apply(self: TokenMaskRules, logits: []f32) void {
        if (self.forbidden_tokens) |forbidden| {
            for (forbidden) |token_id| {
                logits[token_id] = -std.math.inf(f32);
            }
        }

        if (self.allowed_tokens) |allowed| {
            // Set all non-allowed tokens to -inf
            for (logits, 0..) |*logit, i| {
                var is_allowed = false;
                for (allowed) |token_id| {
                    if (i == token_id) {
                        is_allowed = true;
                        break;
                    }
                }
                if (!is_allowed) {
                    logit.* = -std.math.inf(f32);
                }
            }
        }
    }
};

/// A collection of constraints
pub const ConstraintSet = struct {
    constraints: std.ArrayList(Constraint),
    name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) ConstraintSet {
        return .{
            .constraints = std.ArrayList(Constraint){},
            .name = name,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConstraintSet) void {
        self.constraints.deinit(self.allocator);
    }

    pub fn add(self: *ConstraintSet, constraint: Constraint) !void {
        try self.constraints.append(self.allocator, constraint);
    }

    pub fn compile(self: ConstraintSet, allocator: std.mem.Allocator) !ConstraintIR {
        // TODO: Implement constraint compilation
        _ = allocator;
        _ = self;
        return error.NotImplemented;
    }
};