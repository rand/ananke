//! Rust orchestrator example
//!
//! Demonstrates using MazeOrchestrator for constrained code generation.
//!
//! Build: cargo build --example rust_orchestrator
//! Run: cargo run --example rust_orchestrator

use ananke_maze::{
    MazeOrchestrator, ModalConfig, MazeConfig, GenerationRequest, 
    GenerationContext, ffi::ConstraintIR,
};
use std::collections::HashMap;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("\n=== Ananke Rust Orchestrator Example ===\n");
    
    // Step 1: Configure Modal inference service
    println!("Step 1: Configuring Modal inference service...");
    let modal_config = ModalConfig {
        endpoint_url: std::env::var("MODAL_ENDPOINT")
            .unwrap_or_else(|_| "https://example.modal.run".to_string()),
        api_key: std::env::var("MODAL_API_KEY").ok(),
        timeout_secs: 300,
        model: "meta-llama/Llama-3.1-8B-Instruct".to_string(),
        enable_retry: true,
        max_retries: 3,
    };
    println!("  ✓ Modal endpoint: {}", modal_config.endpoint_url);
    println!("  ✓ Model: {}\n", modal_config.model);
    
    // Step 2: Configure Maze orchestrator
    println!("Step 2: Configuring orchestrator...");
    let maze_config = MazeConfig {
        max_tokens: 2048,
        temperature: 0.7,
        enable_cache: true,
        cache_size_limit: 1000,
        timeout_secs: 300,
    };
    println!("  ✓ Max tokens: {}", maze_config.max_tokens);
    println!("  ✓ Cache enabled: {} (limit: {})\n", 
        maze_config.enable_cache, maze_config.cache_size_limit);
    
    // Step 3: Create orchestrator
    println!("Step 3: Creating MazeOrchestrator...");
    let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)?;
    println!("  ✓ Orchestrator ready\n");
    
    // Step 4: Define constraints (normally from Zig/Clew)
    println!("Step 4: Defining security constraints...");
    let security_constraint = ConstraintIR {
        name: "secure_api_handler".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 100,
    };
    
    let type_constraint = ConstraintIR {
        name: "typescript_types".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 90,
    };
    
    let constraints_ir = vec![security_constraint, type_constraint];
    println!("  ✓ {} constraints defined\n", constraints_ir.len);
    
    // Step 5: Create generation context
    println!("Step 5: Building generation context...");
    let context = GenerationContext {
        current_file: Some("src/api/auth.ts".to_string()),
        language: Some("typescript".to_string()),
        project_root: Some("/home/user/project".to_string()),
        metadata: {
            let mut m = HashMap::new();
            m.insert("framework".to_string(), serde_json::json!("express"));
            m.insert("auth".to_string(), serde_json::json!("jwt"));
            m
        },
    };
    println!("  ✓ Context: {} @ {}", 
        context.current_file.as_ref().unwrap(),
        context.language.as_ref().unwrap());
    println!();
    
    // Step 6: Create generation request
    println!("Step 6: Creating generation request...");
    let request = GenerationRequest {
        prompt: "Create an API endpoint that validates user credentials and returns a JWT token. \
                 Include input validation, error handling, and security best practices."
            .to_string(),
        constraints_ir,
        max_tokens: 500,
        temperature: 0.7,
        context: Some(context),
    };
    println!("  ✓ Prompt: {}...", &request.prompt[..70]);
    println!("  ✓ Max tokens: {}", request.max_tokens);
    println!("  ✓ Temperature: {}\n", request.temperature);
    
    // Step 7: Generate code
    println!("Step 7: Generating code with constraints...");
    println!("  (This may take 2-10 seconds depending on model and token count)\n");
    
    // In a real scenario, this would call Modal
    // For this example, we'll simulate the response
    println!("  Note: This example requires a running Modal inference service.");
    println!("  Set MODAL_ENDPOINT and MODAL_API_KEY environment variables.\n");
    
    // Uncomment to actually call Modal:
    /*
    let response = orchestrator.generate(request).await?;
    
    // Step 8: Display results
    println!("Step 8: Generation complete!\n");
    println!("Generated Code:");
    println!("{}", "=".repeat(60));
    println!("{}", response.code);
    println!("{}", "=".repeat(60));
    
    // Display metadata
    println!("\nGeneration Metadata:");
    println!("  Tokens generated: {}", response.metadata.tokens_generated);
    println!("  Generation time: {}ms", response.metadata.generation_time_ms);
    println!("  Average token time: {}μs", response.metadata.avg_token_time_us);
    println!("  Constraint compile time: {}ms", response.metadata.constraint_compile_time_ms);
    
    // Display provenance
    println!("\nProvenance:");
    println!("  Model: {}", response.provenance.model);
    println!("  Timestamp: {}", response.provenance.timestamp);
    println!("  Constraints applied: {:?}", response.provenance.constraints_applied);
    
    // Display validation
    println!("\nValidation:");
    println!("  All constraints satisfied: {}", response.validation.all_satisfied);
    println!("  Satisfied: {} constraints", response.validation.satisfied.len());
    println!("  Violated: {} constraints", response.validation.violated.len());
    
    // Calculate throughput
    let tokens_per_sec = (response.metadata.tokens_generated as f64 / 
        response.metadata.generation_time_ms as f64) * 1000.0;
    println!("\nThroughput: {:.2} tokens/sec", tokens_per_sec);
    */
    
    // Step 9: Check cache stats
    println!("Step 9: Cache statistics...");
    let stats = orchestrator.cache_stats().await;
    println!("  Cache size: {}/{}", stats.size, stats.limit);
    println!("  Usage: {:.1}%\n", 
        (stats.size as f64 / stats.limit as f64) * 100.0);
    
    println!("✓ Example complete!");
    
    Ok(())
}
