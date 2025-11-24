//! Test helper utilities for integration tests
//!
//! Provides common test utilities, fixtures, and assertion helpers

use maze::{
    ffi::{ConstraintIR, Grammar, GrammarRule, JsonSchema, RegexPattern, TokenMaskRules},
    GenerationContext, GenerationRequest, MazeOrchestrator, ModalConfig,
};
use std::collections::HashMap;

/// Create a test orchestrator with mock Modal config
pub fn create_test_orchestrator(endpoint_url: String) -> MazeOrchestrator {
    let config = ModalConfig::new(endpoint_url, "test-model".to_string());
    MazeOrchestrator::new(config).expect("Failed to create orchestrator")
}

/// Create a simple test constraint
pub fn simple_constraint(name: &str, priority: u32) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority,
    }
}

/// Create a regex constraint
pub fn regex_constraint(name: &str, pattern: &str, priority: u32) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![RegexPattern {
            pattern: pattern.to_string(),
            flags: String::new(),
        }],
        token_masks: None,
        priority,
    }
}

/// Create a JSON schema constraint
pub fn json_schema_constraint(
    name: &str,
    properties: HashMap<String, serde_json::Value>,
    required: Vec<String>,
    priority: u32,
) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties,
            required,
            additional_properties: false,
        }),
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority,
    }
}

/// Create a grammar constraint
pub fn grammar_constraint(
    name: &str,
    rules: Vec<GrammarRule>,
    start_symbol: &str,
    priority: u32,
) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: None,
        grammar: Some(Grammar {
            rules,
            start_symbol: start_symbol.to_string(),
        }),
        regex_patterns: vec![],
        token_masks: None,
        priority,
    }
}

/// Create a token mask constraint
pub fn token_mask_constraint(
    name: &str,
    allowed: Option<Vec<u32>>,
    forbidden: Option<Vec<u32>>,
    priority: u32,
) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: allowed,
            forbidden_tokens: forbidden,
        }),
        priority,
    }
}

/// Create a test generation request
pub fn test_request(
    prompt: &str,
    constraints: Vec<ConstraintIR>,
    max_tokens: usize,
) -> GenerationRequest {
    GenerationRequest {
        prompt: prompt.to_string(),
        constraints_ir: constraints,
        max_tokens,
        temperature: 0.7,
        context: None,
    }
}

/// Create a test generation request with context
pub fn test_request_with_context(
    prompt: &str,
    constraints: Vec<ConstraintIR>,
    max_tokens: usize,
    current_file: &str,
    language: &str,
) -> GenerationRequest {
    GenerationRequest {
        prompt: prompt.to_string(),
        constraints_ir: constraints,
        max_tokens,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: Some(current_file.to_string()),
            language: Some(language.to_string()),
            project_root: None,
            metadata: HashMap::new(),
        }),
    }
}

/// Assert that generated code contains expected patterns
pub fn assert_code_contains(code: &str, patterns: &[&str]) {
    for pattern in patterns {
        assert!(
            code.contains(pattern),
            "Generated code does not contain expected pattern: {}\nCode: {}",
            pattern,
            code
        );
    }
}

/// Assert that provenance is valid
pub fn assert_valid_provenance(
    provenance: &maze::Provenance,
    expected_model: &str,
    expected_intent: &str,
    expected_constraints: usize,
) {
    assert_eq!(provenance.model, expected_model);
    assert_eq!(provenance.original_intent, expected_intent);
    assert_eq!(provenance.constraints_applied.len(), expected_constraints);
    assert!(provenance.timestamp > 0);
    assert!(provenance.parameters.contains_key("max_tokens"));
    assert!(provenance.parameters.contains_key("temperature"));
}

/// Assert that validation is successful
pub fn assert_validation_success(validation: &maze::ValidationResult, expected_constraints: usize) {
    assert!(validation.all_satisfied, "Not all constraints satisfied");
    assert_eq!(validation.satisfied.len(), expected_constraints);
    assert!(
        validation.violated.is_empty(),
        "Some constraints violated: {:?}",
        validation.violated
    );
}

/// Assert that metadata is reasonable
pub fn assert_valid_metadata(metadata: &maze::GenerationMetadata) {
    assert!(metadata.tokens_generated > 0, "No tokens generated");
    // Note: generation_time_ms can be 0 in tests due to timing

    if metadata.tokens_generated > 0 && metadata.generation_time_ms > 0 {
        let expected_avg = (metadata.generation_time_ms * 1000) / metadata.tokens_generated as u64;
        assert_eq!(
            metadata.avg_token_time_us, expected_avg,
            "Average token time calculation mismatch"
        );
    }
}

/// Create Rust-specific constraints
pub fn rust_constraints() -> Vec<ConstraintIR> {
    vec![
        regex_constraint("type_safety", r"Result<.*>", 2),
        regex_constraint("error_handling", r"Error|anyhow|thiserror", 1),
        regex_constraint("async_handling", r"async\s+fn", 1),
    ]
}

/// Create TypeScript-specific constraints
pub fn typescript_constraints() -> Vec<ConstraintIR> {
    vec![
        regex_constraint("async_function", r"async\s+function", 2),
        regex_constraint("type_annotations", r":\s*\w+", 2),
        regex_constraint("promise_return", r":\s*Promise<", 1),
    ]
}

/// Create Python-specific constraints
pub fn python_constraints() -> Vec<ConstraintIR> {
    vec![
        regex_constraint("type_hints", r"->\s*\w+", 2),
        regex_constraint("async_def", r"async\s+def", 1),
        regex_constraint("docstrings", r#"\"\"\".*\"\"\""#, 1),
    ]
}

/// Create security constraints
pub fn security_constraints() -> Vec<ConstraintIR> {
    vec![
        token_mask_constraint(
            "no_unsafe_code",
            None,
            Some(vec![1234, 5678, 9012]), // Mock token IDs for unsafe keywords
            3,
        ),
        regex_constraint("input_validation", r"validate|sanitize|check", 2),
        regex_constraint("auth_required", r"authenticate|authorize", 2),
    ]
}
