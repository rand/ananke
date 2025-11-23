//! End-to-end integration tests
//!
//! Tests the complete pipeline from constraint creation to code generation
//! Uses mocked Modal service for offline testing

use maze::{
    MazeOrchestrator, ModalConfig, GenerationRequest, GenerationContext,
    ffi::{ConstraintIR, RegexPattern, TokenMaskRules, JsonSchema, Grammar, GrammarRule},
};
use mockito::Server;
use std::collections::HashMap;

#[tokio::test]
async fn test_e2e_simple_generation_with_mock() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "fn authenticate(username: &str, password: &str) -> Result<bool, String> {\n    Ok(true)\n}",
        "tokens_generated": 25,
        "model": "test-model",
        "stats": {
            "total_time_ms": 250,
            "time_per_token_us": 10000,
            "constraint_checks": 10,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "type_safety".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"Result<.*>".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 1,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Implement authenticate function".to_string(),
        constraints_ir: constraints,
        max_tokens: 100,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: Some("src/auth.rs".to_string()),
            language: Some("rust".to_string()),
            project_root: None,
            metadata: HashMap::new(),
        }),
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(response.code.contains("fn authenticate"));
    assert!(response.code.contains("Result<"));
    assert_eq!(response.metadata.tokens_generated, 25);
    assert!(response.validation.all_satisfied);
    assert_eq!(response.provenance.model, "test-model");
}

#[tokio::test]
async fn test_e2e_typescript_constraints() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "async function authenticate(username: string, password: string): Promise<boolean> {\n    return true;\n}",
        "tokens_generated": 30,
        "model": "test-model",
        "stats": {
            "total_time_ms": 300,
            "time_per_token_us": 10000,
            "constraint_checks": 15,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "async_function".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"async\s+function".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 1,
        },
        ConstraintIR {
            name: "type_annotations".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r":\s*string".to_string(),
                    flags: String::new(),
                },
                RegexPattern {
                    pattern: r":\s*Promise<".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 2,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Implement authenticate function in TypeScript".to_string(),
        constraints_ir: constraints,
        max_tokens: 150,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: Some("src/auth.ts".to_string()),
            language: Some("typescript".to_string()),
            project_root: None,
            metadata: HashMap::new(),
        }),
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(response.code.contains("async function"));
    assert!(response.code.contains("Promise<"));
    assert_eq!(response.validation.satisfied.len(), 2);
}

#[tokio::test]
async fn test_e2e_python_with_json_schema() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "async def authenticate(username: str, password: str) -> bool:\n    return True",
        "tokens_generated": 20,
        "model": "test-model",
        "stats": {
            "total_time_ms": 200,
            "time_per_token_us": 10000,
            "constraint_checks": 8,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let mut properties = HashMap::new();
    properties.insert("username".to_string(), serde_json::json!({"type": "string"}));
    properties.insert("password".to_string(), serde_json::json!({"type": "string"}));
    
    let constraints = vec![
        ConstraintIR {
            name: "function_signature".to_string(),
            json_schema: Some(JsonSchema {
                schema_type: "object".to_string(),
                properties,
                required: vec!["username".to_string(), "password".to_string()],
                additional_properties: false,
            }),
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 1,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Implement authenticate function in Python".to_string(),
        constraints_ir: constraints,
        max_tokens: 100,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: Some("auth.py".to_string()),
            language: Some("python".to_string()),
            project_root: None,
            metadata: HashMap::new(),
        }),
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(response.code.contains("async def authenticate"));
    assert!(response.code.contains("username"));
    assert!(response.code.contains("password"));
}

#[tokio::test]
async fn test_e2e_with_grammar_constraint() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "let result = x + y;",
        "tokens_generated": 8,
        "model": "test-model",
        "stats": {
            "total_time_ms": 80,
            "time_per_token_us": 10000,
            "constraint_checks": 4,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "expression_grammar".to_string(),
            json_schema: None,
            grammar: Some(Grammar {
                rules: vec![
                    GrammarRule {
                        lhs: "S".to_string(),
                        rhs: vec!["E".to_string()],
                    },
                    GrammarRule {
                        lhs: "E".to_string(),
                        rhs: vec!["T".to_string(), "+".to_string(), "E".to_string()],
                    },
                ],
                start_symbol: "S".to_string(),
            }),
            regex_patterns: vec![],
            token_masks: None,
            priority: 1,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Generate an expression".to_string(),
        constraints_ir: constraints,
        max_tokens: 50,
        temperature: 0.5,
        context: None,
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(!response.code.is_empty());
    assert_eq!(response.metadata.tokens_generated, 8);
}

#[tokio::test]
async fn test_e2e_with_token_masks() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "// Safe implementation\nlet x = value?;",
        "tokens_generated": 12,
        "model": "test-model",
        "stats": {
            "total_time_ms": 120,
            "time_per_token_us": 10000,
            "constraint_checks": 6,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "forbidden_unsafe".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: Some(TokenMaskRules {
                allowed_tokens: None,
                forbidden_tokens: Some(vec![1234, 5678]), // Placeholder token IDs
            }),
            priority: 3,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Generate safe code".to_string(),
        constraints_ir: constraints,
        max_tokens: 50,
        temperature: 0.7,
        context: None,
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(!response.code.is_empty());
    assert!(response.validation.all_satisfied);
}

#[tokio::test]
async fn test_e2e_constraint_caching() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "fn test() {}",
        "tokens_generated": 5,
        "model": "test-model",
        "stats": {
            "total_time_ms": 50,
            "time_per_token_us": 10000,
            "constraint_checks": 2,
            "avg_constraint_check_us": 50
        }
    });
    
    // Expect two requests with the same constraints
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .expect(2)
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "test".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 1,
        },
    ];
    
    let request1 = GenerationRequest {
        prompt: "Generate function 1".to_string(),
        constraints_ir: constraints.clone(),
        max_tokens: 50,
        temperature: 0.7,
        context: None,
    };
    
    let request2 = GenerationRequest {
        prompt: "Generate function 2".to_string(),
        constraints_ir: constraints.clone(),
        max_tokens: 50,
        temperature: 0.7,
        context: None,
    };
    
    // First request - should compile constraints
    let response1 = orchestrator.generate(request1).await.unwrap();
    assert_eq!(response1.metadata.tokens_generated, 5);
    
    // Check cache has one entry
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1);
    
    // Second request - should use cached constraints
    let response2 = orchestrator.generate(request2).await.unwrap();
    assert_eq!(response2.metadata.tokens_generated, 5);
    
    // Cache should still have one entry
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 1);
}

#[tokio::test]
async fn test_e2e_multiple_constraints_with_priorities() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "/// Authenticate user\npub async fn authenticate(user: &str) -> Result<bool, Error> {}",
        "tokens_generated": 20,
        "model": "test-model",
        "stats": {
            "total_time_ms": 200,
            "time_per_token_us": 10000,
            "constraint_checks": 10,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "documentation".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"///.*".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 0,  // Low priority
        },
        ConstraintIR {
            name: "type_safety".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"Result<.*>".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 2,  // High priority
        },
        ConstraintIR {
            name: "async_handling".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: r"async\s+fn".to_string(),
                    flags: String::new(),
                },
            ],
            token_masks: None,
            priority: 1,  // Medium priority
        },
    ];
    
    let request = GenerationRequest {
        prompt: "Implement authenticate function with all best practices".to_string(),
        constraints_ir: constraints,
        max_tokens: 100,
        temperature: 0.7,
        context: None,
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    assert!(response.code.contains("///"));
    assert!(response.code.contains("async fn"));
    assert!(response.code.contains("Result<"));
    assert_eq!(response.validation.satisfied.len(), 3);
}

#[tokio::test]
async fn test_e2e_generation_failure_handling() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("POST", "/generate")
        .with_status(500)
        .with_body("Internal Server Error")
        .expect(3)  // Will retry 3 times
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let request = GenerationRequest {
        prompt: "Generate code".to_string(),
        constraints_ir: vec![],
        max_tokens: 50,
        temperature: 0.7,
        context: None,
    };
    
    let result = orchestrator.generate(request).await;
    assert!(result.is_err());
    
    let error = result.unwrap_err();
    assert!(error.to_string().contains("Failed"));
}

#[tokio::test]
async fn test_e2e_provenance_tracking() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "fn test() {}",
        "tokens_generated": 5,
        "model": "llama-3.1-8b",
        "stats": {
            "total_time_ms": 50,
            "time_per_token_us": 10000,
            "constraint_checks": 2,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "llama-3.1-8b".to_string(),
    );
    
    let orchestrator = MazeOrchestrator::new(config).unwrap();
    
    let constraints = vec![
        ConstraintIR {
            name: "constraint1".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 1,
        },
    ];
    
    let request = GenerationRequest {
        prompt: "test prompt".to_string(),
        constraints_ir: constraints,
        max_tokens: 50,
        temperature: 0.8,
        context: None,
    };
    
    let response = orchestrator.generate(request).await.unwrap();
    
    // Verify provenance
    assert_eq!(response.provenance.model, "llama-3.1-8b");
    assert_eq!(response.provenance.original_intent, "test prompt");
    assert_eq!(response.provenance.constraints_applied.len(), 1);
    assert_eq!(response.provenance.constraints_applied[0], "constraint1");
    assert!(response.provenance.timestamp > 0);
    
    // Verify parameters are tracked
    assert!(response.provenance.parameters.contains_key("max_tokens"));
    assert!(response.provenance.parameters.contains_key("temperature"));
}
