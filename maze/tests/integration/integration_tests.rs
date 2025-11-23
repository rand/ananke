//! Comprehensive integration tests for Ananke pipeline

mod mocks;
mod helpers;

use maze::{MazeOrchestrator, ModalConfig, GenerationRequest};
use mocks::{MockModalService, MockScenario, MockResponse};
use helpers::*;
use mockito::Server;

#[tokio::test]
async fn test_extract_compile_pipeline() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    // Simulate extracted constraints from Zig Clew engine
    let constraints = rust_constraints();
    
    // Compile constraints to llguidance format
    let compiled = orchestrator
        .compile_constraints(&constraints)
        .await
        .expect("Failed to compile constraints");
    
    // Verify compilation
    assert!(!compiled.hash.is_empty());
    assert!(compiled.llguidance_schema.is_object());
    assert!(compiled.compiled_at > 0);
    
    // Verify cache key generation
    let cache_key = orchestrator
        .generate_cache_key(&constraints)
        .expect("Failed to generate cache key");
    assert_eq!(cache_key, compiled.hash);
}

#[tokio::test]
async fn test_full_generation_pipeline() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::custom_response(MockResponse {
        generated_text: "async fn authenticate(user: &str) -> Result<bool, AuthError> {\n    Ok(true)\n}".to_string(),
        tokens_generated: 25,
        model: "llama-3.1-8b".to_string(),
        total_time_ms: 250,
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let request = test_request_with_context(
        "Implement secure authentication function",
        rust_constraints(),
        200,
        "src/auth.rs",
        "rust",
    );
    
    let response = orchestrator
        .generate(request.clone())
        .await
        .expect("Generation failed");
    
    // Verify response structure
    assert_code_contains(&response.code, &["async fn", "Result<", "AuthError"]);
    
    // Verify provenance
    assert_valid_provenance(
        &response.provenance,
        "llama-3.1-8b",
        "Implement secure authentication function",
        3,
    );
    
    // Verify validation
    assert_validation_success(&response.validation, 3);
    
    // Verify metadata
    assert_valid_metadata(&response.metadata);
    assert_eq!(response.metadata.tokens_generated, 25);
}

#[tokio::test]
async fn test_constraint_caching_effectiveness() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    
    // Setup three mocks
    for _ in 0..3 {
        let _m = server.mock("POST", "/generate")
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(response.to_string())
            .create_async()
            .await;
    }
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let constraints = rust_constraints();
    
    // First request - should compile and cache
    let request1 = test_request("Generate function 1", constraints.clone(), 100);
    let response1 = orchestrator.generate(request1).await.expect("Request 1 failed");
    
    // Verify cache has one entry
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1, "Cache should have exactly 1 entry after first request");
    
    // Second request with same constraints - should use cache
    let request2 = test_request("Generate function 2", constraints.clone(), 100);
    let response2 = orchestrator.generate(request2).await.expect("Request 2 failed");
    
    // Cache should still have one entry (same constraints)
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1, "Cache should still have 1 entry (same constraints)");
    
    // Third request with different constraints - should compile and cache
    let different_constraints = typescript_constraints();
    let request3 = test_request("Generate function 3", different_constraints, 100);
    let response3 = orchestrator.generate(request3).await.expect("Request 3 failed");
    
    // Cache should now have two entries
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 2, "Cache should have 2 entries (different constraints)");
    
    // All responses should be valid
    assert!(response1.validation.all_satisfied);
    assert!(response2.validation.all_satisfied);
    assert!(response3.validation.all_satisfied);
}

#[tokio::test]
async fn test_ffi_boundary_data_integrity() {
    use maze::ffi::{ConstraintIR, RegexPattern, JsonSchema, Grammar, GrammarRule};
    use std::collections::HashMap;
    
    let mut properties = HashMap::new();
    properties.insert("username".to_string(), serde_json::json!({"type": "string"}));
    properties.insert("password".to_string(), serde_json::json!({"type": "string"}));
    
    let constraint = ConstraintIR {
        name: "complex_ffi_test".to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: properties.clone(),
            required: vec!["username".to_string(), "password".to_string()],
            additional_properties: false,
        }),
        grammar: Some(Grammar {
            rules: vec![
                GrammarRule {
                    lhs: "S".to_string(),
                    rhs: vec!["expr".to_string()],
                },
            ],
            start_symbol: "S".to_string(),
        }),
        regex_patterns: vec![
            RegexPattern {
                pattern: r"fn\s+\w+".to_string(),
                flags: String::new(),
            },
        ],
        token_masks: None,
        priority: 2,
    };
    
    // Convert to FFI and back
    let ffi_ptr = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi_ptr).expect("FFI conversion failed");
        
        // Verify all data is intact
        assert_eq!(constraint.name, restored.name);
        assert_eq!(constraint.priority, restored.priority);
        
        // Verify JSON schema
        assert!(restored.json_schema.is_some());
        let schema = restored.json_schema.unwrap();
        assert_eq!(schema.properties.len(), 2);
        assert!(schema.properties.contains_key("username"));
        assert!(schema.properties.contains_key("password"));
        assert_eq!(schema.required.len(), 2);
        
        // Verify grammar
        assert!(restored.grammar.is_some());
        let grammar = restored.grammar.unwrap();
        assert_eq!(grammar.start_symbol, "S");
        assert_eq!(grammar.rules.len(), 1);
        
        // Verify regex patterns
        assert_eq!(restored.regex_patterns.len(), 1);
        assert_eq!(restored.regex_patterns[0].pattern, r"fn\s+\w+");
        
        maze::ffi::free_constraint_ir_ffi(ffi_ptr);
    }
}

#[tokio::test]
async fn test_error_handling_graceful_degradation() {
    let mut server = Server::new_async().await;
    
    // Setup mock to fail with 500 three times (for retries)
    for _ in 0..3 {
        let _m = server.mock("POST", "/generate")
            .with_status(500)
            .with_body("Internal Server Error")
            .create_async()
            .await;
    }
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let request = test_request("Generate code", vec![simple_constraint("test", 1)], 100);
    
    let result = orchestrator.generate(request).await;
    
    // Should fail after retries
    assert!(result.is_err(), "Should fail when service is down");
    
    let error = result.unwrap_err();
    let error_msg = error.to_string();
    
    // Should contain retry information
    assert!(
        error_msg.contains("Failed") || error_msg.contains("attempts") || error_msg.contains("500"),
        "Error should mention failure: {}",
        error_msg
    );
}

#[tokio::test]
async fn test_concurrent_requests() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    
    // Setup multiple successful responses
    for _ in 0..5 {
        let _m = server.mock("POST", "/generate")
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(response.to_string())
            .create_async()
            .await;
    }
    
    let orchestrator = std::sync::Arc::new(create_test_orchestrator(server.url()));
    
    // Launch 5 concurrent requests
    let mut handles = vec![];
    for i in 0..5 {
        let orch = orchestrator.clone();
        let handle = tokio::spawn(async move {
            let request = test_request(
                &format!("Generate function {}", i),
                rust_constraints(),
                100,
            );
            orch.generate(request).await
        });
        handles.push(handle);
    }
    
    // Wait for all to complete
    let mut successes = 0;
    for handle in handles {
        if let Ok(Ok(_response)) = handle.await {
            successes += 1;
        }
    }
    
    assert_eq!(successes, 5, "All 5 concurrent requests should succeed");
}

#[tokio::test]
async fn test_provenance_tracking_completeness() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::custom_response(MockResponse {
        generated_text: "fn secure() -> Result<(), Error> { Ok(()) }".to_string(),
        tokens_generated: 15,
        model: "llama-3.1-70b".to_string(),
        total_time_ms: 500,
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let constraints = vec![
        simple_constraint("security", 3),
        simple_constraint("type_safety", 2),
        simple_constraint("error_handling", 1),
    ];
    
    let request = GenerationRequest {
        prompt: "Implement secure function".to_string(),
        constraints_ir: constraints.clone(),
        max_tokens: 150,
        temperature: 0.8,
        context: Some(maze::GenerationContext {
            current_file: Some("src/secure.rs".to_string()),
            language: Some("rust".to_string()),
            project_root: Some("/project".to_string()),
            metadata: {
                let mut m = std::collections::HashMap::new();
                m.insert("author".to_string(), serde_json::json!("test"));
                m
            },
        }),
    };
    
    let response = orchestrator.generate(request).await.expect("Generation failed");
    
    // Verify comprehensive provenance
    assert_eq!(response.provenance.model, "llama-3.1-70b");
    assert_eq!(response.provenance.original_intent, "Implement secure function");
    assert_eq!(response.provenance.constraints_applied.len(), 3);
    
    // Verify parameters are captured
    let params = &response.provenance.parameters;
    assert_eq!(params.get("max_tokens"), Some(&serde_json::json!(150)));
    // Temperature might have floating point precision issues, just check it exists
    assert!(params.contains_key("temperature"));
    
    // Verify timestamp is recent
    let now = chrono::Utc::now().timestamp();
    assert!(response.provenance.timestamp > now - 60);
    assert!(response.provenance.timestamp <= now);
}

#[tokio::test]
async fn test_validation_results_accuracy() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let constraints = vec![
        regex_constraint("async_fn", r"async\s+fn", 1),
        regex_constraint("result_type", r"Result<", 1),
        regex_constraint("error_type", r"Error", 1),
    ];
    
    let request = test_request("Generate async function", constraints.clone(), 100);
    let response = orchestrator.generate(request).await.expect("Generation failed");
    
    // Verify validation results
    assert!(response.validation.all_satisfied);
    assert_eq!(response.validation.satisfied.len(), 3);
    assert!(response.validation.violated.is_empty());
}

#[tokio::test]
async fn test_cache_lru_eviction() {
    use maze::MazeConfig;
    
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    
    // Setup 10 mocks for the test
    for _ in 0..10 {
        let _m = server.mock("POST", "/generate")
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(response.to_string())
            .create_async()
            .await;
    }
    
    // Create orchestrator with small cache (5 entries)
    let modal_config = ModalConfig::new(server.url(), "test-model".to_string());
    let maze_config = MazeConfig {
        max_tokens: 2048,
        temperature: 0.7,
        enable_cache: true,
        cache_size_limit: 5,
        timeout_secs: 300,
    };
    
    let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)
        .expect("Failed to create orchestrator");
    
    // Generate 10 different constraint sets
    for i in 0..10 {
        let constraints = vec![simple_constraint(&format!("constraint_{}", i), 1)];
        let request = test_request(&format!("Generate {}", i), constraints, 50);
        let _ = orchestrator.generate(request).await.expect("Generation failed");
    }
    
    // Cache should have exactly 5 entries
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 5, "LRU cache should maintain size limit of 5");
}

#[tokio::test]
async fn test_large_response_handling() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::LargeResponse);
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let request = test_request("Generate large function", vec![], 2000);
    let response = orchestrator.generate(request).await.expect("Generation failed");
    
    // Should handle large responses
    assert!(response.code.len() > 1000, "Response should be large");
    assert_eq!(response.metadata.tokens_generated, 500);
    
    // Metadata calculations should be correct
    assert_valid_metadata(&response.metadata);
}

#[tokio::test]
async fn test_cache_coherence_across_requests() {
    let server = Server::new_async().await;
    let orchestrator = create_test_orchestrator(server.url());
    
    let constraints = rust_constraints();
    
    // First compilation
    let compiled1 = orchestrator
        .compile_constraints(&constraints)
        .await
        .expect("Failed to compile");
    
    // Second compilation (should use cache)
    let compiled2 = orchestrator
        .compile_constraints(&constraints)
        .await
        .expect("Failed to compile");
    
    // Hashes should match
    assert_eq!(compiled1.hash, compiled2.hash);
    
    // Schemas should be equivalent
    assert_eq!(
        serde_json::to_string(&compiled1.llguidance_schema).unwrap(),
        serde_json::to_string(&compiled2.llguidance_schema).unwrap()
    );
    
    // Cache should have one entry
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1);
}

#[tokio::test]
async fn test_cache_invalidation() {
    let server = Server::new_async().await;
    let orchestrator = create_test_orchestrator(server.url());
    
    let constraints = vec![simple_constraint("test", 1)];
    
    // Compile and cache
    let _ = orchestrator.compile_constraints(&constraints).await.expect("Failed to compile");
    
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1);
    
    // Clear cache
    orchestrator.clear_cache().await.expect("Failed to clear cache");
    
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 0, "Cache should be empty after clearing");
    
    // Recompile (should add to cache again)
    let _ = orchestrator.compile_constraints(&constraints).await.expect("Failed to compile");
    
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1, "Cache should have entry after recompilation");
}
