# Ananke Documentation Index

Complete guide to all Ananke documentation, organized by purpose and audience.

---

## Quick Links

### I Want To...

**Get started immediately**
- [Quick Start](../QUICKSTART.md) - 10 minutes
- [Tutorial 1: Extract Constraints](tutorials/01-extract-constraints.md) - 15 minutes

**Understand the constraint algebra**
- [CLaSH Algebra](CLASH_ALGEBRA.md) - The 5-domain, 2-tier constraint lattice
- [Domain Fusion](DOMAIN_FUSION.md) - How 5 domains fuse into 1 per-token decision
- [Type Inhabitation](TYPE_INHABITATION.md) - Type-directed token mask generation

**Learn practical features**
- [FIM Guide](FIM_GUIDE.md) - Fill-in-the-middle for IDE completions
- [Homer Integration](HOMER_INTEGRATION.md) - Repository intelligence
- [Language Support](LANGUAGE_SUPPORT.md) - 14-language support matrix
- [Eval Guide](EVAL_GUIDE.md) - Evaluation framework

**Look something up**
- [CLI Guide](CLI_GUIDE.md) - Command reference (8 commands)
- [API Reference (Zig)](API_REFERENCE_ZIG.md) - Zig library API
- [FAQ](FAQ.md) - Common questions answered

**Deploy to production**
- [Deployment](DEPLOYMENT.md) - Build, deploy, configure
- [Architecture](ARCHITECTURE.md) - System design
- [Modal Infrastructure](MODAL_INFRASTRUCTURE.md) - GPU deployment

**Understand the system deeply**
- [Architecture](ARCHITECTURE.md) - System design and data flow
- [Internals](INTERNALS.md) - Implementation deep dive
- [Extending](EXTENDING.md) - Adding languages and constraint types

---

## Reading Paths

### Path 1: Quick Start (30 min)
1. [README](../README.md) (5 min)
2. [QUICKSTART](../QUICKSTART.md) (10 min)
3. [Tutorial 1: Extract Constraints](tutorials/01-extract-constraints.md) (15 min)

### Path 2: Conceptual Deep Dive (90 min)
1. [Architecture](ARCHITECTURE.md) (20 min)
2. [CLaSH Algebra](CLASH_ALGEBRA.md) (25 min)
3. [Domain Fusion](DOMAIN_FUSION.md) (20 min)
4. [Type Inhabitation](TYPE_INHABITATION.md) (15 min)
5. [Homer Integration](HOMER_INTEGRATION.md) (15 min)

### Path 3: Practical Usage (60 min)
1. [CLI Guide](CLI_GUIDE.md) (15 min)
2. [FIM Guide](FIM_GUIDE.md) (15 min)
3. [Language Support](LANGUAGE_SUPPORT.md) (10 min)
4. [Eval Guide](EVAL_GUIDE.md) (15 min)

### Path 4: All Tutorials (90 min)
1. [Extract Constraints](tutorials/01-extract-constraints.md) (15 min)
2. [Compile Constraints](tutorials/02-compile-constraints.md) (15 min)
3. [Generate Code](tutorials/03-generate-code.md) (20 min)
4. [Ariadne DSL](tutorials/04-ariadne-dsl.md) (20 min)
5. [Integration](tutorials/05-integration.md) (20 min)

---

## File Map

```
docs/
├── INDEX.md                       # This file
│
├── Conceptual Core
│   ├── ARCHITECTURE.md            # System design and data flow
│   ├── CLASH_ALGEBRA.md           # CLaSH 5-domain constraint algebra (NEW)
│   ├── DOMAIN_FUSION.md           # Domain fusion: ASAp + CRANE (NEW)
│   ├── TYPE_INHABITATION.md       # Type-directed token masks (NEW)
│   └── INTERNALS.md               # Implementation deep dive
│
├── Practical Guides
│   ├── CLI_GUIDE.md               # CLI reference (8 commands)
│   ├── FIM_GUIDE.md               # Fill-in-the-middle guide (NEW)
│   ├── HOMER_INTEGRATION.md       # Repository intelligence (NEW)
│   ├── LANGUAGE_SUPPORT.md        # 14-language matrix (NEW)
│   ├── EVAL_GUIDE.md              # Evaluation framework (NEW)
│   └── DEPLOYMENT.md              # Build and deploy
│
├── API References
│   ├── API_REFERENCE_ZIG.md       # Zig library API
│   ├── API_REFERENCE_RUST.md      # Rust Maze API
│   ├── API_QUICK_REFERENCE.md     # Quick reference card
│   ├── PYTHON_API.md              # Python bindings
│   └── FFI_GUIDE.md               # Cross-language integration
│
├── Extension & Contributing
│   ├── EXTENDING.md               # Adding languages and constraints
│   ├── PATTERN_REFERENCE.md       # Pattern library (383 patterns, 14 langs)
│   └── LIBRARY_INTEGRATION.md     # Library integration guide
│
├── Reference
│   ├── FAQ.md                     # Common questions
│   ├── TROUBLESHOOTING.md         # Problem solutions
│   ├── MODAL_INFRASTRUCTURE.md    # Modal GPU deployment
│   └── ariadne-grammar.md         # Ariadne DSL grammar
│
├── Design Documents
│   ├── spec/                      # Feature specifications
│   │   ├── SPEC-01-clash-algebra.md
│   │   ├── SPEC-02-sglang-integration.md
│   │   ├── SPEC-03-rich-context.md
│   │   ├── SPEC-04-homer-integration.md
│   │   └── SPEC-05-domain-fusion.md
│   └── adr/                       # Architectural decisions
│       ├── ADR-001-json-bridge-format.md
│       ├── ADR-002-hard-soft-constraint-tiers.md
│       ├── ADR-003-homer-mcp-communication.md
│       ├── ADR-004-cross-domain-morphism-monotonicity.md
│       ├── ADR-005-distribution-preserving-domain-fusion.md
│       ├── ADR-006-scope-graph-resolution-from-homer.md
│       └── ADR-007-salience-based-constraint-relaxation.md
│
└── tutorials/
    ├── README.md                  # Tutorial index
    ├── 01-extract-constraints.md  # 15 min, beginner
    ├── 02-compile-constraints.md  # 15 min, intermediate
    ├── 03-generate-code.md        # 20 min, intermediate
    ├── 04-ariadne-dsl.md          # 20 min, advanced
    └── 05-integration.md          # 20 min, advanced
```

---

## By Task

| Task | Document | Section |
|------|----------|---------|
| Get started | [QUICKSTART](../QUICKSTART.md) | Full guide |
| Understand CLaSH | [CLASH_ALGEBRA](CLASH_ALGEBRA.md) | 5 domains, 2 tiers |
| Use FIM mode | [FIM_GUIDE](FIM_GUIDE.md) | CLI usage |
| Check language support | [LANGUAGE_SUPPORT](LANGUAGE_SUPPORT.md) | Matrix |
| Look up CLI command | [CLI_GUIDE](CLI_GUIDE.md) | Commands |
| Run evaluations | [EVAL_GUIDE](EVAL_GUIDE.md) | Running evals |
| Add a language | [EXTENDING](EXTENDING.md) | Adding language support |
| Deploy to Modal | [DEPLOYMENT](DEPLOYMENT.md) | Modal section |
| Understand architecture | [ARCHITECTURE](ARCHITECTURE.md) | System design |
| Fix a problem | [TROUBLESHOOTING](TROUBLESHOOTING.md) | By error type |
