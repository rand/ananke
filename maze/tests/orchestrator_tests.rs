//! Integration tests for MazeOrchestrator
//!
//! Tests the core orchestration logic with mocked Modal client

use maze::{
    ffi::{ConstraintIR, RegexPattern},
    GenerationContext, GenerationRequest, MazeOrchestrator, ModalConfig,
};
use std::collections::HashMap;

#[test]
fn test_orchestrator_creation() {
    let config = ModalConfig::new(
        "https://test.modal.run".to_string(),
        "test-model".to_string(),
    );

    let orchestrator = MazeOrchestrator::new(config);
    assert!(orchestrator.is_ok());
}

#[test]
fn test_orchestrator_with_custom_config() {
    let modal_config = ModalConfig::new(
        "https://test.modal.run".to_string(),
        "test-model".to_string(),
    )
    .with_api_key("test-key".to_string())
    .with_timeout(600);

    let maze_config = maze::MazeConfig {
        max_tokens: 4096,
        temperature: 0.8,
        enable_cache: true,
        cache_size_limit: 500,
        timeout_secs: 600,
    };

    let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config);
    assert!(orchestrator.is_ok());
}

#[tokio::test]
async fn test_cache_operations() {
    let config = ModalConfig::new(
        "https://test.modal.run".to_string(),
        "test-model".to_string(),
    );

    let orchestrator = MazeOrchestrator::new(config).unwrap();

    // Initial cache should be empty
    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 0);

    // Clear cache (should succeed even when empty)
    let result = orchestrator.clear_cache().await;
    assert!(result.is_ok());

    let stats = orchestrator.cache_stats().await;
    assert_eq!(stats.size, 0);
}

#[test]
fn test_generation_request_creation() {
    let request = GenerationRequest {
        prompt: "Implement a function".to_string(),
        constraints_ir: vec![],
        max_tokens: 1024,
        temperature: 0.7,
        context: None,
    };

    assert_eq!(request.max_tokens, 1024);
    assert_eq!(request.temperature, 0.7);
    assert!(request.context.is_none());
}

#[test]
fn test_generation_request_with_context() {
    let mut metadata = HashMap::new();
    metadata.insert("test_key".to_string(), serde_json::json!("test_value"));

    let context = GenerationContext {
        current_file: Some("src/main.rs".to_string()),
        language: Some("rust".to_string()),
        project_root: Some("/project".to_string()),
        metadata,
    };

    let request = GenerationRequest {
        prompt: "Implement a function".to_string(),
        constraints_ir: vec![],
        max_tokens: 1024,
        temperature: 0.7,
        context: Some(context.clone()),
    };

    assert!(request.context.is_some());
    let ctx = request.context.unwrap();
    assert_eq!(ctx.current_file, Some("src/main.rs".to_string()));
    assert_eq!(ctx.language, Some("rust".to_string()));
    assert_eq!(ctx.metadata.len(), 1);
}

#[test]
fn test_generation_request_with_constraints() {
    let constraints = vec![
        ConstraintIR {
            name: "type_safety".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![RegexPattern {
                pattern: r"Result<.*>".to_string(),
                flags: String::new(),
            }],
            token_masks: None,
            priority: 1,
        },
        ConstraintIR {
            name: "documentation".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![RegexPattern {
                pattern: r"///.*".to_string(),
                flags: String::new(),
            }],
            token_masks: None,
            priority: 0,
        },
    ];

    let request = GenerationRequest {
        prompt: "Implement a function".to_string(),
        constraints_ir: constraints.clone(),
        max_tokens: 1024,
        temperature: 0.7,
        context: None,
    };

    assert_eq!(request.constraints_ir.len(), 2);
    assert_eq!(request.constraints_ir[0].name, "type_safety");
    assert_eq!(request.constraints_ir[1].name, "documentation");
}

#[test]
fn test_generation_request_serialization() {
    let request = GenerationRequest {
        prompt: "test".to_string(),
        constraints_ir: vec![],
        max_tokens: 100,
        temperature: 0.5,
        context: None,
    };

    let json = serde_json::to_string(&request).unwrap();
    let deserialized: GenerationRequest = serde_json::from_str(&json).unwrap();

    assert_eq!(request.prompt, deserialized.prompt);
    assert_eq!(request.max_tokens, deserialized.max_tokens);
    assert_eq!(request.temperature, deserialized.temperature);
}

#[test]
fn test_generation_context_serialization() {
    let mut metadata = HashMap::new();
    metadata.insert("key".to_string(), serde_json::json!("value"));

    let context = GenerationContext {
        current_file: Some("test.rs".to_string()),
        language: Some("rust".to_string()),
        project_root: Some("/project".to_string()),
        metadata,
    };

    let json = serde_json::to_string(&context).unwrap();
    let deserialized: GenerationContext = serde_json::from_str(&json).unwrap();

    assert_eq!(context.current_file, deserialized.current_file);
    assert_eq!(context.language, deserialized.language);
    assert_eq!(context.project_root, deserialized.project_root);
    assert_eq!(context.metadata.len(), deserialized.metadata.len());
}

#[test]
fn test_maze_config_defaults() {
    let config = maze::MazeConfig::default();

    assert_eq!(config.max_tokens, 2048);
    assert_eq!(config.temperature, 0.7);
    assert!(config.enable_cache);
    assert_eq!(config.cache_size_limit, 1000);
    assert_eq!(config.timeout_secs, 300);
}

#[test]
fn test_maze_config_custom() {
    let config = maze::MazeConfig {
        max_tokens: 4096,
        temperature: 0.9,
        enable_cache: false,
        cache_size_limit: 2000,
        timeout_secs: 600,
    };

    assert_eq!(config.max_tokens, 4096);
    assert_eq!(config.temperature, 0.9);
    assert!(!config.enable_cache);
    assert_eq!(config.cache_size_limit, 2000);
    assert_eq!(config.timeout_secs, 600);
}

#[test]
fn test_cache_stats_structure() {
    let stats = maze::CacheStats {
        size: 10,
        limit: 100,
    };

    assert_eq!(stats.size, 10);
    assert_eq!(stats.limit, 100);
}
