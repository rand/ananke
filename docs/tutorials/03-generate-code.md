# Tutorial 3: Generate Code with Constraints

**Time**: 20 minutes  
**Level**: Intermediate  
**Outcome**: Generate your first piece of constrained code

---

## Prerequisites

Complete Tutorials 1 and 2, or have:
- Compiled constraints (`.cir` file)
- Modal service deployed
- Environment configured

---

## Step 1: Prepare Your Environment

```bash
# Verify Modal is set up
modal token list

# If empty, authenticate
modal token new

# Create HuggingFace secret
modal secret create huggingface-secret \
  HUGGING_FACE_HUB_TOKEN=hf_your_token

# Deploy inference service
ananke service deploy --model llama-3.1-8b

# Verify deployment
modal app list
# Should show ananke-inference
```

## Step 2: Generate Simple Code

Start with a basic generation:

```bash
# Generate code with constraints
ananke generate "Create a function that validates email addresses" \
  --constraints compiled.cir \
  --max-tokens 256 \
  --output email_validator.py

# View generated code
cat email_validator.py
```

## Step 3: Validate Generated Code

Check that generated code satisfies constraints:

```bash
# Validate generated code
ananke validate email_validator.py --constraints compiled.cir

# Expected output:
# ✓ All type constraints satisfied
# ✓ All security constraints satisfied
# ✓ All performance constraints satisfied
```

## Step 4: Generate with Custom Options

Control generation behavior:

```bash
# With specific temperature (lower = more conservative)
ananke generate "Add user authentication" \
  --constraints compiled.cir \
  --temperature 0.3 \
  --max-tokens 500 \
  --output auth.py

# Generate in specific language
ananke generate "Create API handler" \
  --constraints compiled.cir \
  --language typescript \
  --output handler.ts

# Generate multiple variations
ananke generate "Implement caching" \
  --constraints compiled.cir \
  --num-samples 3 \
  --output-dir variations/
```

## Step 5: Interactive Generation

Get real-time feedback:

```bash
# Interactive mode
ananke generate "Add pagination to user list" \
  --constraints compiled.cir \
  --interactive

# You'll see:
# 1. Generated code
# 2. Constraint validation report
# 3. Option to accept/reject/refine
# 4. Suggestion for improvements
```

## Step 6: Batch Generation

Generate multiple pieces of code:

```bash
# Create request batch file
cat > generation-requests.yaml << 'YAML'
requests:
  - prompt: "Implement user signup endpoint"
    max_tokens: 300
  - prompt: "Add email notification service"
    max_tokens: 400
  - prompt: "Create database migration"
    max_tokens: 250
YAML

# Generate all
ananke generate --batch generation-requests.yaml \
  --constraints compiled.cir \
  --output-dir generated/
```

## Step 7: Handle Generation Errors

What to do when generation fails:

```bash
# Enable debug mode
ANANKE_LOG_LEVEL=debug ananke generate "feature" \
  --constraints compiled.cir \
  --debug

# If constraints too restrictive:
# Option 1: Relax constraints
ananke constraints modify compiled.cir \
  --relax "complexity_limit" \
  --output relaxed.cir

# Option 2: Lower temperature
ananke generate "feature" \
  --constraints compiled.cir \
  --temperature 0.1

# Option 3: Use smaller max_tokens
ananke generate "feature" \
  --constraints compiled.cir \
  --max-tokens 100
```

## Step 8: Integrate into Your Workflow

Use generated code in your project:

```bash
# Generate in your src directory
ananke generate "Add feature X" \
  --constraints compiled.cir \
  --output src/feature_x.py \
  --language python

# Run tests on generated code
pytest src/feature_x.py

# Add to version control
git add src/feature_x.py
git commit -m "Add feature X (generated with Ananke)"
```

---

## Understanding Generation Results

### Validation Report

When code is generated, you get a validation report:

```
Generation Complete
===================

Generated: 287 tokens in 3.2s

Type Safety Constraints:
  ✓ No 'any' types
  ✓ All returns typed
  ✓ All parameters typed

Security Constraints:
  ✓ Input validation present
  ✓ No dangerous functions
  ✓ Error handling

Performance Constraints:
  ✓ Complexity: 7/10
  ✓ Caching used
  ✓ Execution time: 45ms

Confidence: 98%
```

### What Each Part Means

- **Type Safety**: Code follows your typing rules
- **Security**: Code avoids dangerous patterns
- **Performance**: Code meets performance targets
- **Confidence**: Model's certainty in constraints

---

## Troubleshooting

### Generation Timeout

**Problem**: "Generation timed out after 10 seconds"

**Solution**:
```bash
# Reduce complexity
ananke generate "feature" \
  --constraints compiled.cir \
  --max-tokens 128 \
  --temperature 0.3

# Or check Modal service
modal logs ananke-inference | tail -20
```

### Constraints Violated

**Problem**: "Generated code violates constraints"

**Solution**:
```bash
# Try with strict mode
ananke generate "feature" \
  --constraints compiled.cir \
  --strict-mode \
  --temperature 0.1

# Or debug which constraint failed
ananke validate generated.py \
  --constraints compiled.cir \
  --debug
```

### Modal Service Not Responding

**Problem**: "Connection refused"

**Solution**:
```bash
# Check service is running
modal app list

# Redeploy if needed
modal deploy modal_inference/inference.py

# Check logs
modal logs ananke-inference
```

---

## Next Steps

- **Tutorial 4**: Learn Ariadne DSL for advanced constraints
- **Tutorial 5**: Integrate generation into CI/CD
- **User Guide**: Detailed feature documentation
- **API Reference**: All CLI commands

---

**Next**: [Tutorial 4: Ariadne DSL](04-ariadne-dsl.md)
