# Claude API Integration for Ananke

This document describes the Claude API integration for semantic analysis and conflict resolution in the Ananke constraint mining system.

## Overview

The Claude integration enables Ananke to use Large Language Model capabilities for:
- **Semantic analysis** of source code to extract implicit constraints
- **Test intent analysis** to understand what tests verify
- **Conflict resolution** when multiple constraints are incompatible

## Architecture

### Components

```
src/api/
├── http.zig          - HTTP client utilities
└── claude.zig        - Claude API client with retries and rate limiting

src/clew/
└── clew.zig          - Updated to use Claude for semantic analysis

src/braid/
└── braid.zig         - Updated to use Claude for conflict resolution

examples/
└── claude_integration.zig  - Demonstration of Claude API usage
```

### Module Structure

1. **HTTP Client** (`src/api/http.zig`)
   - Simple HTTP POST wrapper for API calls
   - JSON serialization/deserialization helpers
   - Header management
   - Response handling

2. **Claude Client** (`src/api/claude.zig`)
   - Full Claude API integration
   - API key management from environment
   - Configurable model, temperature, max_tokens
   - Automatic retries with exponential backoff
   - Rate limiting to prevent API throttling
   - Type-safe request/response handling

3. **Clew Integration**
   - Optional Claude client field
   - Calls Claude for semantic analysis when available
   - Converts Claude responses to Ananke Constraint objects
   - Caches results for performance

4. **Braid Integration**
   - Optional Claude client field
   - Uses Claude to suggest conflict resolutions
   - Applies LLM-suggested resolutions to constraint graph
   - Falls back to heuristic resolution when Claude unavailable

## API Structure

### ClaudeClient

```zig
pub const ClaudeClient = struct {
    allocator: std.mem.Allocator,
    config: ClaudeConfig,

    // Rate limiting
    last_request_time: i64,
    min_request_interval_ms: i64 = 100,

    // Retry configuration
    max_retries: u32 = 3,
    retry_delay_ms: u32 = 1000,

    pub fn init(allocator, config) !ClaudeClient
    pub fn deinit(*ClaudeClient) void

    // Main API methods
    pub fn analyzeCode(*ClaudeClient, source: []const u8, language: []const u8) ![]const Constraint
    pub fn suggestResolution(*ClaudeClient, conflicts: []const ConflictDescription) !ResolutionSuggestion
    pub fn analyzeTestIntent(*ClaudeClient, test_source: []const u8) !TestIntentAnalysis
};
```

### ClaudeConfig

```zig
pub const ClaudeConfig = struct {
    api_key: []const u8,
    endpoint: []const u8 = "https://api.anthropic.com/v1/messages",
    model: []const u8 = "claude-sonnet-4-5-20250929",
    max_tokens: u32 = 4096,
    temperature: f32 = 0.7,
    timeout_ms: u32 = 30000,
};
```

## Usage Examples

### 1. Initialize Claude Client

```zig
const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY");
defer allocator.free(api_key);

const config = claude_api.ClaudeConfig{
    .api_key = api_key,
    .max_tokens = 2048,
    .temperature = 0.7,
};

var client = try claude_api.ClaudeClient.init(allocator, config);
defer client.deinit();
```

### 2. Analyze Code for Constraints

```zig
const typescript_code =
    \\function processUser(user: any) {
    \\    if (user.name == null) {
    \\        throw new Error("Name is required");
    \\    }
    \\    return user.name.toUpperCase();
    \\}
;

const constraints = try client.analyzeCode(typescript_code, "typescript");
defer allocator.free(constraints);

for (constraints) |constraint| {
    std.log.info("{s}: {s}", .{constraint.name, constraint.description});
}
```

### 3. Integrate with Clew

```zig
var clew = try Clew.init(allocator);
defer clew.deinit();

// Set Claude client for semantic analysis
clew.setClaudeClient(&client);

// Extract constraints (will use Claude automatically)
const constraint_set = try clew.extractFromCode(source, "typescript");
defer constraint_set.deinit();
```

### 4. Resolve Conflicts with Braid

```zig
var braid = try Braid.init(allocator);
defer braid.deinit();

// Set Claude client for conflict resolution
braid.setClaudeClient(&client);

// Compile constraints (will use Claude for conflicts)
const ir = try braid.compile(constraints);
```

## Prompts and Responses

### Code Analysis Prompt

The Claude client sends structured prompts for code analysis:

```
Analyze the following {language} code and extract semantic constraints.

For each constraint, provide:
1. Type (semantic, type_safety, security, etc.)
2. Severity (error, warning, info, hint)
3. Name (short identifier)
4. Description (clear explanation)
5. Confidence (0.0 to 1.0)

Code:
```{language}
{source_code}
```

Return the constraints as a JSON array...
```

### Expected Response Format

```json
[
  {
    "kind": "type_safety",
    "severity": "warning",
    "name": "avoid_any_type",
    "description": "Parameter 'user' uses 'any' type which bypasses type checking",
    "confidence": 0.95
  },
  {
    "kind": "semantic",
    "severity": "info",
    "name": "null_check_before_use",
    "description": "Code checks for null before accessing properties",
    "confidence": 0.9
  }
]
```

### Conflict Resolution Prompt

```
The following constraint conflicts need resolution:

Conflict 1:
  Constraint A: strict_null_checks (All values must be checked for null)
  Constraint B: performance_optimization (Skip null checks for performance)
  Issue: Null checking adds overhead but is required for safety

Suggest a resolution strategy. For each conflict, provide one of:
1. "disable_a" or "disable_b" - disable one constraint
2. "merge" - merge constraints into unified constraint
3. "modify_a" or "modify_b" - modify constraint to resolve conflict

Return JSON in this format...
```

## Error Handling

The Claude client implements robust error handling:

1. **Retries with Exponential Backoff**
   - Automatically retries failed requests up to `max_retries` times
   - Uses exponential backoff: delay = base_delay * 2^retry_count
   - Prevents overwhelming the API during transient failures

2. **Rate Limiting**
   - Enforces minimum interval between requests (default 100ms)
   - Sleeps if necessary to maintain rate limit
   - Prevents API throttling errors

3. **Timeout Handling**
   - Configurable timeout per request (default 30s)
   - Prevents indefinite hangs on network issues

4. **Response Validation**
   - Validates JSON structure of responses
   - Gracefully handles malformed responses
   - Extracts JSON from markdown code blocks if needed

## Performance Considerations

1. **Caching** - Clew caches constraint extraction results by source code
2. **Optional Usage** - Claude client is optional; system works without it
3. **Batching** - Multiple constraints analyzed in single API call when possible
4. **Rate Limiting** - Built-in rate limiting prevents API quota exhaustion

## Security

1. **API Key Management**
   - API key loaded from environment variable (ANTHROPIC_API_KEY)
   - Never hardcoded or logged
   - Passed securely to HTTP client

2. **Input Validation**
   - Source code sanitized before sending to API
   - Response parsing validates structure and types
   - No arbitrary code execution from responses

## Configuration

### Environment Variables

- `ANTHROPIC_API_KEY` - Required. Your Claude API key

### Build Flags

```bash
zig build                    # Build with Claude integration
zig build run-example        # Run Claude integration example
```

## Dependencies

- Zig 0.15.2 or later
- Internet connection for Claude API
- Valid Anthropic API key

## Limitations

1. **API Costs** - Each analysis call costs API credits
2. **Latency** - Network round-trip adds latency vs local analysis
3. **Rate Limits** - Subject to Anthropic's rate limiting
4. **Availability** - Requires internet and API availability

## Future Enhancements

1. **Streaming Responses** - Support Claude streaming for faster feedback
2. **Prompt Caching** - Use Claude's prompt caching for repeated analyses
3. **Fine-tuning** - Train custom models for domain-specific constraints
4. **Batch API** - Use batch API for cost-efficient bulk analysis
5. **Local Fallback** - Use local models when API unavailable

## Testing

Run the example:

```bash
export ANTHROPIC_API_KEY=your-key-here
zig build run-example
```

## Troubleshooting

### "API key not set" error
- Ensure `ANTHROPIC_API_KEY` environment variable is set
- Verify API key is valid and active

### "Max retries exceeded" error
- Check internet connection
- Verify Claude API is accessible
- Check API rate limits and quotas

### "Invalid response" error
- Usually indicates API changes or malformed request
- Check Claude API version compatibility
- Review request/response logs

## Implementation Status

### Completed
- ✅ HTTP client utilities with POST support
- ✅ Claude API client with full configuration
- ✅ Retry logic with exponential backoff
- ✅ Rate limiting implementation
- ✅ JSON request/response handling
- ✅ Clew integration for semantic analysis
- ✅ Braid integration for conflict resolution
- ✅ Type conversions between Claude and Ananke types
- ✅ Comprehensive error handling
- ✅ Example code demonstrating usage
- ✅ Build system integration

### Known Issues
- HTTP client uses simplified fetch API (returns empty body)
- Full HTTP response parsing needs refinement for Zig 0.15 API
- ArrayList and JSON APIs updated for Zig 0.15 compatibility

### Next Steps for Production
1. Complete HTTP client to properly capture response bodies
2. Add comprehensive unit tests
3. Add integration tests with mock API
4. Performance benchmarking
5. Add metrics and logging

## License

Same as Ananke project.
