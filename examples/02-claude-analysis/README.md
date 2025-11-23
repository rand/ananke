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

## Building and Running

```bash
# Without Claude (static analysis only)
zig build run

# With Claude (requires API key)
export ANTHROPIC_API_KEY='your-key-here'
zig build run
```

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
