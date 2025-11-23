//! Simple example of using Maze for constrained code generation
//!
//! This example demonstrates:
//! - Configuring the Modal client
//! - Creating constraint IR
//! - Generating code with constraints
//! - Handling the response

use anyhow::Result;
use maze::{
    MazeOrchestrator, ModalConfig, GenerationRequest, GenerationContext,
    ffi::{ConstraintIR, RegexPattern, TokenMaskRules},
};
use std::collections::HashMap;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter("maze=debug,simple_generation=info")
        .init();

    println!("=== Maze Simple Generation Example ===\n");

    // Step 1: Configure Modal endpoint
    // In production, use ModalConfig::from_env() to read from environment
    let modal_config = ModalConfig::new(
        "https://ananke-inference.modal.run".to_string(),
        "meta-llama/Llama-3.1-8B-Instruct".to_string(),
    )
    .with_timeout(300);

    println!("Configured Modal endpoint: {}", modal_config.endpoint_url);
    println!("Model: {}\n", modal_config.model);

    // Step 2: Create Maze orchestrator
    let orchestrator = MazeOrchestrator::new(modal_config)?;
    println!("Created Maze orchestrator\n");

    // Step 3: Define constraints
    // These would typically come from Zig (Clew/Braid)
    let constraints = create_example_constraints();
    println!("Created {} constraints:", constraints.len());
    for constraint in &constraints {
        println!("  - {}", constraint.name);
    }
    println!();

    // Step 4: Create generation request
    let request = GenerationRequest {
        prompt: "Implement a secure API handler for user authentication".to_string(),
        constraints_ir: constraints,
        max_tokens: 512,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: Some("src/api/auth.rs".to_string()),
            language: Some("rust".to_string()),
            project_root: Some("/Users/example/project".to_string()),
            metadata: HashMap::new(),
        }),
    };

    println!("Generation request:");
    println!("  Prompt: {}", request.prompt);
    println!("  Max tokens: {}", request.max_tokens);
    println!("  Temperature: {}\n", request.temperature);

    // Step 5: Generate code
    println!("Generating code with constraints...\n");

    // NOTE: This will fail unless you have a running Modal service
    // For development, you can use a mock or local inference server
    match orchestrator.generate(request).await {
        Ok(response) => {
            println!("=== Generation Successful ===\n");
            println!("Generated code:\n{}\n", response.code);

            println!("Metadata:");
            println!("  Tokens: {}", response.metadata.tokens_generated);
            println!("  Generation time: {}ms", response.metadata.generation_time_ms);
            println!("  Avg token time: {}μs", response.metadata.avg_token_time_us);
            println!("  Constraint compile time: {}ms\n", response.metadata.constraint_compile_time_ms);

            println!("Provenance:");
            println!("  Model: {}", response.provenance.model);
            println!("  Timestamp: {}", response.provenance.timestamp);
            println!("  Constraints applied: {}", response.provenance.constraints_applied.len());

            println!("\nValidation:");
            println!("  All satisfied: {}", response.validation.all_satisfied);
            println!("  Satisfied: {}", response.validation.satisfied.len());
            println!("  Violated: {}", response.validation.violated.len());
        }
        Err(e) => {
            eprintln!("=== Generation Failed ===");
            eprintln!("Error: {}\n", e);
            eprintln!("Note: This example requires a running Modal inference service.");
            eprintln!("Set MODAL_ENDPOINT environment variable to your service URL.");
            eprintln!("\nExample:");
            eprintln!("  export MODAL_ENDPOINT=https://your-app.modal.run");
            eprintln!("  export MODAL_API_KEY=your-api-key  # if required");
            return Err(e);
        }
    }

    // Step 6: Cache statistics
    let stats = orchestrator.cache_stats().await;
    println!("\nCache statistics:");
    println!("  Size: {}/{}", stats.size, stats.limit);

    Ok(())
}

/// Create example constraints that would typically come from Zig
fn create_example_constraints() -> Vec<ConstraintIR> {
    vec![
        // Constraint 1: Type safety
        ConstraintIR {
            name: "type_safety".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"Result<.*>".to_string(),
                    flags: String::new(),
                }
            ],
            token_masks: None,
            priority: 1,
        },

        // Constraint 2: Security - forbid dangerous operations
        ConstraintIR {
            name: "security".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: Some(TokenMaskRules {
                allowed_tokens: None,
                // In reality, these would be actual token IDs from the model
                forbidden_tokens: Some(vec![
                    // Token IDs for "unsafe", "unwrap", "panic" etc.
                    // These are placeholder values
                ]),
            }),
            priority: 2,
        },

        // Constraint 3: Code style - require documentation
        ConstraintIR {
            name: "documentation".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"///.*".to_string(),  // Require doc comments
                    flags: String::new(),
                }
            ],
            token_masks: None,
            priority: 0,
        },

        // Constraint 4: Async handling
        ConstraintIR {
            name: "async_handling".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"async\s+fn".to_string(),
                    flags: String::new(),
                }
            ],
            token_masks: None,
            priority: 1,
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_example_constraints() {
        let constraints = create_example_constraints();
        assert_eq!(constraints.len(), 4);
        assert_eq!(constraints[0].name, "type_safety");
        assert_eq!(constraints[1].name, "security");
    }
}
