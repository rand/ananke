# Ananke Documentation Index

Complete guide to all Ananke documentation, organized by purpose and audience.

---

## Quick Links

### I Want To...

**Get started immediately**
- [Quick Start](USER_GUIDE.md#quick-start-60-seconds) - 5 minutes
- [Tutorial 1: Extract Constraints](tutorials/01-extract-constraints.md) - 15 minutes

**Learn all the concepts**
- [Core Concepts](USER_GUIDE.md#core-concepts) - 20 minutes
- [All Tutorials](tutorials/README.md) - 1-2 hours

**Look something up**
- [API Reference](API.md) - Command and function reference
- [FAQ](FAQ.md) - Common questions answered
- [TROUBLESHOOTING](TROUBLESHOOTING.md) - Problem solutions

**Deploy to production**
- [Integration Tutorial](tutorials/05-integration.md) - Complete setup
- [User Guide: Configuration](USER_GUIDE.md#configuration) - All options
- [Architecture](ARCHITECTURE.md) - System design details

**Fix a problem**
- [TROUBLESHOOTING](TROUBLESHOOTING.md) - Browse by problem type
- [User Guide: Troubleshooting](USER_GUIDE.md#troubleshooting) - General issues
- [FAQ](FAQ.md#support-questions) - Getting help

**Understand the system**
- [ARCHITECTURE.md](ARCHITECTURE.md) - Complete system design
- [Core Concepts](USER_GUIDE.md#core-concepts) - High-level overview
- [Technical FAQ](FAQ.md#technical-questions) - Technical deep dive

---

## Documentation by Audience

### First-Time Users
**Path**: 45 minutes total

1. [What is Ananke?](USER_GUIDE.md#what-is-ananke) (5 min)
2. [Quick Start](USER_GUIDE.md#quick-start-60-seconds) (10 min)
3. [Installation](USER_GUIDE.md#installation) (10 min)
4. [Tutorial 1: Extract Constraints](tutorials/01-extract-constraints.md) (15 min)
5. [Common Tasks](USER_GUIDE.md#common-tasks) (reference as needed)

**Result**: Can extract constraints and understand the system

### Python/Rust Developers
**Path**: 1-2 hours total

1. [Core Concepts](USER_GUIDE.md#core-concepts) (20 min)
2. [API Reference](API.md) (30 min)
3. [Tutorial 3: Generate Code](tutorials/03-generate-code.md) (20 min)
4. [Integration Tutorial](tutorials/05-integration.md) (30 min, optional)

**Result**: Can use Ananke in code and automate workflows

### DevOps/Infrastructure
**Path**: 1 hour total

1. [Installation](USER_GUIDE.md#installation) (15 min)
2. [Configuration](USER_GUIDE.md#configuration) (20 min)
3. [Integration Tutorial](tutorials/05-integration.md) (20 min)
4. [TROUBLESHOOTING](TROUBLESHOOTING.md) (reference as needed)

**Result**: Can deploy and maintain Ananke service

### Team Leads/Architects
**Path**: 1-2 hours total

1. [What is Ananke?](USER_GUIDE.md#what-is-ananke) (10 min)
2. [FAQ](FAQ.md) (30 min)
3. [Core Concepts](USER_GUIDE.md#core-concepts) (20 min)
4. [ARCHITECTURE](ARCHITECTURE.md) (20 min)
5. [Integration Tutorial](tutorials/05-integration.md) (20 min, optional)

**Result**: Can evaluate feasibility and plan adoption

---

## Documentation Organization

### User-Facing Guides (START HERE)

#### USER_GUIDE.md (7,500 words)
**Main reference for all users**

- Getting Started
  - What is Ananke?
  - Quick start in 60 seconds
  
- Core Concepts
  - Constraint types (6 categories)
  - How Ananke works (4-layer architecture)
  - Claude API vs inference server
  
- Installation
  - 3 installation options
  - Modal setup (for code generation)
  - Prerequisites by use case
  
- Usage Patterns
  - CLI tools
  - Library integration
  - API service
  - Pre-commit hooks
  - Code review automation
  
- Constraint Sources
  - Automatic extraction
  - JSON constraints
  - YAML constraints
  - Ariadne DSL
  - Multiple sources
  - Claude-enhanced extraction
  
- Configuration
  - Environment variables
  - Configuration file
  - Per-project overrides
  
- Common Tasks
  - Extracting constraints
  - Generating code
  - Validating code
  - Setting up CI/CD
  - Sharing constraints
  - Debugging
  
- Troubleshooting
  - Installation issues
  - Modal issues
  - Constraint issues
  - Performance issues
  - Getting help

**When to use**: Always your first stop for practical questions

---

### API Reference

#### API.md (4,000 words)
**Complete API reference for developers**

- CLI Commands
  - extract
  - compile
  - generate
  - validate
  - constraints (subcommands)
  
- Python API
  - Clew (extraction)
  - Braid (compilation)
  - Maze (orchestration)
  
- Zig API
  - Core modules
  - Type system
  
- HTTP API
  - Endpoints
  - Request/response formats
  - Status codes
  
- Configuration Reference
  - All environment variables
  - Config file schema
  
- Error Handling
  - Exception types
  - Error codes
  - Recovery strategies

**When to use**: When you need exact syntax or API details

---

### FAQ

#### FAQ.md (2,500 words)
**Common questions and honest answers**

- General (Comparison, cost, languages)
- Constraints (Types, restrictiveness)
- Generation (Quality, performance)
- Integration (CI/CD, sharing)
- Performance (Speed, scalability)
- Technical (Architecture, validation)
- Support (Getting help, reporting bugs)

**When to use**: When you have a general question or need clarification

---

### Tutorial Series (5 tutorials, 10,000 words)

#### Tutorial Index
`tutorials/README.md` - Navigation and overview

#### 1. Extract Constraints (15 min, Beginner)
`tutorials/01-extract-constraints.md`

Learn to automatically discover constraints in your code.

- Extract from TypeScript service
- Understand constraint report
- Extract from multiple sources
- Save for later use

**Start here after**: Installation

---

#### 2. Compile Constraints (15 min, Intermediate)
`tutorials/02-compile-constraints.md`

Optimize constraints for code generation.

- Compile to ConstraintIR
- Analyze dependencies
- Detect conflicts
- Optimize for performance
- Test constraints

**Start here after**: Tutorial 1

---

#### 3. Generate Code (20 min, Intermediate)
`tutorials/03-generate-code.md`

Generate your first piece of constrained code.

- Modal environment setup
- Simple generation
- Code validation
- Custom options
- Interactive mode
- Error handling

**Start here after**: Tutorial 2

---

#### 4. Ariadne DSL (20 min, Advanced)
`tutorials/04-ariadne-dsl.md`

Write constraints in a high-level language.

- Ariadne syntax
- Constraint organization
- Inheritance and composition
- Real-world examples
- DSL vs JSON comparison

**Start here after**: Tutorial 2 (optional after 3)

---

#### 5. Integration (20 min, Advanced)
`tutorials/05-integration.md`

Integrate Ananke into your workflow.

- Project setup
- Pre-commit hooks
- GitHub Actions
- Team workflows
- Production deployment (Docker, K8s)
- Monitoring

**Start here after**: Tutorial 3

---

### Support Documentation

#### TROUBLESHOOTING.md (3,500 words)
**Solutions to common problems**

- Installation Issues (5 problem/solution pairs)
- Modal Service Issues (7 pairs)
- Constraint Issues (4 pairs)
- Generation Issues (3 pairs)
- Performance Issues (3 pairs)
- Debugging Techniques
- Getting Help

**When to use**: When something isn't working

---

### System Documentation

#### ARCHITECTURE.md
**System design and technical details**

- System components (Clew, Braid, Ariadne, Maze)
- Data flow
- Deployment architecture
- Integration patterns
- Performance characteristics
- Security model
- Extensibility

**When to use**: When you need to understand how the system works

---

#### IMPLEMENTATION_PLAN.md
**Development roadmap and phases**

- Phase breakdown (1-10)
- Component dependencies
- Milestones and timeline
- Risk assessment
- Testing strategy

**When to use**: If contributing to development or evaluating project status

---

## Documentation Hierarchy

```
START HERE
    |
    v
USER_GUIDE.md
    |
    +---> Quick Start (5 min)
    |
    +---> Core Concepts (20 min)
    |
    +---> Installation (15 min)
    |
    v
TUTORIALS (choose your path)
    |
    +---> Path 1: Generate Code
    |     Tutorial 1 -> 2 -> 3 (45 min)
    |
    +---> Path 2: Learn Everything
    |     Tutorial 1 -> 2 -> 3 -> 4 -> 5 (90 min)
    |
    +---> Path 3: Integrate & Deploy
    |     Tutorial 1 -> 5 (35 min)
    |
    v
REFERENCE DOCS
    |
    +---> API.md (look up syntax)
    |
    +---> FAQ.md (answer questions)
    |
    +---> TROUBLESHOOTING.md (fix problems)
    |
    v
DEEP DIVE
    |
    +---> ARCHITECTURE.md (understand design)
    |
    +---> IMPLEMENTATION_PLAN.md (evaluate project)
```

---

## File Map

All files in `/docs/`:

```
docs/
├── INDEX.md                       # This file
├── USER_GUIDE.md                  # Main user guide (7,500 words)
├── API.md                         # API reference (4,000 words)
├── FAQ.md                         # Common questions (2,500 words)
├── TROUBLESHOOTING.md             # Problem solutions (3,500 words)
├── ARCHITECTURE.md                # System design (existing)
├── IMPLEMENTATION_PLAN.md         # Dev roadmap (existing)
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

## Reading Guides

### For Different Situations

**"I have 5 minutes"**
- Read: USER_GUIDE.md Quick Start section
- Result: Understand what Ananke does

**"I have 30 minutes"**
- Read: USER_GUIDE.md (skip Troubleshooting)
- Result: Know enough to try Ananke

**"I have 1 hour"**
- Read: USER_GUIDE.md + Tutorial 1
- Result: Can extract and analyze constraints

**"I have 2 hours"**
- Read: USER_GUIDE.md + Tutorials 1-3
- Result: Can use full Ananke pipeline

**"I want to master it"**
- Read: All tutorials + API reference
- Result: Can use any Ananke feature

**"I'm stuck on something"**
1. Check: TROUBLESHOOTING.md for your problem
2. Read: USER_GUIDE.md relevant section
3. See: API.md for exact syntax
4. Ask: FAQ.md or open GitHub issue

---

## Quick Reference

### Most Important Documents

1. **USER_GUIDE.md** - 95% of users find answers here
2. **TROUBLESHOOTING.md** - When something breaks
3. **API.md** - Exact syntax reference
4. **tutorials/01-extract-constraints.md** - First hands-on experience
5. **tutorials/05-integration.md** - Production deployment

### By Task

| Task | Best Document | Section |
|------|---------------|---------|
| Get started | USER_GUIDE | Quick Start |
| Learn concepts | USER_GUIDE | Core Concepts |
| Extract constraints | tutorials/01 | Step-by-step |
| Compile constraints | tutorials/02 | Step-by-step |
| Generate code | tutorials/03 | Step-by-step |
| Write DSL | tutorials/04 | Step-by-step |
| Set up CI/CD | tutorials/05 | Step-by-step |
| Look up command | API | CLI Commands |
| Look up API | API | Python/Zig API |
| Understand cost | FAQ | General |
| Fix error | TROUBLESHOOTING | By error type |
| Understand architecture | ARCHITECTURE | Overview |

---

## Common Questions About Documentation

**Q: Where do I start?**
A: USER_GUIDE.md Quick Start section (5 minutes)

**Q: How long to learn everything?**
A: Complete all tutorials in 90 minutes

**Q: Can I just use the CLI?**
A: Yes, see USER_GUIDE.md Usage Patterns

**Q: Do I need to read ARCHITECTURE.md?**
A: Only if you want deep technical understanding

**Q: Where's the code?**
A: Examples throughout USER_GUIDE.md and tutorials

**Q: How do I report bugs in the docs?**
A: Open issue on GitHub with section and what's wrong

**Q: Can I contribute improvements?**
A: Yes! See CONTRIBUTING.md (coming soon)

---

## Next Steps

1. **Start here**: USER_GUIDE.md
2. **Hands-on practice**: tutorials/01-extract-constraints.md
3. **Deep dive**: tutorials/ (2-5)
4. **Reference**: API.md and FAQ.md
5. **Troubleshoot**: TROUBLESHOOTING.md (as needed)

---

**Happy documenting! Ananke makes it easy to write better code with confidence.**
