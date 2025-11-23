# Ananke Implementation Plan - Final Version
*With constrained generation architecture and managed inference integration*

## Executive Summary
Ananke requires two distinct deployment layers:
1. **Constraint Engine** (Clew/Braid/Ariadne in Zig): Runs anywhere as a lightweight binary, can leverage managed APIs (Claude/OpenAI) for analysis
2. **Inference Layer** (Maze + vLLM/SGLang + llguidance): Requires GPU infrastructure for constrained code generation with token-level control

Key insight: While constrained generation needs inference server control, the constraint engines can intelligently use managed APIs for extraction and compilation tasks.

---

## System Architecture

```
┌──────────────────────────────────────────────────┐
│            User Applications                     │
│    (CLI, IDE, CI/CD, Web Tools)                 │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│          Ananke Core (Zig)                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │   Clew   │ │  Braid   │ │ Ariadne  │        │
│  │(Extract) │ │(Compile) │ │  (DSL)   │        │
│  └─────┬────┘ └────┬─────┘ └──────────┘        │
│        │           │                             │
│        └───────────┴──────────┐                 │
│                               ▼                  │
│                    Can use Claude/OpenAI         │
│                    for analysis tasks            │
│         Runs locally or edge (no GPU)            │
└─────────────────┬────────────────────────────────┘
                  │ Compiled ConstraintIR
                  │
┌─────────────────▼────────────────────────────────┐
│        Maze Orchestration (Rust/Python)          │
│         Coordinates constrained generation       │
└─────────────────┬────────────────────────────────┘
                  │ API calls
                  │
┌─────────────────▼────────────────────────────────┐
│     Inference Service (Modal/RunPod/Local)       │
│                                                  │
│  ┌────────────────────────────────────────┐     │
│  │        vLLM/SGLang Server              │     │
│  │   - Model loading & management         │     │
│  │   - GPU memory optimization            │     │
│  │   - Batched inference                  │     │
│  └───────────────┬────────────────────────┘     │
│                  │                               │
│  ┌───────────────▼────────────────────────┐     │
│  │         llguidance Engine              │     │
│  │   - Compiles constraints to FSM        │     │
│  │   - Masks logits in ~50μs/token        │     │
│  │   - Enforces grammars/schemas          │     │
│  └────────────────────────────────────────┘     │
│                                                  │
│         Requires GPUs (16-80GB VRAM)             │
└──────────────────────────────────────────────────┘
```

---

## Phase 0: Foundation & Research (Week 1)

### Technology Stack Validation
- **Zig 0.15.1**: Constraint engines
- **Rust 1.83+**: Maze orchestration
- **Python 3.11+**: llguidance integration
- **vLLM 0.8.2+**: Inference server with llguidance support
- **Modal**: GPU infrastructure for constrained generation
- **Claude/OpenAI APIs**: For Clew/Braid analysis tasks

### Core Architecture Decisions
```zig
// Ananke core runs WITHOUT GPUs but CAN use managed APIs
pub const ConstraintEngine = struct {
    clew: Clew,      // Extraction - may use Claude for understanding
    braid: Braid,    // Compilation - may use Claude for optimization
    ariadne: ?Ariadne, // Optional DSL

    // Outputs ConstraintIR for constrained generation
    pub fn compile(self: *ConstraintEngine) !ConstraintIR {}
};
```

### Deployment Strategy Research
- Set up Modal account ($30 free credits)
- Test vLLM deployment on Modal
- Benchmark llguidance performance
- Configure Claude/OpenAI API keys for analysis
- Evaluate model options (Llama, Mistral, DeepSeek)

---

## Phase 1: Constraint Engines in Zig (Weeks 2-3)

### Clew Implementation with Managed API Support
```zig
const Clew = struct {
    claude_client: ?ClaudeClient, // Optional managed API

    // Extract constraints using hybrid approach
    pub fn extractFromCode(source: []const u8) ![]Constraint {
        // 1. Tree-sitter parsing for syntactic patterns
        const syntax_constraints = try parseWithTreeSitter(source);

        // 2. Optional: Use Claude for semantic understanding
        if (self.claude_client) |client| {
            const semantic_analysis = try client.analyze(
                \\Analyze this code and identify:
                \\- Implicit architectural patterns
                \\- Security constraints
                \\- Performance requirements
                \\Code: {source}
            );
            // Merge Claude insights with static analysis
        }

        return constraints;
    }

    pub fn extractFromTests(tests: []const u8) ![]Constraint {
        // Use Claude to understand test intent
        if (self.claude_client) |client| {
            const test_patterns = try client.analyze(
                \\What constraints do these tests imply?
                \\Tests: {tests}
            );
        }
    }

    pub fn mineFromTelemetry(data: Telemetry) ![]Constraint {
        // Use Claude for anomaly detection and pattern recognition
    }
};
```

### Braid Implementation with Optimization Support
```zig
const Braid = struct {
    llm_client: ?LLMClient, // Claude/OpenAI for optimization

    // Compile constraints with optional LLM assistance
    pub fn compile(constraints: []Constraint) !ConstraintIR {
        // Build initial dependency graph
        var graph = try buildDependencyGraph(constraints);

        // Optional: Use Claude for conflict resolution
        if (self.llm_client) |client| {
            const conflicts = try detectConflicts(graph);
            if (conflicts.len > 0) {
                const resolution = try client.suggest(
                    \\These constraints conflict:
                    \\{conflicts}
                    \\Suggest resolution strategy
                );
                graph = try applyResolution(graph, resolution);
            }
        }

        // Compile to IR for llguidance
        return compileToIR(graph);
    }

    // Convert to llguidance format
    pub fn toLLGuidanceSchema(ir: ConstraintIR) ![]const u8 {
        // Generate JSON schema/grammar for constrained generation
    }
};
```

### Managed API Integration
```zig
// Lightweight clients for analysis tasks
const ClaudeClient = struct {
    api_key: []const u8,

    pub fn analyze(self: ClaudeClient, prompt: []const u8) !Analysis {
        // Call Claude for code understanding
        // These are analysis calls, not generation
        // Don't need token-level control here
    }
};
```

---

## Phase 2: Ariadne DSL (Week 4)

### Ariadne Compiler
```zig
const AriadneCompiler = struct {
    llm_client: ?LLMClient, // Can use Claude for macro expansion

    pub fn compile(source: []const u8) !ConstraintIR {
        // Parse Ariadne syntax
        const ast = try parseAriadne(source);

        // Optional: Use Claude for complex macro expansion
        if (self.llm_client) |client| {
            // "What constraints should this macro expand to?"
        }

        // Generate constraint graph
        return generateIR(ast);
    }
};
```

### Usage Patterns
```ariadne
// Ariadne defines constraints for constrained generation
constraint api_handler {
    returns: Result<Response, Error>;
    validates: input_schema;
    max_lines: 100;
    forbid: ["eval", "exec"];
}

// Clew might use Claude to understand existing handlers
// Braid compiles these to llguidance schemas
// Maze uses them for constrained generation
```

---

## Phase 3: Maze Orchestration Layer (Weeks 5-6)

### Maze Core (Rust)
```rust
// Maze ONLY handles constrained generation, not analysis
pub struct Maze {
    inference_client: InferenceClient, // vLLM + llguidance
    constraint_cache: Arc<Mutex<HashMap<String, CompiledConstraint>>>,
}

impl Maze {
    pub async fn generate(
        &self,
        intent: Intent,
        constraints: ConstraintIR,
    ) -> Result<GeneratedCode> {
        // This REQUIRES inference server control
        // Cannot use Claude/OpenAI here

        // Convert ConstraintIR to llguidance format
        let guidance_schema = self.compile_to_guidance(constraints)?;

        // Send to vLLM with llguidance on Modal
        let response = self.inference_client
            .generate_constrained(
                intent.prompt,
                guidance_schema,
            )
            .await?;

        Ok(response)
    }
}
```

---

## Phase 4: Inference Service Setup (Week 7)

### Modal Deployment for Constrained Generation
```python
# modal_inference.py
import modal
from vllm import LLM, SamplingParams
from llguidance import LLGuidance

app = modal.App("ananke-inference")

@app.function(
    gpu=modal.gpu.A100(count=1, memory=40),
    container_idle_timeout=60,
    secrets=[modal.Secret.from_name("hf-token")],
)
class InferenceService:
    def __init__(self):
        # This is for GENERATION only
        self.llm = LLM(
            model="meta-llama/Llama-3.1-8B-Instruct",
            gpu_memory_utilization=0.9,
            enforce_eager=True,
        )
        self.guidance = LLGuidance()

    @modal.method()
    async def generate_constrained(
        self,
        prompt: str,
        constraints: dict,
    ) -> str:
        # Token-level constraint enforcement
        token_masks = self.guidance.compile(constraints)

        sampling_params = SamplingParams(
            temperature=0.7,
            max_tokens=2048,
            logits_processor=token_masks,
        )

        outputs = self.llm.generate([prompt], sampling_params)
        return outputs[0].outputs[0].text
```

---

## Phase 5: Integration Patterns (Week 8)

### Pattern 1: Full Pipeline
```bash
# Clew uses Claude to understand codebase
ananke extract ./src --use-claude -o constraints.json

# Braid optimizes constraints (may use Claude)
ananke compile constraints.json -o compiled.cir

# Maze generates with constraints (uses vLLM on Modal)
ananke generate "create auth handler" \
  --constraints compiled.cir \
  --inference-url https://ananke-inference.modal.run
```

### Pattern 2: Library Mode
```python
from ananke import Ananke

ananke = Ananke(
    claude_api_key="...",  # For Clew/Braid analysis
    modal_endpoint="...",  # For Maze generation
)

# Extraction can use Claude
constraints = await ananke.extract_from_code(
    "app.py",
    use_llm=True  # Enable Claude for semantic analysis
)

# Compilation can use Claude
compiled = await ananke.compile(
    constraints,
    optimize_with_llm=True  # Enable conflict resolution
)

# Generation MUST use constrained inference
result = await ananke.generate(
    intent="Add error handling",
    constraints=compiled,
)
```

### Pattern 3: Hybrid Configuration
```yaml
# ananke.config.yaml
analysis:
  # Clew and Braid can use managed APIs
  provider: claude
  api_key: ${ANTHROPIC_API_KEY}
  model: claude-3-opus-20240229

generation:
  # Maze requires inference server control
  backend: modal
  endpoint: https://ananke-inference.modal.run
  model: llama-3.1-70b

optimization:
  use_llm_for_conflicts: true
  use_llm_for_semantic_analysis: true
```

---

## Phase 6: Testing Strategy (Week 9)

### Testing Clew/Braid (Can mock or use real Claude)
```zig
test "constraint extraction with LLM" {
    // Can use real Claude API for integration tests
    const clew = Clew{ .claude_client = test_client };
    const constraints = try clew.extractFromCode(sample_code);
    try expect(constraints.len > 0);
}

test "constraint compilation with optimization" {
    // Test Braid with Claude-assisted conflict resolution
    const braid = Braid{ .llm_client = mock_client };
    const ir = try braid.compile(conflicting_constraints);
    try expect(ir.conflicts_resolved);
}
```

### Testing Maze (Requires GPU or Mock)
```python
def test_constrained_generation():
    # This CANNOT use Claude/OpenAI
    # Must test with vLLM + llguidance
    result = maze.generate(intent, constraints)
    assert validates_all_constraints(result, constraints)
```

---

## Phase 7: Documentation & Examples (Week 10)

### Clear Explanation of API Usage
```markdown
## When Ananke Uses Which APIs

### Managed APIs (Claude/OpenAI) - Analysis & Understanding
Used by Clew and Braid for:
- Semantic code analysis
- Pattern recognition
- Conflict resolution
- Test intent understanding
- Architecture discovery

These are one-shot analysis tasks that don't require
token-level control.

### Inference Servers (vLLM + llguidance) - Generation
Used by Maze for:
- Constrained code generation
- Token-by-token validation
- Grammar enforcement
- Schema compliance

This REQUIRES control over the inference process and
cannot use managed APIs.
```

---

## Phase 8: Production Deployment (Week 11)

### Deployment Configuration
```yaml
production:
  # Analysis services (lightweight, no GPU)
  clew:
    deployment: cloudflare-workers
    llm_provider: claude

  braid:
    deployment: cloudflare-workers
    llm_provider: claude

  # Generation service (GPU required)
  maze:
    deployment: modal
    gpu: a100
    model: llama-3.1-70b

costs:
  analysis: ~$0.01 per 1000 operations (Claude API)
  generation: ~$0.10 per 1000 generations (Modal GPU)
```

---

## Phase 9: Documentation Persistence (Week 12)

### Document Structure
```
ananke/
├── docs/
│   ├── IMPLEMENTATION_PLAN.md (this document)
│   ├── ARCHITECTURE.md
│   ├── API_USAGE.md
│   └── DEPLOYMENT.md
├── beads/
│   ├── implementation-phases.bead
│   ├── constraint-extraction.bead
│   ├── inference-setup.bead
│   └── testing-strategy.bead
└── examples/
    ├── with-claude-analysis/
    ├── pure-local/
    └── full-pipeline/
```

### Beads Task Tracking
```yaml
# implementation-phases.bead
name: Ananke Implementation
phases:
  - name: Foundation
    tasks:
      - Set up Zig project
      - Configure Modal account
      - Design ConstraintIR

  - name: Constraint Engines
    tasks:
      - Implement Clew with Claude integration
      - Build Braid with conflict resolution
      - Create Ariadne compiler

  - name: Inference Layer
    tasks:
      - Deploy vLLM on Modal
      - Integrate llguidance
      - Build Maze orchestration
```

---

## Cost Analysis (Updated)

### Analysis Costs (Claude API)
- Clew extraction: ~$0.001-0.005 per file
- Braid optimization: ~$0.002-0.01 per compilation
- Total analysis: ~$0.01-0.05 per full pipeline

### Generation Costs (Modal GPU)
- Model loading: 3-5 seconds (~$0.005)
- Generation: ~$0.01-0.05 per request
- Total with scale-to-zero: ~$0.10 per 1000 generations

### Recommendations
- Use Claude for complex analysis tasks
- Cache analysis results aggressively
- Use Modal for generation with scale-to-zero
- Consider local GGUF for development

---

## Success Metrics

### Performance
- ✅ Constraint validation: <50μs locally (Zig)
- ✅ Constraint extraction: <2s with Claude
- ✅ Constraint compilation: <50ms + Claude latency if needed
- ✅ Constrained generation: <5s on Modal
- ✅ Invalid output rate: <0.12% with llguidance

### Cost Efficiency
- ✅ Analysis: <$0.05 per pipeline with caching
- ✅ Generation: <$0.10 per 1000 requests
- ✅ Development: Free with local models

---

## Next Immediate Steps

1. **Day 1**: Create docs/ directory and save this plan ✅
2. **Day 2**: Set up beads for task tracking
3. **Day 3**: Initialize Zig project structure
4. **Day 4**: Configure Claude API for Clew
5. **Day 5**: Set up Modal for inference
6. **Week 1 Goal**: End-to-end pipeline with both analysis and generation

This plan properly integrates managed APIs for intelligent analysis while maintaining the requirement for controlled inference during generation.