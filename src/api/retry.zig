// Retry logic with exponential backoff for HTTP requests
const std = @import("std");

/// Retry configuration
pub const RetryConfig = struct {
    /// Maximum number of retry attempts (0 = no retries)
    max_retries: u8 = 3,

    /// Initial backoff delay in milliseconds
    initial_backoff_ms: u32 = 1000,

    /// Maximum backoff delay in milliseconds (prevents excessive waits)
    max_backoff_ms: u32 = 30000,

    /// Multiplier for exponential backoff (typically 2.0)
    backoff_multiplier: f32 = 2.0,

    /// Whether to add jitter to backoff times (reduces thundering herd)
    use_jitter: bool = true,
};

/// Retry statistics for observability
pub const RetryStats = struct {
    attempts: u32 = 0,
    total_backoff_ms: u64 = 0,
    last_error: ?anyerror = null,
};

/// Calculate backoff delay with exponential backoff and optional jitter
pub fn calculateBackoff(
    config: RetryConfig,
    attempt: u32,
    prng: ?*std.Random,
) u32 {
    if (attempt == 0) return 0;

    // Calculate base exponential backoff: initial * (multiplier ^ (attempt - 1))
    var backoff_ms: f32 = @as(f32, @floatFromInt(config.initial_backoff_ms));
    var i: u32 = 1;
    while (i < attempt) : (i += 1) {
        backoff_ms *= config.backoff_multiplier;
    }

    // Cap at max_backoff_ms
    const capped: u32 = @min(@as(u32, @intFromFloat(backoff_ms)), config.max_backoff_ms);

    // Add jitter if enabled (randomize between 50% and 100% of backoff)
    if (config.use_jitter and prng != null) {
        const min_backoff = capped / 2;
        const jitter_range = capped - min_backoff;
        const jitter = prng.?.int(u32) % jitter_range;
        return min_backoff + jitter;
    }

    return capped;
}

/// Determine if an error is retryable
pub fn isRetryableError(err: anyerror) bool {
    return switch (err) {
        // Network errors - retry
        error.ConnectionRefused,
        error.ConnectionTimedOut,
        error.NetworkUnreachable,
        error.TemporarilyUnavailable,
        error.BrokenPipe,
        error.ConnectionResetByPeer,
        => true,

        // Resource errors - don't retry
        error.OutOfMemory,
        error.SystemResources,
        => false,

        // Invalid input - don't retry
        error.InvalidUrl,
        error.InvalidUtf8,
        error.InvalidCharacter,
        => false,

        // Other errors - retry
        else => true,
    };
}

/// Determine if an HTTP status code is retryable
pub fn isRetryableStatus(status_code: u16) bool {
    return switch (status_code) {
        // 408 Request Timeout
        408 => true,
        // 429 Too Many Requests (rate limit)
        429 => true,
        // 500 Internal Server Error
        500 => true,
        // 502 Bad Gateway
        502 => true,
        // 503 Service Unavailable
        503 => true,
        // 504 Gateway Timeout
        504 => true,
        // Everything else - don't retry
        else => false,
    };
}

/// Execute a function with retry logic and exponential backoff
pub fn withRetry(
    comptime Func: type,
    config: RetryConfig,
    func: Func,
    stats: ?*RetryStats,
) !@typeInfo(@TypeOf(func)).@"fn".return_type.? {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var random = prng.random();

    var attempt: u32 = 0;
    var last_err: ?anyerror = null;

    while (attempt <= config.max_retries) : (attempt += 1) {
        // Update stats
        if (stats) |s| {
            s.attempts = attempt + 1;
        }

        // Calculate and apply backoff (skip on first attempt)
        if (attempt > 0) {
            const backoff_ms = calculateBackoff(config, attempt, &random);
            if (stats) |s| {
                s.total_backoff_ms += backoff_ms;
            }
            std.time.sleep(backoff_ms * std.time.ns_per_ms);
        }

        // Try the function
        const result = func() catch |err| {
            last_err = err;
            if (stats) |s| {
                s.last_error = err;
            }

            // Don't retry if error is not retryable
            if (!isRetryableError(err)) {
                return err;
            }

            // Don't retry if we've exhausted attempts
            if (attempt >= config.max_retries) {
                return err;
            }

            // Log retry (in production, use proper logging)
            std.log.debug("Request failed with {s}, retrying (attempt {d}/{d})", .{
                @errorName(err),
                attempt + 1,
                config.max_retries,
            });

            continue;
        };

        // Success - return result
        return result;
    }

    // Should never reach here, but if we do, return the last error
    return last_err.?;
}

test "calculateBackoff - exponential growth" {
    const testing = std.testing;

    const config = RetryConfig{
        .initial_backoff_ms = 1000,
        .max_backoff_ms = 30000,
        .backoff_multiplier = 2.0,
        .use_jitter = false,
    };

    // First retry: 1000ms
    try testing.expectEqual(@as(u32, 1000), calculateBackoff(config, 1, null));

    // Second retry: 2000ms
    try testing.expectEqual(@as(u32, 2000), calculateBackoff(config, 2, null));

    // Third retry: 4000ms
    try testing.expectEqual(@as(u32, 4000), calculateBackoff(config, 3, null));

    // Fourth retry: 8000ms
    try testing.expectEqual(@as(u32, 8000), calculateBackoff(config, 4, null));

    // Fifth retry: 16000ms
    try testing.expectEqual(@as(u32, 16000), calculateBackoff(config, 5, null));
}

test "calculateBackoff - caps at max" {
    const testing = std.testing;

    const config = RetryConfig{
        .initial_backoff_ms = 1000,
        .max_backoff_ms = 5000,
        .backoff_multiplier = 2.0,
        .use_jitter = false,
    };

    // Should cap at 5000ms
    try testing.expectEqual(@as(u32, 5000), calculateBackoff(config, 10, null));
}

test "calculateBackoff - jitter" {
    const testing = std.testing;

    var prng = std.Random.DefaultPrng.init(12345);
    var random = prng.random();

    const config = RetryConfig{
        .initial_backoff_ms = 1000,
        .max_backoff_ms = 30000,
        .backoff_multiplier = 2.0,
        .use_jitter = true,
    };

    const backoff1 = calculateBackoff(config, 1, &random);
    const backoff2 = calculateBackoff(config, 1, &random);

    // With jitter, values should be in range [500, 1000]
    try testing.expect(backoff1 >= 500);
    try testing.expect(backoff1 <= 1000);
    try testing.expect(backoff2 >= 500);
    try testing.expect(backoff2 <= 1000);
}

test "isRetryableError - network errors" {
    const testing = std.testing;

    try testing.expect(isRetryableError(error.ConnectionRefused));
    try testing.expect(isRetryableError(error.ConnectionTimedOut));
    try testing.expect(isRetryableError(error.NetworkUnreachable));
}

test "isRetryableError - non-retryable errors" {
    const testing = std.testing;

    try testing.expect(!isRetryableError(error.OutOfMemory));
    try testing.expect(!isRetryableError(error.InvalidUrl));
}

test "isRetryableStatus - server errors" {
    const testing = std.testing;

    try testing.expect(isRetryableStatus(429)); // Rate limit
    try testing.expect(isRetryableStatus(500)); // Internal error
    try testing.expect(isRetryableStatus(502)); // Bad gateway
    try testing.expect(isRetryableStatus(503)); // Service unavailable
    try testing.expect(isRetryableStatus(504)); // Gateway timeout
}

test "isRetryableStatus - client errors" {
    const testing = std.testing;

    try testing.expect(!isRetryableStatus(400)); // Bad request
    try testing.expect(!isRetryableStatus(401)); // Unauthorized
    try testing.expect(!isRetryableStatus(404)); // Not found
}

test "withRetry - succeeds on first attempt" {
    const testing = std.testing;

    const func = struct {
        fn call() !void {
            // Success on first try
        }
    }.call;

    const config = RetryConfig{ .max_retries = 3 };
    var stats = RetryStats{};

    try withRetry(@TypeOf(func), config, func, &stats);

    try testing.expectEqual(@as(u32, 1), stats.attempts);
}

test "withRetry - retries on transient error" {
    const testing = std.testing;

    const TestError = error{TransientFailure};

    // Use a global counter to track attempts across retries
    const TestContext = struct {
        var call_count: u32 = 0;

        fn call() !void {
            call_count += 1;
            if (call_count < 3) {
                return TestError.TransientFailure;
            }
        }
    };

    // Reset counter before test
    TestContext.call_count = 0;

    const config = RetryConfig{
        .max_retries = 3,
        .initial_backoff_ms = 1, // Fast for testing
    };
    var stats = RetryStats{};

    try withRetry(@TypeOf(TestContext.call), config, TestContext.call, &stats);

    // Should have tried 3 times before succeeding
    try testing.expectEqual(@as(u32, 3), stats.attempts);
    try testing.expectEqual(@as(u32, 3), TestContext.call_count);
}
