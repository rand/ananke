//! Pipeline Runner for E2E Tests
//!
//! Provides infrastructure for running the full Ananke pipeline:
//! - Extract constraints from source code (Clew)
//! - Compile constraints to IR (Braid)
//! - Generate code via Modal (optional, requires ANANKE_MODAL_ENDPOINT)
//! - Validate generated code satisfies constraints

const std = @import("std");
const ananke = @import("ananke");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;

const Allocator = std.mem.Allocator;
const Constraint = ananke.Constraint;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;

/// Pipeline configuration
pub const PipelineConfig = struct {
    /// Modal endpoint URL (optional, for generation testing)
    modal_endpoint: ?[]const u8 = null,

    /// Timeout for Modal requests in milliseconds
    timeout_ms: u64 = 30000,

    /// Enable verbose logging
    verbose: bool = false,

    /// Read Modal endpoint from environment
    pub fn fromEnv(allocator: Allocator) !PipelineConfig {
        var config = PipelineConfig{};

        // Try to read ANANKE_MODAL_ENDPOINT from environment
        if (std.process.getEnvVarOwned(allocator, "ANANKE_MODAL_ENDPOINT")) |endpoint| {
            config.modal_endpoint = endpoint;
        } else |_| {
            // Environment variable not set, Modal tests will be skipped
            config.modal_endpoint = null;
        }

        return config;
    }
};

/// Result from running the full pipeline
pub const PipelineResult = struct {
    /// Extracted constraints
    constraints: ConstraintSet,

    /// Compiled IR
    ir: ConstraintIR,

    /// Generated code (if Modal endpoint available)
    generated_code: ?[]const u8 = null,

    /// Generation metadata
    generation_metadata: ?GenerationMetadata = null,

    pub fn deinit(self: *PipelineResult, allocator: Allocator) void {
        self.constraints.deinit();
        self.ir.deinit(allocator);
        if (self.generated_code) |code| {
            allocator.free(code);
        }
    }
};

/// Metadata from code generation
pub const GenerationMetadata = struct {
    /// Time taken for generation (milliseconds)
    generation_time_ms: u64,

    /// Number of tokens generated
    tokens_generated: usize,

    /// Whether constraints were satisfied
    constraints_satisfied: bool,

    /// Model used for generation
    model_name: []const u8,
};

/// Validation result for generated code
pub const ValidationResult = struct {
    /// Whether all constraints are satisfied
    all_satisfied: bool,

    /// List of satisfied constraint names
    satisfied: []const []const u8,

    /// List of violated constraint names
    violated: []const []const u8,

    /// Validation errors
    errors: []const []const u8,
};

/// Pipeline runner for E2E testing
pub const PipelineRunner = struct {
    allocator: Allocator,
    config: PipelineConfig,
    clew: *Clew,
    braid: *Braid,

    /// Initialize pipeline runner
    pub fn init(allocator: Allocator, config: PipelineConfig) !*PipelineRunner {
        const runner = try allocator.create(PipelineRunner);

        const clew = try allocator.create(Clew);
        clew.* = try Clew.init(allocator);

        const braid = try allocator.create(Braid);
        braid.* = try Braid.init(allocator);

        runner.* = PipelineRunner{
            .allocator = allocator,
            .config = config,
            .clew = clew,
            .braid = braid,
        };

        return runner;
    }

    /// Clean up pipeline runner
    pub fn deinit(self: *PipelineRunner) void {
        self.clew.deinit();
        self.allocator.destroy(self.clew);

        self.braid.deinit();
        self.allocator.destroy(self.braid);

        self.allocator.destroy(self);
    }

    /// Run the full pipeline: extract → compile → (optionally) generate
    pub fn runFullPipeline(
        self: *PipelineRunner,
        source_file: []const u8,
        intent: ?[]const u8,
    ) !PipelineResult {
        // Detect language from file extension
        const language = detectLanguage(source_file) orelse
            return error.UnknownLanguage;

        // Read source file
        const source = try std.fs.cwd().readFileAlloc(
            self.allocator,
            source_file,
            10 * 1024 * 1024, // 10MB max
        );
        defer self.allocator.free(source);

        if (self.config.verbose) {
            std.debug.print("Extracting constraints from {s} ({s})...\n", .{ source_file, @tagName(language) });
        }

        // Extract constraints
        var constraints = try self.clew.extractFromCode(source, language);
        errdefer constraints.deinit();

        if (self.config.verbose) {
            std.debug.print("Extracted {} constraints\n", .{constraints.constraints.items.len});
        }

        // Compile to IR
        const ir = try self.braid.compile(constraints.constraints.items);
        errdefer ir.deinit(self.allocator);

        if (self.config.verbose) {
            std.debug.print("Compiled to IR (priority: {})\n", .{ir.priority});
        }

        // Initialize result
        var result = PipelineResult{
            .constraints = constraints,
            .ir = ir,
        };

        // If Modal endpoint is available and intent is provided, generate code
        if (self.config.modal_endpoint != null and intent != null) {
            if (self.config.verbose) {
                std.debug.print("Generating code via Modal...\n", .{});
            }

            // TODO: Implement Modal API call
            // For now, this is a placeholder - actual Modal integration
            // would require HTTP client and JSON handling
            result.generated_code = null;
            result.generation_metadata = null;
        }

        return result;
    }

    /// Validate that generated code satisfies constraints
    pub fn validateGenerated(
        self: *PipelineRunner,
        generated_code: []const u8,
        constraints: []const Constraint,
    ) !ValidationResult {
        _ = self;
        _ = generated_code;
        _ = constraints;

        // TODO: Implement constraint validation
        // This would involve re-running extraction on generated code
        // and comparing against original constraints

        return ValidationResult{
            .all_satisfied = true,
            .satisfied = &.{},
            .violated = &.{},
            .errors = &.{},
        };
    }
};

/// Detect language from file extension
fn detectLanguage(file_path: []const u8) ?ananke.Language {
    if (std.mem.endsWith(u8, file_path, ".ts")) {
        return .typescript;
    } else if (std.mem.endsWith(u8, file_path, ".tsx")) {
        return .typescript;
    } else if (std.mem.endsWith(u8, file_path, ".js")) {
        return .javascript;
    } else if (std.mem.endsWith(u8, file_path, ".py")) {
        return .python;
    } else if (std.mem.endsWith(u8, file_path, ".rs")) {
        return .rust;
    } else if (std.mem.endsWith(u8, file_path, ".go")) {
        return .go;
    } else if (std.mem.endsWith(u8, file_path, ".zig")) {
        return .zig;
    }
    return null;
}

/// Check if Modal endpoint is available
pub fn isModalAvailable() bool {
    const endpoint = std.process.getEnvVarOwned(
        std.heap.page_allocator,
        "ANANKE_MODAL_ENDPOINT",
    ) catch return false;
    defer std.heap.page_allocator.free(endpoint);
    return endpoint.len > 0;
}
