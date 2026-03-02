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

**14 languages**, in two tiers:

**Tier 1** (tree-sitter AST, 0.95 confidence): TypeScript, JavaScript, Python, Rust, Go, Zig, C, C++, Java

**Tier 2** (tree-sitter + patterns, 0.85 confidence): Kotlin, C#, Ruby, PHP, Swift

All 14 support constraint extraction, CLaSH domain compilation, and type analysis. See [LANGUAGE_SUPPORT.md](LANGUAGE_SUPPORT.md) for details.

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
1. Use feasibility analysis (`src/braid/feasibility.zig`) to detect conflicts and tightness
2. The CLaSH relaxation cascade handles over-constraint automatically: drop Imports → Types → Syntax-only
3. Start with fewer constraints and add incrementally

### How do I know what constraints to extract?

Start with automatic extraction:

```bash
./zig-out/bin/ananke extract path/to/code.ts
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
    zig build -Doptimize=ReleaseSafe
    ./zig-out/bin/ananke validate ./src
```

### Can I use Ananke with my existing tools?

**VS Code**: Via [ananke-vscode](https://github.com/rand/ananke-vscode) extension
**GitHub Actions**: Via workflow steps
**Build systems**: Via Zig library API or Rust FFI

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
# Static analysis only (no Claude API)
unset ANTHROPIC_API_KEY
./zig-out/bin/ananke extract path/to/code.ts
```

### How fast is constraint compilation?

- **Small** (1-5 constraints): <10ms
- **Medium** (5-25 constraints): 10-50ms
- **Large** (25+ constraints): 50-200ms

Braid uses LRU caching — repeated compilations of the same constraint set are near-instant (~5-15μs cache hit). First compilation is ~1ms for typical constraint sets.

### How fast is code generation?

See "How fast is generation?" above.

---

## Technical Questions

### What's under the hood?

**Architecture**:
- **Clew** (Zig): Tree-sitter AST extraction across 14 languages, scope context, call graph, conventions
- **Braid** (Zig): CLaSH 5-domain constraint algebra, domain fusion (ASAp + CRANE), type inhabitation, FIM
- **Ariadne** (Zig): Constraint DSL parser
- **Maze** (Rust): Orchestration layer, FFI bridge, Modal/sglang client
- **Inference**: sglang/vLLM + llguidance, Qwen2.5-Coder-32B-Instruct on A100-80GB

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design and [CLASH_ALGEBRA.md](CLASH_ALGEBRA.md) for the constraint algebra.

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

### What is CLaSH?

CLaSH (Constraint Lattice for Shaped Holefilling) is the algebraic foundation. Five constraint domains in two tiers: hard (Syntax, Types, Imports — binary pass/fail) and soft (ControlFlow, Semantics — graded preferences). Hard constraints compose by intersection; soft constraints never block generation. See [CLASH_ALGEBRA.md](CLASH_ALGEBRA.md).

### What is FIM?

Fill-in-the-middle: generate code between existing prefix and suffix (cursor in the middle of a file). Ananke quotients the grammar by surrounding context so the infill is guaranteed to connect prefix to suffix through valid program states. See [FIM_GUIDE.md](FIM_GUIDE.md).

### What is domain fusion?

How 5 CLaSH domains fuse into 1 per-token decision. Hard domains intersect (exact), soft domains reweight (additive), ASAp preserves the distribution, CRANE adapts intensity by generation phase. See [DOMAIN_FUSION.md](DOMAIN_FUSION.md).

---

## More Information

- **User Guide**: See [USER_GUIDE.md](USER_GUIDE.md)
- **Tutorials**: See [tutorials/](tutorials/)
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

