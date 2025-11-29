# API Error Handling Guide

Comprehensive guide to handling errors when using Ananke's API integrations (Claude API and Modal).

## Table of Contents

1. [Overview](#overview)
2. [Error Types](#error-types)
3. [Retry Strategy](#retry-strategy)
4. [Error Codes](#error-codes)
5. [Best Practices](#best-practices)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Ananke integrates with external APIs (Claude/Anthropic and Modal) for semantic analysis and constraint compilation. Network requests can fail for various reasons:

- **Transient failures**: Temporary network issues, rate limits, server overload
- **Permanent failures**: Invalid API keys, malformed requests, quota exceeded
- **Timeout failures**: Slow network, large payloads, server processing time

Ananke implements **intelligent retry logic with exponential backoff** to handle transient failures gracefully while failing fast on permanent errors.

---

## Error Types

### Network Errors

**Retryable** - Automatically retried with exponential backoff:

```
ConnectionRefused        - Server not responding
ConnectionTimedOut       - Request took too long
NetworkUnreachable       - No network connectivity
TemporarilyUnavailable   - Service temporarily down
BrokenPipe               - Connection interrupted
ConnectionResetByPeer    - Server closed connection
```

**Non-retryable** - Fail immediately:

```
OutOfMemory             - Insufficient system resources
SystemResources         - System-level resource exhaustion
InvalidUrl              - Malformed URL (configuration error)
InvalidUtf8             - Character encoding issue
```

### HTTP Status Code Errors

**Retryable Status Codes:**

| Code | Meaning | Retry Strategy |
|------|---------|----------------|
| 408 | Request Timeout | Retry with backoff |
| 429 | Too Many Requests (Rate Limit) | Retry with exponential backoff + jitter |
| 500 | Internal Server Error | Retry (server issue) |
| 502 | Bad Gateway | Retry (proxy/gateway issue) |
| 503 | Service Unavailable | Retry (temporary outage) |
| 504 | Gateway Timeout | Retry (upstream timeout) |

**Non-retryable Status Codes:**

| Code | Meaning | Action |
|------|---------|--------|
| 400 | Bad Request | Fix request format |
| 401 | Unauthorized | Check API key |
| 403 | Forbidden | Verify permissions |
| 404 | Not Found | Check endpoint URL |
| 422 | Unprocessable Entity | Validate request payload |

---

## Retry Strategy

### Exponential Backoff Configuration

```zig
pub const RetryConfig = struct {
    max_retries: u8 = 3,                  // Maximum retry attempts
    initial_backoff_ms: u32 = 1000,       // Start with 1 second
    max_backoff_ms: u32 = 30000,          // Cap at 30 seconds
    backoff_multiplier: f32 = 2.0,        // Double each time
    use_jitter: bool = true,              // Add randomization
};
```

### Backoff Progression

| Attempt | Base Delay | With Jitter (50-100%) |
|---------|------------|-----------------------|
| 1 | 1s | 500ms - 1s |
| 2 | 2s | 1s - 2s |
| 3 | 4s | 2s - 4s |
| 4 | 8s | 4s - 8s |
| 5 | 16s | 8s - 16s |
| 6+ | 30s (capped) | 15s - 30s |

### Why Jitter?

**Without jitter (thundering herd problem):**
```
Client 1: ├─ 1s ─┤├─ 2s ─┤├─ 4s ─┤
Client 2: ├─ 1s ─┤├─ 2s ─┤├─ 4s ─┤  ← All hit server simultaneously
Client 3: ├─ 1s ─┤├─ 2s ─┤├─ 4s ─┤
```

**With jitter (distributed load):**
```
Client 1: ├─ 0.8s ─┤├─ 1.5s ─┤├─ 3.2s ─┤
Client 2: ├─ 0.5s ─┤├─ 1.8s ─┤├─ 2.7s ─┤  ← Requests spread out
Client 3: ├─ 0.9s ─┤├─ 1.2s ─┤├─ 3.8s ─┤
```

### Retry Decision Flow

```
┌─────────────────┐
│ HTTP Request    │
└────────┬────────┘
         │
         ▼
   ┌─────────┐
   │ Success?│─── Yes ──→ Return Response
   └────┬────┘
        │ No
        ▼
   ┌──────────────┐
   │ Error Type?  │
   └──────┬───────┘
          │
    ┌─────┴─────┐
    │           │
    ▼           ▼
 Retryable   Non-retryable
    │           │
    ▼           └──→ Fail Immediately
 Max retries
 exceeded?
    │
 Yes│  No
    │   │
    ▼   ▼
  Fail  Wait (exponential backoff + jitter)
         │
         └──→ Retry Request
```

---

## Error Codes

### Claude API Errors

#### Authentication Errors
```zig
error.Unauthorized  // 401: Invalid API key
// Fix: Set ANTHROPIC_API_KEY environment variable
// export ANTHROPIC_API_KEY=sk-ant-...
```

#### Rate Limiting
```zig
error.RateLimited  // 429: Too many requests
// Automatic retry with backoff
// Consider: Upgrade API tier, reduce request frequency
```

#### Request Errors
```zig
error.InvalidRequest  // 400: Malformed request
// Check: Request format, required fields, data types

error.RequestTooLarge  // 413: Payload exceeds limit
// Fix: Reduce input size, split into multiple requests
```

#### Server Errors
```zig
error.ServerError  // 500-599: Claude API server issues
// Automatic retry
// If persistent: Check status.anthropic.com
```

### Modal Errors

#### Deployment Errors
```zig
error.DeploymentFailed  // Modal app not deployed
// Fix: modal deploy --name ananke-compiler

error.EndpointNotFound  // 404: App/endpoint missing
// Fix: Verify modal_endpoint in config
```

#### Execution Errors
```zig
error.FunctionTimeout  // Modal function timeout
// Fix: Increase timeout, optimize constraint compilation

error.ResourceExhausted  // Out of Modal credits
// Fix: Add payment method, check usage
```

---

## Best Practices

### 1. Configure Appropriate Timeouts

```zig
// For small requests (< 1KB)
const fast_retry = RetryConfig{
    .max_retries = 2,
    .initial_backoff_ms = 500,
    .max_backoff_ms = 5000,
};

// For large requests (> 100KB) or complex operations
const slow_retry = RetryConfig{
    .max_retries = 5,
    .initial_backoff_ms = 2000,
    .max_backoff_ms = 60000,
};
```

### 2. Monitor Retry Statistics

```zig
var stats = retry_mod.RetryStats{};
const response = try postWithRetry(
    allocator,
    url,
    headers,
    body,
    retry_config,
    &stats,
);

// Log retry metrics for observability
std.log.info("Request completed after {d} attempts, {d}ms total backoff", .{
    stats.attempts,
    stats.total_backoff_ms,
});
```

### 3. Implement Circuit Breaker Pattern

For production systems, implement circuit breaker to prevent cascading failures:

```zig
const CircuitState = enum { Closed, Open, HalfOpen };

var circuit_state = CircuitState.Closed;
var failure_count: u32 = 0;
const FAILURE_THRESHOLD = 5;

fn makeRequest() !Response {
    if (circuit_state == .Open) {
        return error.CircuitOpen;
    }

    const response = try postWithRetry(...) catch |err| {
        failure_count += 1;
        if (failure_count >= FAILURE_THRESHOLD) {
            circuit_state = .Open;
            // Schedule circuit reset after cooldown period
        }
        return err;
    };

    // Success - reset circuit
    failure_count = 0;
    circuit_state = .Closed;
    return response;
}
```

### 4. Validate Before Sending

```zig
// Validate API key exists
if (!config.claude_api_key.isSet()) {
    return error.MissingApiKey;
}

// Validate request size
if (request_body.len > MAX_REQUEST_SIZE) {
    return error.RequestTooLarge;
}

// Validate URL format
const uri = std.Uri.parse(url) catch {
    return error.InvalidUrl;
};
```

### 5. Use Timeouts

```zig
// Set per-request timeout
const timeout_ms: u32 = 30000;  // 30 seconds

// For streaming responses, use longer timeout
const streaming_timeout_ms: u32 = 120000;  // 2 minutes
```

---

## Examples

### Example 1: Basic Error Handling

```zig
const response = http.post(
    allocator,
    "https://api.anthropic.com/v1/messages",
    headers,
    request_body,
) catch |err| {
    switch (err) {
        error.ConnectionFailed => {
            std.log.err("Network error: {s}", .{@errorName(err)});
            return error.NetworkUnavailable;
        },
        error.Timeout => {
            std.log.err("Request timeout - server too slow", .{});
            return error.OperationTimeout;
        },
        error.InvalidUrl => {
            std.log.err("Configuration error: invalid API endpoint", .{});
            return error.ConfigurationError;
        },
        else => return err,
    }
};

if (response.status_code != 200) {
    std.log.err("API error: {d} - {s}", .{
        response.status_code,
        response.body,
    });
    return error.ApiError;
}
```

### Example 2: With Retry Logic

```zig
const retry_config = retry_mod.RetryConfig{
    .max_retries = 3,
    .initial_backoff_ms = 1000,
    .use_jitter = true,
};

var stats = retry_mod.RetryStats{};

const response = http.postWithRetry(
    allocator,
    url,
    headers,
    body,
    retry_config,
    &stats,
) catch |err| {
    std.log.err("Request failed after {d} attempts: {s}", .{
        stats.attempts,
        @errorName(err),
    });

    if (stats.last_error) |last_err| {
        std.log.err("Last error: {s}", .{@errorName(last_err)});
    }

    return err;
};

defer response.deinit();
std.log.info("Request succeeded after {d} attempts", .{stats.attempts});
```

### Example 3: Environment Variable Configuration

```toml
# .ananke.toml
[claude]
endpoint = "https://api.anthropic.com/v1/messages"
model = "claude-sonnet-4-5-20250929"
enabled = true

[defaults]
max_tokens = 4096
temperature = 0.7
```

```bash
# Environment variables (higher priority than config file)
export ANTHROPIC_API_KEY=sk-ant-...
export ANANKE_CLAUDE_ENDPOINT=https://api.anthropic.com/v1/messages
```

---

## Troubleshooting

### Issue: "ConnectionFailed" errors

**Symptoms:**
```
error: ConnectionFailed
error: the following command failed: ananke extract
```

**Solutions:**
1. Check network connectivity:
   ```bash
   curl https://api.anthropic.com/v1/messages
   ```

2. Verify firewall/proxy settings:
   ```bash
   export HTTP_PROXY=http://proxy.example.com:8080
   export HTTPS_PROXY=https://proxy.example.com:8080
   ```

3. Check DNS resolution:
   ```bash
   nslookup api.anthropic.com
   ```

### Issue: "Unauthorized" (401) errors

**Symptoms:**
```
HTTP 401: Unauthorized
error: Invalid API key
```

**Solutions:**
1. Verify API key is set:
   ```bash
   echo $ANTHROPIC_API_KEY
   ```

2. Check key format (should start with `sk-ant-`):
   ```bash
   # Correct format
   sk-ant-api03-...
   ```

3. Verify key hasn't expired (check Anthropic Console)

### Issue: "RateLimited" (429) errors

**Symptoms:**
```
HTTP 429: Too Many Requests
Retry-After: 60
```

**Solutions:**
1. **Automatic handling**: Ananke retries with exponential backoff
2. **Manual configuration**: Increase backoff times:
   ```zig
   const retry_config = RetryConfig{
       .max_retries = 5,
       .initial_backoff_ms = 2000,
       .max_backoff_ms = 60000,
   };
   ```
3. **Long-term**: Reduce request frequency or upgrade API tier

### Issue: Requests timing out

**Symptoms:**
```
error: Timeout
Request exceeded 30000ms timeout
```

**Solutions:**
1. Increase timeout for large requests:
   ```zig
   const http_client = HttpClient{
       .timeout_ms = 60000,  // 60 seconds
   };
   ```

2. Reduce payload size:
   ```bash
   # Split large files
   ananke extract large_file.ts --max-size 50000
   ```

3. Check server status:
   ```bash
   curl -I https://api.anthropic.com
   ```

### Issue: Retry exhaustion

**Symptoms:**
```
Request failed after 3 attempts
Last error: ServerError
```

**Solutions:**
1. Check service status: https://status.anthropic.com
2. Increase retry attempts:
   ```zig
   const retry_config = RetryConfig{
       .max_retries = 5,  // More attempts
   };
   ```
3. Implement exponential backoff ceiling:
   ```zig
   const retry_config = RetryConfig{
       .max_backoff_ms = 120000,  // 2 minutes max
   };
   ```

---

## Error Codes Reference

### Ananke HTTP Error Enum

```zig
pub const HttpError = error{
    ConnectionFailed,    // Network unreachable
    Timeout,            // Request timeout
    InvalidUrl,         // Malformed URL
    RequestFailed,      // Generic request failure
    InvalidResponse,    // Malformed response
    TooManyRedirects,   // Redirect loop
    RateLimited,        // 429 status code
    ServerError,        // 500-599 status codes
};
```

### Retry Module Errors

```zig
// Errors that trigger retry
const RETRYABLE_ERRORS = .{
    error.ConnectionRefused,
    error.ConnectionTimedOut,
    error.NetworkUnreachable,
    error.TemporarilyUnavailable,
    error.BrokenPipe,
    error.ConnectionResetByPeer,
};

// Errors that fail immediately
const FATAL_ERRORS = .{
    error.OutOfMemory,
    error.SystemResources,
    error.InvalidUrl,
    error.InvalidUtf8,
};
```

---

## Related Documentation

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - General troubleshooting guide
- [README.md](../README.md) - Getting started
- [src/api/retry.zig](../src/api/retry.zig) - Retry implementation
- [src/api/http.zig](../src/api/http.zig) - HTTP client implementation
- [src/security/secure_string.zig](../src/security/secure_string.zig) - API key security

---

## Support

- **Issues**: https://github.com/your-org/ananke/issues
- **Discussions**: https://github.com/your-org/ananke/discussions
- **Anthropic Status**: https://status.anthropic.com
- **Modal Status**: https://status.modal.com
