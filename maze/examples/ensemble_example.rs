//! Example demonstrating multi-model ensemble usage
//!
//! This example shows how to configure and use the ensemble client
//! with multiple models, automatic routing, and fallback.

use maze::{
    EnsembleClient, EnsembleConfig, HoleSpec, InferenceRequest, ModelCapability, ModelEndpoint,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Configure multiple model endpoints
    let endpoints = vec![
        ModelEndpoint {
            name: "fast-model".to_string(),
            endpoint_url: "https://fast.modal.run".to_string(),
            model: "meta-llama/Llama-3.1-8B-Instruct".to_string(),
            api_key: std::env::var("MODAL_API_KEY").ok(),
            timeout_secs: 60,
            capabilities: vec![ModelCapability::FastInference, ModelCapability::CodeCompletion],
            priority: 1,
            cost_per_1k_tokens: 0.001,
        },
        ModelEndpoint {
            name: "quality-model".to_string(),
            endpoint_url: "https://quality.modal.run".to_string(),
            model: "meta-llama/Llama-3.1-70B-Instruct".to_string(),
            api_key: std::env::var("MODAL_API_KEY").ok(),
            timeout_secs: 180,
            capabilities: vec![
                ModelCapability::HighQuality,
                ModelCapability::SecurityAware,
                ModelCapability::LongContext,
            ],
            priority: 2,
            cost_per_1k_tokens: 0.01,
        },
        ModelEndpoint {
            name: "constrained-model".to_string(),
            endpoint_url: "https://constrained.modal.run".to_string(),
            model: "deepseek-ai/DeepSeek-Coder-V2-Instruct".to_string(),
            api_key: std::env::var("MODAL_API_KEY").ok(),
            timeout_secs: 120,
            capabilities: vec![
                ModelCapability::ConstrainedGeneration,
                ModelCapability::CodeCompletion,
            ],
            priority: 3,
            cost_per_1k_tokens: 0.005,
        },
    ];

    // Create ensemble configuration
    let config = EnsembleConfig {
        endpoints,
        fallback_enabled: true,
        best_of_n: None,
        max_fallback_attempts: 3,
    };

    println!("Creating ensemble client with {} models", config.endpoints.len());
    let ensemble = EnsembleClient::from_config(config)?;

    // Example 1: Simple hole - should route to fast model
    println!("\n=== Example 1: Simple Hole ===");
    let simple_hole = HoleSpec {
        hole_id: 1,
        fill_schema: None,
        fill_grammar: None,
        fill_constraints: vec![],
        grammar_ref: None,
    };

    let routing = ensemble.router().route(&simple_hole, &[]);
    println!("Routing decision for simple hole:");
    println!("  Primary model: {}", routing.primary_model);
    println!("  Reason: {}", routing.reason);
    println!("  Fallback chain: {:?}", routing.fallback_models);

    // Example 2: Complex hole with many constraints - should route to constrained model
    println!("\n=== Example 2: Complex Hole ===");
    let complex_hole = HoleSpec {
        hole_id: 2,
        fill_schema: None,
        fill_grammar: None,
        fill_constraints: (0..15)
            .map(|i| maze::FillConstraint {
                kind: "constraint".to_string(),
                value: format!("value{}", i),
                error_message: None,
            })
            .collect(),
        grammar_ref: None,
    };

    let routing = ensemble.router().route(&complex_hole, &[]);
    println!("Routing decision for complex hole:");
    println!("  Primary model: {}", routing.primary_model);
    println!("  Reason: {}", routing.reason);
    println!("  Fallback chain: {:?}", routing.fallback_models);

    // Example 3: Security-sensitive hole - should route to quality model
    println!("\n=== Example 3: Security-Sensitive Hole ===");
    let security_hole = HoleSpec {
        hole_id: 3,
        fill_schema: None,
        fill_grammar: None,
        fill_constraints: vec![maze::FillConstraint {
            kind: "security".to_string(),
            value: "no_unsafe_operations".to_string(),
            error_message: None,
        }],
        grammar_ref: None,
    };

    let security_constraints = vec![maze::ConstraintIR {
        name: "security".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(maze::ffi::TokenMaskRules {
            allowed_tokens: None,
            forbidden_tokens: Some(vec![/* unsafe tokens */]),
        }),
        priority: 0,
    }];

    let routing = ensemble.router().route(&security_hole, &security_constraints);
    println!("Routing decision for security hole:");
    println!("  Primary model: {}", routing.primary_model);
    println!("  Reason: {}", routing.reason);
    println!("  Fallback chain: {:?}", routing.fallback_models);

    // Example 4: Generate with automatic routing (would make actual request if endpoints were real)
    println!("\n=== Example 4: Generate with Routing ===");
    let request = InferenceRequest {
        prompt: "Implement a secure function to validate user input".to_string(),
        constraints: serde_json::json!({
            "type": "function",
            "security": "high"
        }),
        max_tokens: 256,
        temperature: 0.7,
        context: None,
    };

    println!("Would generate with request:");
    println!("  Prompt: {}", request.prompt);
    println!("  Max tokens: {}", request.max_tokens);
    println!("  Temperature: {}", request.temperature);

    // Note: Actual generation would fail since these are example endpoints
    // let response = ensemble.generate_routed(request, &security_hole, &security_constraints).await?;

    // Example 5: Display metrics
    println!("\n=== Example 5: Ensemble Metrics ===");
    let metrics_arc = ensemble.get_metrics();
    let metrics = metrics_arc.lock().await;
    println!("Total requests: {}", metrics.total_requests);
    println!("Total fallbacks: {}", metrics.total_fallbacks);
    println!("Per-model metrics:");
    for (model, model_metrics) in &metrics.per_model {
        println!("  {}:", model);
        println!("    Requests: {}", model_metrics.requests);
        println!("    Successes: {}", model_metrics.successes);
        println!("    Failures: {}", model_metrics.failures);
        println!("    Success rate: {:.2}%", model_metrics.success_rate() * 100.0);
        println!("    Avg latency: {}ms", model_metrics.avg_latency_ms());
        println!("    Avg confidence: {:.2}", model_metrics.avg_confidence);
    }

    println!("\n=== Ensemble Example Complete ===");
    println!("This example demonstrates:");
    println!("  - Configuring multiple model endpoints");
    println!("  - Automatic routing based on hole characteristics");
    println!("  - Fallback chains for reliability");
    println!("  - Metrics tracking per model");

    Ok(())
}
