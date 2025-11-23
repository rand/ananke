// Intent representation for the Ananke system
const std = @import("std");

/// User intent format
pub const IntentFormat = enum {
    natural_language,
    json,
    yaml,
    ariadne,
};

/// Represents user intent for code generation
pub const Intent = struct {
    /// Raw input from user
    raw_input: []const u8,

    /// Parsed intent format
    format: IntentFormat,

    /// Extracted prompt for generation
    prompt: []const u8,

    /// Context information
    context: Context,

    /// Metadata
    metadata: IntentMetadata,

    pub fn init(input: []const u8) Intent {
        return .{
            .raw_input = input,
            .format = detectFormat(input),
            .prompt = input, // Initially same as input
            .context = Context.init(),
            .metadata = IntentMetadata.init(),
        };
    }

    fn detectFormat(input: []const u8) IntentFormat {
        // Simple format detection
        if (std.mem.startsWith(u8, input, "{")) {
            return .json;
        } else if (std.mem.indexOf(u8, input, "---") != null) {
            return .yaml;
        } else if (std.mem.indexOf(u8, input, "constraint") != null and
                   std.mem.indexOf(u8, input, "generate") != null) {
            return .ariadne;
        }
        return .natural_language;
    }
};

/// Context for intent enrichment
pub const Context = struct {
    /// Current file being edited
    current_file: ?[]const u8 = null,

    /// Selected code region
    selection: ?CodeSelection = null,

    /// Recent edits for context
    recent_edits: []const Edit = &.{},

    /// Project information
    project_info: ?ProjectInfo = null,

    pub fn init() Context {
        return .{};
    }
};

pub const CodeSelection = struct {
    file_path: []const u8,
    start_line: u32,
    end_line: u32,
    content: []const u8,
};

pub const Edit = struct {
    timestamp: i64,
    file_path: []const u8,
    change_type: enum { add, modify, delete },
};

pub const ProjectInfo = struct {
    root_path: []const u8,
    language: []const u8,
    framework: ?[]const u8 = null,
    dependencies: []const []const u8 = &.{},
};

/// Intent metadata
pub const IntentMetadata = struct {
    /// Timestamp of intent creation
    timestamp: i64,

    /// User identifier (if available)
    user_id: ?[]const u8 = null,

    /// Session identifier
    session_id: []const u8,

    /// Priority level
    priority: Priority = .normal,

    pub fn init() IntentMetadata {
        return .{
            .timestamp = std.time.timestamp(),
            .session_id = generateSessionId(),
        };
    }

    fn generateSessionId() []const u8 {
        // TODO: Implement proper session ID generation
        return "session-default";
    }
};

pub const Priority = enum {
    low,
    normal,
    high,
    critical,
};

/// Compiled intent representation
pub const IntentIR = struct {
    /// Core generation prompt
    prompt: []const u8,

    /// Extracted parameters
    parameters: std.StringHashMap(std.json.Value),

    /// Constraints to apply
    constraint_refs: []const []const u8,

    /// Target context
    target: GenerationTarget,

    pub fn init(allocator: std.mem.Allocator) IntentIR {
        return .{
            .prompt = "",
            .parameters = std.StringHashMap(std.json.Value).init(allocator),
            .constraint_refs = &.{},
            .target = .{ .new_file = "generated.zig" },
        };
    }

    pub fn deinit(self: *IntentIR) void {
        self.parameters.deinit();
    }
};

/// Target for code generation
pub const GenerationTarget = union(enum) {
    new_file: []const u8,
    insert_at: InsertLocation,
    replace: ReplaceLocation,
    modify_function: []const u8,
    modify_class: []const u8,
};

pub const InsertLocation = struct {
    file_path: []const u8,
    line: u32,
};

pub const ReplaceLocation = struct {
    file_path: []const u8,
    start_line: u32,
    end_line: u32,
};

/// Intent processor interface
pub const IntentProcessor = struct {
    /// Parse intent from various formats
    parse: *const fn (input: []const u8, format: IntentFormat) anyerror!Intent,

    /// Enrich intent with context
    enrich: *const fn (intent: *Intent, context: Context) anyerror!void,

    /// Compile to IntentIR
    compile: *const fn (intent: Intent, allocator: std.mem.Allocator) anyerror!IntentIR,

    /// Validate intent
    validate: *const fn (intent: Intent) anyerror!bool,
};