//! Modal client example
//!
//! Demonstrates direct use of ModalClient for inference.

use ananke_maze::modal_client::{ModalClient, ModalConfig, InferenceRequest};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("\n=== Modal Client Example ===\n");
    
    // Configure Modal
    let config = ModalConfig {
        endpoint_url: "https://example.modal.run".to_string(),
        api_key: Some("sk-test-key".to_string()),
        timeout_secs: 60,
        model: "meta-llama/Llama-3.1-8B-Instruct".to_string(),
        enable_retry: true,
        max_retries: 2,
    };
    
    println!("Configuration:");
    println!("  Endpoint: {}", config.endpoint_url);
    println!("  Model: {}", config.model);
    println!("  Retry: {} (max: {})\n", config.enable_retry, config.max_retries);
    
    // Create client
    let client = ModalClient::new(config)?;
    
    // Health check
    println!("Performing health check...");
    match client.health_check().await {
        Ok(healthy) if healthy => println!("✓ Service is healthy\n"),
        Ok(_) => println!("✗ Service is unhealthy\n"),
        Err(e) => println!("✗ Health check failed: {}\n", e),
    }
    
    // List available models
    println!("Listing available models...");
    match client.list_models().await {
        Ok(models) => {
            println!("✓ {} models available:", models.len());
            for model in models {
                println!("  - {}", model);
            }
            println!();
        },
        Err(e) => println!("✗ Failed to list models: {}\n", e),
    }
    
    // Create inference request
    let request = InferenceRequest {
        prompt: "def factorial(n):".to_string(),
        constraints: serde_json::json!({
            "type": "object",
            "constraints": []
        }),
        max_tokens: 50,
        temperature: 0.5,
        context: None,
    };
    
    println!("Inference Request:");
    println!("  Prompt: {}", request.prompt);
    println!("  Max tokens: {}", request.max_tokens);
    println!("  Temperature: {}\n", request.temperature);
    
    // Generate (would fail with fake endpoint)
    println!("Attempting generation...");
    println!("(This will fail with the example endpoint)\n");
    
    match client.generate_constrained(request).await {
        Ok(response) => {
            println!("✓ Generation successful!");
            println!("  Generated: {}", response.generated_text);
            println!("  Tokens: {}", response.tokens_generated);
            println!("  Model: {}", response.model);
            println!("  Time: {}ms", response.stats.total_time_ms);
            println!("  Token time: {}μs", response.stats.time_per_token_us);
        },
        Err(e) => {
            println!("✗ Generation failed (expected with example config):");
            println!("  Error: {}\n", e);
        }
    }
    
    println!("Note: Set valid MODAL_ENDPOINT and MODAL_API_KEY to run successfully.");
    println!("\n✓ Example complete!");
    
    Ok(())
}
