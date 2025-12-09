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
            std.mem.indexOf(u8, input, "generate") != null)
        {
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

    /// Session ID buffer (stack allocated)
    session_id_buf: [37]u8 = undefined,

    pub fn init() IntentMetadata {
        var meta: IntentMetadata = .{
            .timestamp = std.time.timestamp(),
            .session_id = undefined,
        };
        meta.session_id = generateSessionId(&meta.session_id_buf);
        return meta;
    }

    /// Generate a UUID v4 style session ID
    /// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    /// where y is one of 8, 9, a, or b
    fn generateSessionId(buf: *[37]u8) []const u8 {
        var random_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        // Set version 4 (0100) in bits 12-15 of time_hi_and_version
        random_bytes[6] = (random_bytes[6] & 0x0f) | 0x40;

        // Set variant (10) in bits 6-7 of clock_seq_hi_and_reserved
        random_bytes[8] = (random_bytes[8] & 0x3f) | 0x80;

        // Format as UUID string
        const hex_chars = "0123456789abcdef";
        var i: usize = 0;
        var buf_idx: usize = 0;

        // First group: 8 chars (4 bytes)
        while (i < 4) : (i += 1) {
            buf[buf_idx] = hex_chars[random_bytes[i] >> 4];
            buf[buf_idx + 1] = hex_chars[random_bytes[i] & 0x0f];
            buf_idx += 2;
        }
        buf[buf_idx] = '-';
        buf_idx += 1;

        // Second group: 4 chars (2 bytes)
        while (i < 6) : (i += 1) {
            buf[buf_idx] = hex_chars[random_bytes[i] >> 4];
            buf[buf_idx + 1] = hex_chars[random_bytes[i] & 0x0f];
            buf_idx += 2;
        }
        buf[buf_idx] = '-';
        buf_idx += 1;

        // Third group: 4 chars (2 bytes)
        while (i < 8) : (i += 1) {
            buf[buf_idx] = hex_chars[random_bytes[i] >> 4];
            buf[buf_idx + 1] = hex_chars[random_bytes[i] & 0x0f];
            buf_idx += 2;
        }
        buf[buf_idx] = '-';
        buf_idx += 1;

        // Fourth group: 4 chars (2 bytes)
        while (i < 10) : (i += 1) {
            buf[buf_idx] = hex_chars[random_bytes[i] >> 4];
            buf[buf_idx + 1] = hex_chars[random_bytes[i] & 0x0f];
            buf_idx += 2;
        }
        buf[buf_idx] = '-';
        buf_idx += 1;

        // Fifth group: 12 chars (6 bytes)
        while (i < 16) : (i += 1) {
            buf[buf_idx] = hex_chars[random_bytes[i] >> 4];
            buf[buf_idx + 1] = hex_chars[random_bytes[i] & 0x0f];
            buf_idx += 2;
        }
        buf[buf_idx] = 0; // Null terminate

        return buf[0..36];
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
