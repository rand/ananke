# Multi-Model Ensemble Implementation

## Overview

The multi-model ensemble system enables Ananke's Maze to orchestrate multiple LLM endpoints with intelligent routing, fallback, and metrics tracking. This implementation addresses Gap 3 from the v0.2.0 roadmap.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      EnsembleClient                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ModalClient 1 │  │ModalClient 2 │  │ModalClient N │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                │
│                     ModelRouter                             │
│                   (constraint-aware)                        │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. ModelRouter (`model_router.rs`)

Handles intelligent routing based on hole characteristics and constraints.

**Key Features:**
- **Capability-based routing**: Routes requests to models with required capabilities
- **Constraint analysis**: Examines security constraints, grammar complexity, constraint count
- **Complexity estimation**: Uses ModelSelector to estimate hole complexity
- **Fallback chains**: Builds priority-ordered fallback sequences

**Model Capabilities:**
- `CodeCompletion`: General code generation
- `LongContext`: Extended context window support
- `ConstrainedGeneration`: Complex constraint handling
- `FastInference`: Low-latency inference
- `HighQuality`: High-quality generations for complex tasks
- `SecurityAware`: Security-sensitive operations

**Routing Logic:**
```rust
if has_security_constraints {
    SecurityAware model
} else if constraint_count > 10 || has_grammar {
    ConstrainedGeneration model
} else if complexity < 0.3 {
    FastInference model
} else if complexity > 0.7 {
    HighQuality model
} else {
    Default model
}
```

### 2. EnsembleClient (`modal_client.rs`)

Orchestrates multiple ModalClient instances with routing and fallback.

**Key Features:**
- **Automatic routing**: `generate_routed()` uses ModelRouter for intelligent selection
- **Fallback on failure**: Tries alternative models if primary fails
- **Best-of-N**: Generates N candidates and selects highest confidence
- **Metrics tracking**: Per-model success rates, latencies, confidence scores

**Methods:**
```rust
// Generate with automatic routing
pub async fn generate_routed(
    request: InferenceRequest,
    hole_spec: &HoleSpec,
    constraints: &[ConstraintIR],
) -> Result<InferenceResponse>

// Generate with explicit fallback chain
pub async fn generate_with_fallback(
    request: InferenceRequest,
    routing: RoutingDecision,
) -> Result<InferenceResponse>

// Generate N candidates and pick best
pub async fn generate_best_of_n(
    request: InferenceRequest,
    n: usize,
    model_name: &str,
) -> Result<InferenceResponse>
```

### 3. ProgressiveRefiner Integration (`progressive_refinement.rs`)

Updated to support both single and ensemble backends.

**InferenceBackend Enum:**
```rust
pub enum InferenceBackend {
    Single(ModalClient),
    Ensemble(EnsembleClient),
}
```

**Constructor Patterns:**
```rust
// Single model
ProgressiveRefiner::new(modal_client, config)

// Ensemble
ProgressiveRefiner::with_ensemble(ensemble_client, config)
```

## Configuration

### Ensemble Configuration

```rust
use maze::{EnsembleConfig, ModelEndpoint, ModelCapability};

let config = EnsembleConfig {
    endpoints: vec![
        ModelEndpoint {
            name: "fast-8b".to_string(),
            endpoint_url: "https://fast.modal.run".to_string(),
            model: "meta-llama/Llama-3.1-8B-Instruct".to_string(),
            api_key: Some("key".to_string()),
            timeout_secs: 60,
            capabilities: vec![
                ModelCapability::FastInference,
                ModelCapability::CodeCompletion,
            ],
            priority: 1, // Lower = higher priority for fallback
            cost_per_1k_tokens: 0.001,
        },
        ModelEndpoint {
            name: "quality-70b".to_string(),
            endpoint_url: "https://quality.modal.run".to_string(),
            model: "meta-llama/Llama-3.1-70B-Instruct".to_string(),
            api_key: Some("key".to_string()),
            timeout_secs: 180,
            capabilities: vec![
                ModelCapability::HighQuality,
                ModelCapability::SecurityAware,
                ModelCapability::LongContext,
            ],
            priority: 2,
            cost_per_1k_tokens: 0.01,
        },
    ],
    fallback_enabled: true,
    best_of_n: None,
    max_fallback_attempts: 3,
};

let ensemble = EnsembleClient::from_config(config)?;
```

## Metrics

The ensemble tracks detailed metrics per model:

```rust
#[derive(Debug, Default, Clone)]
pub struct ModelMetrics {
    pub requests: u64,
    pub successes: u64,
    pub failures: u64,
    pub total_latency_ms: u64,
    pub avg_confidence: f32,
}

impl ModelMetrics {
    pub fn success_rate(&self) -> f32;
    pub fn avg_latency_ms(&self) -> u64;
}
```

**Accessing Metrics:**
```rust
let metrics = ensemble.get_metrics().lock().await;
println!("Total requests: {}", metrics.total_requests);
println!("Total fallbacks: {}", metrics.total_fallbacks);

for (model, model_metrics) in &metrics.per_model {
    println!("Model {}: {:.2}% success rate",
        model,
        model_metrics.success_rate() * 100.0);
}
```

## Routing Examples

### Example 1: Simple Hole → Fast Model

```rust
let hole_spec = HoleSpec {
    hole_id: 1,
    fill_constraints: vec![],
    ..Default::default()
};

let routing = router.route(&hole_spec, &[]);
// Primary: "fast-8b" (complexity < 0.3)
// Fallback: ["quality-70b"]
```

### Example 2: Security Hole → Security-Aware Model

```rust
let constraints = vec![ConstraintIR {
    name: "security".to_string(),
    token_masks: Some(TokenMaskRules { ... }),
    ..Default::default()
}];

let routing = router.route(&hole_spec, &constraints);
// Primary: "quality-70b" (has SecurityAware capability)
// Fallback: ["fast-8b"]
```

### Example 3: Complex Hole → Constrained Generation Model

```rust
let hole_spec = HoleSpec {
    fill_constraints: (0..15).map(|i| FillConstraint { ... }).collect(),
    ..Default::default()
};

let routing = router.route(&hole_spec, &[]);
// Primary: "constrained-model" (constraint_count > 10)
// Fallback: ["fast-8b", "quality-70b"]
```

## Testing

All components have comprehensive unit tests:

```bash
# Run all ensemble and routing tests
cargo test --lib -- ensemble routing

# Run specific model_router tests
cargo test --lib model_router

# Run all tests
cargo test --lib
```

**Test Coverage:**
- Routing decisions for different hole types
- Fallback chain ordering by priority
- Default model fallback when no capability match
- Metrics tracking (success rate, latency)
- Configuration defaults

## Performance Considerations

### Routing Overhead
- O(n) model capability lookup per route (n = number of endpoints)
- Typically < 10 endpoints, so overhead is negligible
- Router created once per ensemble, reused for all requests

### Fallback Strategy
- Sequential fallback: tries models one at a time
- Configurable `max_fallback_attempts` to limit retries
- Early termination on first success

### Best-of-N
- Parallel generation of N candidates
- Uses `futures::future::join_all` for concurrency
- Selects by confidence score
- Trade-off: N×cost for better quality

## Future Enhancements

1. **Adaptive Routing**: Learn from metrics to improve routing decisions
2. **Cost Optimization**: Balance quality vs. cost based on constraints
3. **Latency Budgets**: Route to faster models when time-constrained
4. **A/B Testing**: Split traffic for model comparison
5. **Circuit Breaker**: Automatically disable failing models
6. **Load Balancing**: Distribute load across identical model instances

## References

- `src/model_router.rs`: Routing logic and capability matching
- `src/modal_client.rs`: EnsembleClient implementation
- `src/progressive_refinement.rs`: Integration with refinement loop
- `examples/ensemble_example.rs`: Usage examples
