# Example 02: Claude-Enhanced Semantic Analysis

This example compares constraint extraction with and without Claude, demonstrating the value of LLM-enhanced semantic understanding.

## What This Example Shows

- **Comparison study**: Side-by-side static vs. semantic analysis
- **Business rule extraction**: Finding implicit constraints in code
- **Domain understanding**: Recognizing payment processing patterns
- **Comment analysis**: Extracting intent from documentation
- **Confidence scoring**: How certain are we about each constraint?

## Files

- `sample.py` - Payment processing code with rich business logic
- `main.zig` - Comparison program that runs both approaches
- `build.zig` - Build configuration
- `build.zig.zon` - Dependencies

## Prerequisites

### Required
- Zig 0.15.2 or later

### Optional (for Claude analysis)
- Anthropic API key (get one at https://console.anthropic.com/settings/keys)
- Internet connection

### Cost Estimate

If using Claude:
- API calls: ~$0.01-0.05 per run (depending on file size)
- Free tier: 5 free API calls available for new accounts

## Setup

### Option 1: Run Without Claude (Free)

```bash
# No setup needed - just run
zig build run
```

This will demonstrate what Claude analysis would find, using static analysis only.

### Option 2: Run With Claude (Requires API Key)

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit `.env` and add your API key:
```bash
ANTHROPIC_API_KEY=sk-ant-api03-your-actual-key-here
```

3. Load the environment:
```bash
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY .env | cut -d '=' -f2)
```

4. Verify it's set:
```bash
echo $ANTHROPIC_API_KEY
```

5. Run the example:
```bash
zig build run
```

## Building and Running

```bash
# From this directory
zig build run

# Or from the ananke root
cd examples/02-claude-analysis
zig build run
```

Expected build time: ~5 seconds
Expected run time (without Claude): ~100ms
Expected run time (with Claude): ~2-3 seconds

## What Gets Extracted

### Static Analysis Alone (No LLM)

Finds basic patterns:
- Function definitions with type hints
- Class structure and methods
- Explicit type annotations
- Error handling patterns
- Import statements

### With Claude Analysis

Extracts deeper constraints:

1. **Business Rule: $10,000 Threshold**
   - Source: Comment + code logic
   - "Payments over $10,000 require additional verification"

2. **Rate Limiting Policy**
   - Source: Inferred from `_is_rate_limited` method + comment
   - "3 failed attempts in 24 hours = rate limited"

3. **PCI Compliance**
   - Source: Comments about logging
   - "Never log full card numbers"

4. **Refund Window**
   - Source: Docstring
   - "Refunds must be processed within 90 days"

5. **Supported Currencies**
   - Source: `SUPPORTED_CURRENCIES` list + function
   - "Only USD, EUR, GBP accepted"

6. **Performance Requirement**
   - Source: Comment in fraud detection
   - "Must be fast (< 100ms)"

7. **Idempotency Requirement**
   - Source: Comment about duplicate handling
   - "Must be idempotent"

8. **Security Requirement**
   - Source: Comment about TLS
   - "Must use secure connection"

## Confidence Scores

Claude provides confidence for each extracted constraint:

- **1.0**: Explicitly stated in code or comments
- **0.9-0.95**: Strongly implied by multiple indicators
- **0.8-0.89**: Reasonable inference from context
- **0.7-0.79**: Plausible but less certain
- **< 0.7**: Speculative, might be wrong

## Cost vs. Value Analysis

### Static Analysis
- **Cost**: Free
- **Time**: ~50-100ms
- **Constraints found**: 5-10 (structural)

### Claude Analysis
- **Cost**: ~$0.01-0.05 per request (depending on file size)
- **Time**: ~1-3 seconds
- **Constraints found**: 15-25 (structural + semantic)

### When to Use Claude

Use Claude when:
- Code has complex business logic
- Domain knowledge matters (finance, healthcare, etc.)
- Comments contain important constraints
- Understanding intent is crucial
- Cost is acceptable for the value

Skip Claude when:
- Simple structural constraints are enough
- Speed is critical
- Budget is tight
- Code is self-explanatory

## Integration Pattern

The recommended approach:

```python
# 1. Fast static pass (always)
static_constraints = clew.extract(code, use_llm=False)

# 2. Check if semantic analysis is needed
needs_semantic = (
    has_complex_business_logic(code) or
    has_rich_comments(code) or
    is_critical_domain(code)
)

# 3. Optional semantic pass (when valuable)
if needs_semantic and budget_allows:
    semantic_constraints = clew.extract(code, use_llm=True)
    all_constraints = merge(static_constraints, semantic_constraints)
else:
    all_constraints = static_constraints
```

## Understanding the Output

Each constraint includes:

- **Name**: Human-readable identifier
- **Kind**: Category (syntactic, security, operational, etc.)
- **Severity**: How important (error, warning, info)
- **Description**: What the constraint means
- **Source**: Where it came from (static_analysis, llm_analysis)
- **Confidence**: How certain we are (0.0-1.0)
- **Provenance**: Original location in code

## Key Insights

1. **Static analysis is a baseline** - Always run it first
2. **LLMs add semantic layer** - Understanding beyond structure
3. **Confidence matters** - Not all extracted constraints are equally certain
4. **Cost-benefit tradeoff** - Use Claude when value exceeds cost
5. **Complementary approaches** - Combine for best results

## Next Steps

- See Example 01 for pure static extraction
- See Example 03 for manually defining constraints in Ariadne DSL
- See Example 04 for using these constraints in code generation

## Real-World Usage

In production:

```zig
// Typical workflow
const constraints = try clew.extractFromCode(source_code, "python");

// Filter by confidence
const high_confidence = constraints.filter(|c| c.confidence > 0.8);

// Compile to IR
const ir = try braid.compile(high_confidence);

// Use for validation or generation
const result = try maze.generate(intent, ir);
```

This hybrid approach gives you the speed of static analysis with the intelligence of semantic understanding, only paying for LLM calls when they provide value.

## Common Issues

### Issue: API key not recognized

**Symptom:**
```
ANTHROPIC_API_KEY not set - skipping Claude analysis
```

**Cause:** Environment variable not exported or incorrectly formatted.

**Solution:**
```bash
# Check if variable is set
echo $ANTHROPIC_API_KEY

# If empty, export it
export ANTHROPIC_API_KEY='sk-ant-api03-...'

# Verify again
echo $ANTHROPIC_API_KEY

# Run example
zig build run
```

### Issue: API authentication failed

**Symptom:**
```
Error: Claude API authentication failed
```

**Cause:** Invalid or expired API key.

**Solution:**
1. Verify your API key at https://console.anthropic.com/settings/keys
2. Generate a new key if needed
3. Update your .env file
4. Re-export the environment variable

### Issue: Rate limit exceeded

**Symptom:**
```
Error: Rate limit exceeded
```

**Cause:** Too many API calls in a short time.

**Solution:**
- Wait 60 seconds and try again
- Upgrade your Anthropic API plan for higher limits
- Run without Claude using static analysis only

### Issue: Network timeout

**Symptom:**
```
Error: Request timeout
```

**Cause:** Slow internet connection or API service issues.

**Solution:**
- Check your internet connection
- Try again in a few minutes
- Check Anthropic status page: https://status.anthropic.com
- Run without Claude for offline operation

### Issue: Cost concerns

**Symptom:**
You're worried about API costs accumulating.

**Solution:**
- Use static analysis only (free) for development
- Reserve Claude analysis for production/critical code
- Set up billing alerts in Anthropic console
- Run Example 01 instead for cost-free extraction

## Files Structure

```
02-claude-analysis/
├── README.md                    # This file
├── .env.example                 # Environment template
├── main.zig                     # Comparison program (80 lines)
├── sample.py                    # Payment processing code
├── sample_complex_logic.py      # Complex business logic
├── sample_security.ts           # Security-focused code
├── build.zig                    # Build configuration
└── build.zig.zon                # Dependencies
```

## Analyzing Different Files

The example includes multiple sample files to test different patterns:

### Payment Processing (sample.py)
- Rich business logic
- Compliance requirements
- Rate limiting
- Refund policies

```bash
# Modify main.zig to use this file (already default)
const file_path = "sample.py";
```

### Complex Logic (sample_complex_logic.py)
- Intricate algorithms
- State machines
- Performance requirements

```bash
# Modify main.zig
const file_path = "sample_complex_logic.py";
const constraints = try clew.extractFromCode(source_code, "python");
```

### Security Focus (sample_security.ts)
- Authentication patterns
- Input validation
- Cryptography usage

```bash
# Modify main.zig
const file_path = "sample_security.ts";
const constraints = try clew.extractFromCode(source_code, "typescript");
```

## Performance Comparison

| Operation              | Without Claude | With Claude |
|------------------------|----------------|-------------|
| File reading           | ~1ms           | ~1ms        |
| Static analysis        | ~50ms          | ~50ms       |
| Semantic analysis      | N/A            | ~1500ms     |
| Total                  | ~51ms          | ~1551ms     |
| Constraints found      | 5-10           | 15-25       |
| Cost                   | $0.00          | ~$0.02      |

The 30x slowdown with Claude is offset by 2-3x more constraints and much richer semantic understanding.
