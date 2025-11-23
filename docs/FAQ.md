# Frequently Asked Questions

---

## General Questions

### What's the difference between Ananke and ChatGPT/Claude?

**ChatGPT/Claude**: General-purpose AI assistants that generate text probabilistically. They might follow your patterns, but there's no guarantee.

**Ananke**: Specialized constraint-driven system that enforces requirements at the token level. Generated code *cannot* violate constraints.

Think of it as the difference between "hope the model follows your rules" vs "the system prevents rule violations."

### Is Ananke production-ready?

**Yes**. The system includes:
- Comprehensive testing and benchmarking
- Modal GPU inference service
- Complete CLI and library interfaces
- Real-world usage documentation

Suitable for production deployment.

### How much does Ananke cost?

**Ananke itself**: Free and open source (MIT license)

**Infrastructure costs**:
- **Analysis only** (Clew/Braid): Free (runs locally)
- **Generation** (Modal): ~$0.01-0.05 per request + $30/month free tier credits
- **Claude API** (optional): $3-15 per million tokens
- **Total**: $10-50/month for typical usage

### What languages does Ananke support?

Currently supported:
- Python
- TypeScript/JavaScript
- Rust
- Go
- Java (partial)

More languages being added based on community demand.

### Can I run Ananke without Modal?

**For analysis** (Clew/Braid): Yes, completely local.

**For generation** (Maze): You need a constrained inference service. Options:
- Modal (easiest)
- RunPod
- Local GPU with vLLM + llguidance
- Your own infrastructure

You cannot use Claude/OpenAI for generation because they don't expose logits.

---

## Constraints Questions

### What's the difference between constraints and prompts?

**Prompts**: Natural language descriptions of what you want ("add pagination")

**Constraints**: Rules about *how* code must be structured ("no eval() calls", "all functions must be typed")

Ananke uses both: prompts describe intent, constraints ensure quality.

### Can constraints be too restrictive?

Yes. If you have contradictory constraints or constraints too specific to past code, generation might fail.

**Solutions**:
1. Use `ananke constraints analyze` to find conflicts
2. Use Claude to suggest relaxations: `ananke constraints validate --use-claude`
3. Start with fewer constraints and add incrementally

### How do I know what constraints to extract?

Start with automatic extraction:

```bash
ananke extract ./src --output auto.json
```

Then review and adjust based on:
- What patterns do you want to enforce?
- What bad patterns do you want to prevent?
- What performance requirements do you have?

---

## Generation Questions

### Why does generation sometimes fail?

Common reasons:

1. **Constraints too restrictive** - No valid outputs possible
2. **Inference service down** - Check Modal logs
3. **Model doesn't support constraint** - Some constraints work better with larger models
4. **Network timeout** - Retry or increase timeout

See troubleshooting guide for solutions.

### How do I improve generation quality?

1. **Be specific in prompts** - "Add JWT authentication with exp validation" vs "Add auth"
2. **Lower temperature** - Use 0.3-0.5 for deterministic code
3. **Use larger model** - 70B models better than 8B for complex code
4. **Relax unnecessary constraints** - Only enforce critical patterns
5. **Provide context** - Include relevant code snippets in prompt

### How fast is generation?

**Typical latency**:
- Cold start (load model): 3-5 seconds
- Subsequent requests: 1-3 seconds per 100 tokens
- Constraint validation: <50 microseconds per token

Overall: 2-10 seconds per request

### Can I batch generate code?

Yes:

```bash
ananke generate --batch requests.yaml \
  --constraints compiled.cir \
  --output-dir generated/
```

---

## Integration Questions

### How do I integrate Ananke into CI/CD?

See Tutorial 5 for complete setup. Quick version:

```yaml
# .github/workflows/ananke-check.yml
- name: Validate constraints
  run: |
    pip install ananke-ai
    ananke validate ./src --constraints .ananke/constraints.cir
```

### Can I use Ananke with my existing tools?

**Pre-commit hooks**: Yes
```bash
ananke hook install
```

**VS Code**: Via CLI commands
**GitHub Actions**: Via workflow steps
**Build systems**: Via library API

### How do I share constraints with my team?

```bash
# Compile and commit
ananke compile constraints.json --output .ananke/constraints.cir
git add .ananke/constraints.cir
git commit -m "Update constraints"

# Team pulls and uses
git pull
ananke generate "feature" --constraints .ananke/constraints.cir
```

---

## Performance Questions

### How fast is constraint extraction?

- **Simple files** (<100 lines): 10-50ms
- **Medium files** (100-1000 lines): 50-200ms
- **Large files** (>1000 lines): 200-500ms
- **With Claude**: Add 500-1000ms per file

To speed up:
```bash
# Extract only certain types
ananke extract ./src --types security,type_safety

# Disable Claude
ananke extract ./src --no-claude
```

### How fast is constraint compilation?

- **Small** (1-5 constraints): <10ms
- **Medium** (5-25 constraints): 10-50ms
- **Large** (25+ constraints): 50-200ms

To speed up:
```bash
# Remove redundant constraints
ananke constraints prune constraints.json

# Compile with optimization
ananke compile constraints.json --optimize
```

### How fast is code generation?

See "How fast is generation?" above.

---

## Technical Questions

### What's under the hood?

**Architecture**:
- **Clew**: Tree-sitter static analysis
- **Braid**: Constraint DAG + llguidance compilation
- **Ariadne**: Constraint DSL parser
- **Maze**: Rust orchestration layer
- **Modal**: vLLM + llguidance GPU service

**Languages**:
- **Zig**: Constraint engines (fast, memory-efficient)
- **Rust**: Orchestration (async, safe)
- **Python**: Bindings and CLI

### How are constraints validated?

During generation, constraints are applied token-by-token:

1. Model produces logits (probability for each token)
2. llguidance applies token masks (disable invalid tokens)
3. Only valid tokens can be selected
4. Process repeats for each token

Result: Generated code *cannot* violate constraints.

### How do constraints get stored?

**Formats**:
- **JSON**: Human-readable, version-control friendly
- **YAML**: More readable for large constraint sets
- **CIR**: Compiled binary format, optimized for generation

Recommendation: Commit JSON/YAML to git, keep CIR in .gitignore

---

## Support Questions

### How do I report a bug?

1. **GitHub Issues**: https://github.com/ananke-ai/ananke/issues
2. **Include**: Steps to reproduce, expected behavior, actual behavior
3. **Logs**: Set `ANANKE_LOG_LEVEL=debug` and include logs

### Can I contribute?

Yes! Check `CONTRIBUTING.md` for:
- Code of conduct
- Development setup
- Pull request process
- Areas needing help

### Where can I ask questions?

1. **GitHub Discussions**: Community Q&A
2. **Discord**: Real-time chat
3. **Email**: support@ananke-ai.dev (paid plans)

---

## More Information

- **User Guide**: See `USER_GUIDE.md`
- **Tutorials**: See `docs/tutorials/`
- **API Reference**: See `docs/API.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`

