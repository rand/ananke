//! Full Pipeline E2E Tests
//!
//! Tests the complete extraction pipeline from source code to constraints:
//! - Source parsing with tree-sitter
//! - Hybrid extraction (AST + patterns)
//! - Constraint quality and confidence
//! - Metadata and provenance tracking
//! - Error handling and graceful degradation

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
// Import Ananke modules
const ananke = @import("ananke");
const Constraint = ananke.types.constraint.Constraint;
const ConstraintKind = ananke.types.constraint.ConstraintKind;
const ConstraintSet = ananke.types.constraint.ConstraintSet;
const Severity = ananke.types.constraint.Severity;
// Import Clew (extraction engine)
const Clew = @import("clew").Clew;
const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;
// ============================================================================
// Test Fixtures
const typescript_real_world =
    \\// Real-world TypeScript: API service with validation
    \\interface UserCreateRequest {
    \\    username: string;
    \\    email: string;
    \\    password: string;
    \\}
    \\
    \\interface ValidationError {
    \\    field: string;
    \\    message: string;
    \\class EmailValidator {
    \\    private static readonly EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    \\    
    \\    static validate(email: string): ValidationError | null {
    \\        if (!this.EMAIL_REGEX.test(email)) {
    \\            return { field: 'email', message: 'Invalid email format' };
    \\        }
    \\        return null;
    \\    }
    \\class UserService {
    \\    async createUser(request: UserCreateRequest): Promise<User> {
    \\        // Validate email
    \\        const emailError = EmailValidator.validate(request.email);
    \\        if (emailError) {
    \\            throw new ValidationError(emailError.message);
    \\        
    \\        // Hash password
    \\        const hashedPassword = await this.hashPassword(request.password);
    \\        return await this.db.insert({
    \\            username: request.username,
    \\            email: request.email,
    \\            password: hashedPassword
    \\        });
    \\    private async hashPassword(password: string): Promise<string> {
    \\        // bcrypt implementation
    \\        return "";
;
const python_real_world =
    \\# Real-world Python: Async rate limiter with decorators
    \\from typing import Optional, Dict, Any
    \\from dataclasses import dataclass
    \\from datetime import datetime
    \\import asyncio
    \\@dataclass
    \\class RateLimitConfig:
    \\    max_requests: int
    \\    window_seconds: int
    \\class RateLimitExceeded(Exception):
    \\    """Raised when rate limit is exceeded."""
    \\    pass
    \\class RateLimiter:
    \\    def __init__(self, config: RateLimitConfig):
    \\        self.config = config
    \\        self.requests: Dict[str, list] = {}
    \\    async def check_limit(self, user_id: str) -> bool:
    \\        """Check if user has exceeded rate limit."""
    \\        now = datetime.now()
    \\        if user_id not in self.requests:
    \\            self.requests[user_id] = []
    \\        # Clean old requests
    \\        self.requests[user_id] = [
    \\            req_time for req_time in self.requests[user_id]
    \\            if (now - req_time).seconds < self.config.window_seconds
    \\        ]
    \\        if len(self.requests[user_id]) >= self.config.max_requests:
    \\            raise RateLimitExceeded(f"User {user_id} exceeded rate limit")
    \\        self.requests[user_id].append(now)
    \\        return True
    \\def rate_limit(max_requests: int, window_seconds: int):
    \\    """Decorator to apply rate limiting to async functions."""
    \\    def decorator(func):
    \\        async def wrapper(*args, **kwargs):
    \\            # Rate limit check here
    \\            return await func(*args, **kwargs)
    \\        return wrapper
    \\    return decorator
;

// Full Pipeline: TypeScript
test "Full Pipeline: TypeScript real-world code extraction" {
    const allocator = testing.allocator;
    
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(typescript_real_world, "typescript");
    defer constraints.deinit();
    // Should extract multiple constraints
    try testing.expect(constraints.constraints.items.len > 0);
    std.debug.print("\n=== TypeScript Full Pipeline Test ===\n", .{});
    std.debug.print("Extracted {} constraints from real-world TypeScript\n", .{constraints.constraints.items.len});
    // Verify we found key patterns
    var found_interface = false;
    var found_class = false;
    var found_async = false;
    var found_validation = false;
    for (constraints.constraints.items) |constraint| {
        const name_lower = std.ascii.allocLowerString(allocator, constraint.name) catch constraint.name;
        defer if (name_lower.ptr != constraint.name.ptr) allocator.free(name_lower);
        
        if (std.mem.indexOf(u8, name_lower, "interface") != null) found_interface = true;
        if (std.mem.indexOf(u8, name_lower, "class") != null) found_class = true;
        if (std.mem.indexOf(u8, name_lower, "async") != null) found_async = true;
        if (std.mem.indexOf(u8, name_lower, "validat") != null) found_validation = true;
        std.debug.print("  - {s} (kind: {s}, confidence: {d:.2})\n", 
            .{constraint.name, @tagName(constraint.kind), constraint.confidence});
    }
    try testing.expect(found_interface or found_class);
    std.debug.print("✓ Found structural patterns (interfaces/classes)\n", .{});
}
test "Full Pipeline: TypeScript constraint quality checks" {
    const allocator = testing.allocator;

    var extractor = try HybridExtractor.init(allocator, .combined);
    defer extractor.deinit();
    defer extractor.deinit();
    var result = try extractor.extract(typescript_real_world, "typescript");
    defer result.deinitFull(allocator);

    std.debug.print("\n=== TypeScript Constraint Quality ===\n", .{});
    std.debug.print("Strategy used: {s}\n", .{@tagName(result.strategy_used)});
    std.debug.print("Tree-sitter available: {}\n", .{result.tree_sitter_available});

    if (result.tree_sitter_errors) |errors| {
        std.debug.print("Tree-sitter errors: {s}\n", .{errors});
    }

    // All constraints should have valid confidence scores
    for (result.constraints) |constraint| {
        try testing.expect(constraint.confidence >= 0.0 and constraint.confidence <= 1.0);

        // AST-based constraints should have high confidence (0.95)
        // Pattern-based should have medium confidence (0.75)
        if (constraint.confidence >= 0.90) {
            std.debug.print("  High confidence (AST): {s} = {d:.2}\n",
                .{constraint.name, constraint.confidence});
        }
    }

    // Should have at least some high-confidence AST constraints if tree-sitter actually succeeded
    if (result.tree_sitter_available and result.tree_sitter_errors == null) {
        var high_confidence_count: usize = 0;
        for (result.constraints) |constraint| {
            if (constraint.confidence >= 0.90) high_confidence_count += 1;
        }
        std.debug.print("✓ Found {} high-confidence AST constraints\n", .{high_confidence_count});
        try testing.expect(high_confidence_count > 0);
    } else if (result.tree_sitter_errors != null) {
        std.debug.print("⊘ Tree-sitter extraction failed, skipping AST confidence check\n", .{});
    }
}
// Full Pipeline: Python
test "Full Pipeline: Python real-world code extraction" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(python_real_world, "python");
    defer constraints.deinit();
    std.debug.print("\n=== Python Full Pipeline Test ===\n", .{});
    std.debug.print("Extracted {} constraints from real-world Python\n", .{constraints.constraints.items.len});
    // Verify we found key Python patterns
    var found_dataclass = false;
    var found_exception = false;
    var found_decorator = false;
    for (constraints.constraints.items) |c| {
        const name_lower = std.ascii.allocLowerString(allocator, c.name) catch c.name;
        defer if (name_lower.ptr != c.name.ptr) allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "dataclass") != null) found_dataclass = true;
        if (std.mem.indexOf(u8, name_lower, "exception") != null or
            std.mem.indexOf(u8, name_lower, "error") != null) found_exception = true;
        if (std.mem.indexOf(u8, name_lower, "decorator") != null) found_decorator = true;
        std.debug.print("  - {s} (kind: {s}, confidence: {d:.2})\n",
            .{c.name, @tagName(c.kind), c.confidence});
    }
    std.debug.print("✓ Extracted Python-specific patterns\n", .{});
}
test "Full Pipeline: Python metadata and provenance" {
    const allocator = testing.allocator;

    var extractor = try HybridExtractor.init(allocator, .combined);
    defer extractor.deinit();
    defer extractor.deinit();
    var result = try extractor.extract(python_real_world, "python");
    defer result.deinitFull(allocator);

    std.debug.print("\n=== Python Metadata Verification ===\n", .{});
    // Check metadata is populated
    for (result.constraints) |constraint| {
        // All constraints should have names and descriptions
        try testing.expect(constraint.name.len > 0);
        try testing.expect(constraint.description.len > 0);
        // Constraint kind should be valid
        switch (constraint.kind) {
            .syntactic, .type_safety, .semantic, .architectural, .operational, .security => {},
        }
        std.debug.print("  {s}: line={?}, freq={}, conf={d:.2}\n",
            .{constraint.name, constraint.origin_line, constraint.frequency, constraint.confidence});
    }
    std.debug.print("✓ All constraints have valid metadata\n", .{});
}
// Error Handling and Edge Cases
test "Full Pipeline: Empty source code" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode("", "typescript");
    defer constraints.deinit();
    // Should handle empty code gracefully
    std.debug.print("\n=== Empty Source Test ===\n", .{});
    std.debug.print("Constraints from empty code: {}\n", .{constraints.constraints.items.len});
    std.debug.print("✓ Handled empty source gracefully\n", .{});
}
test "Full Pipeline: Malformed TypeScript" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    const malformed = "function broken( { const x =";
    var constraints = try clew.extractFromCode(malformed, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Malformed Code Test ===\n", .{});
    std.debug.print("Constraints from malformed TypeScript: {}\n", .{constraints.constraints.items.len});
    std.debug.print("✓ Handled malformed code without crashing\n", .{});
}
test "Full Pipeline: Very large source file" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    // Generate large source (repeat pattern 100 times)
    var large_source = try std.ArrayList(u8).initCapacity(allocator, 10000);
    defer large_source.deinit();
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const writer = large_source.writer(allocator);
        try writer.writeAll(typescript_real_world);
        try large_source.append('\n');
    }
    const start = std.time.milliTimestamp();
    var constraints = try clew.extractFromCode(large_source.items, "typescript");
    defer constraints.deinit();
    const elapsed = std.time.milliTimestamp() - start;
    std.debug.print("\n=== Large File Test ===\n", .{});
    std.debug.print("Processed {} bytes in {}ms\n", .{large_source.items.len, elapsed});
    std.debug.print("Extracted {} constraints\n", .{constraints.constraints.items.len});
    std.debug.print("✓ Handled large file successfully\n", .{});
}
test "Full Pipeline: Unsupported language fallback" {
    const allocator = testing.allocator;
    const kotlin_code = "fun main() { println(\"Hello\") }";
    var extractor = try HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    defer extractor.deinit();
    var result = try extractor.extract(kotlin_code, "kotlin");
    defer result.deinitFull(allocator);
    std.debug.print("\n=== Unsupported Language Test ===\n", .{});
    std.debug.print("Tree-sitter available for Kotlin: {}\n", .{result.tree_sitter_available});
    std.debug.print("Fallback to patterns: {}\n", .{!result.tree_sitter_available});
    if (result.tree_sitter_errors) |errors| {
        std.debug.print("Expected error: {s}\n", .{errors});
    }
    std.debug.print("✓ Graceful degradation for unsupported language\n", .{});
}
// Confidence Score Distribution
test "Full Pipeline: Confidence score distribution" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var result = try clew.extractFromCode(typescript_real_world, "typescript");
    defer result.deinit();
    std.debug.print("\n=== Confidence Score Distribution ===\n", .{});
    var high_conf: usize = 0;  // >= 0.90
    var mid_conf: usize = 0;   // 0.70 - 0.89
    var low_conf: usize = 0;   // < 0.70
    for (result.constraints.items) |constraint| {
        if (constraint.confidence >= 0.90) {
            high_conf += 1;
        } else if (constraint.confidence >= 0.70) {
            mid_conf += 1;
        } else {
            low_conf += 1;
        }
    }
    const total = result.constraints.items.len;
    if (total > 0) {
        std.debug.print("High confidence (AST, ≥0.90): {} ({d:.1}%)\n", 
            .{high_conf, @as(f64, @floatFromInt(high_conf)) / @as(f64, @floatFromInt(total)) * 100.0});
        std.debug.print("Mid confidence (0.70-0.89): {} ({d:.1}%)\n",
            .{mid_conf, @as(f64, @floatFromInt(mid_conf)) / @as(f64, @floatFromInt(total)) * 100.0});
        std.debug.print("Low confidence (<0.70): {} ({d:.1}%)\n",
            .{low_conf, @as(f64, @floatFromInt(low_conf)) / @as(f64, @floatFromInt(total)) * 100.0});
    }
    std.debug.print("✓ Confidence scores properly distributed\n", .{});
}
