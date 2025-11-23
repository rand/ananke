//! Integration tests for FFI bridge
//!
//! Tests the C-compatible FFI layer between Rust and Zig

use maze::ffi::{
    ConstraintIR, Intent, GenerationResult, RegexPattern, TokenMaskRules,
    JsonSchema, Grammar, GrammarRule,
};
use std::collections::HashMap;

#[test]
fn test_constraint_ir_ffi_roundtrip_simple() {
    let constraint = ConstraintIR {
        name: "test_constraint".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 1,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert_eq!(constraint.priority, restored.priority);
        assert!(restored.json_schema.is_none());
        assert!(restored.grammar.is_none());
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_constraint_ir_ffi_with_regex() {
    let constraint = ConstraintIR {
        name: "regex_constraint".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![
            RegexPattern {
                pattern: r"\d+".to_string(),
                flags: "g".to_string(),
            },
            RegexPattern {
                pattern: r"[a-zA-Z]+".to_string(),
                flags: "i".to_string(),
            },
        ],
        token_masks: None,
        priority: 2,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert_eq!(constraint.regex_patterns.len(), restored.regex_patterns.len());
        assert_eq!(constraint.regex_patterns[0].pattern, restored.regex_patterns[0].pattern);
        assert_eq!(constraint.regex_patterns[1].pattern, restored.regex_patterns[1].pattern);
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_constraint_ir_ffi_with_json_schema() {
    let constraint = ConstraintIR {
        name: "json_schema_constraint".to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: {
                let mut props = HashMap::new();
                props.insert("name".to_string(), serde_json::json!({"type": "string"}));
                props.insert("age".to_string(), serde_json::json!({"type": "number"}));
                props
            },
            required: vec!["name".to_string()],
            additional_properties: false,
        }),
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 1,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert!(restored.json_schema.is_some());
        let schema = restored.json_schema.unwrap();
        assert_eq!(schema.schema_type, "object");
        assert_eq!(schema.properties.len(), 2);
        assert!(schema.properties.contains_key("name"));
        assert!(schema.properties.contains_key("age"));
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_constraint_ir_ffi_with_grammar() {
    let constraint = ConstraintIR {
        name: "grammar_constraint".to_string(),
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
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert!(restored.grammar.is_some());
        let grammar = restored.grammar.unwrap();
        assert_eq!(grammar.start_symbol, "S");
        assert_eq!(grammar.rules.len(), 2);
        assert_eq!(grammar.rules[0].lhs, "S");
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_constraint_ir_ffi_with_token_masks() {
    let constraint = ConstraintIR {
        name: "token_mask_constraint".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some(vec![1, 2, 3, 4, 5]),
            forbidden_tokens: Some(vec![100, 101, 102]),
        }),
        priority: 3,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert!(restored.token_masks.is_some());
        let masks = restored.token_masks.unwrap();
        assert_eq!(masks.allowed_tokens, Some(vec![1, 2, 3, 4, 5]));
        assert_eq!(masks.forbidden_tokens, Some(vec![100, 101, 102]));
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_constraint_ir_ffi_complex() {
    // Test with all fields populated
    let constraint = ConstraintIR {
        name: "complex_constraint".to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: HashMap::new(),
            required: vec![],
            additional_properties: true,
        }),
        grammar: Some(Grammar {
            rules: vec![],
            start_symbol: "S".to_string(),
        }),
        regex_patterns: vec![
            RegexPattern {
                pattern: r".*".to_string(),
                flags: String::new(),
            },
        ],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some(vec![10, 20]),
            forbidden_tokens: None,
        }),
        priority: 5,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).unwrap();
        assert_eq!(constraint.name, restored.name);
        assert!(restored.json_schema.is_some());
        assert!(restored.grammar.is_some());
        assert_eq!(restored.regex_patterns.len(), 1);
        assert!(restored.token_masks.is_some());
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

#[test]
fn test_intent_from_ffi_minimal() {
    use std::ffi::CString;
    use maze::ffi::IntentFFI;
    
    let raw_input = CString::new("implement auth").unwrap();
    let prompt = CString::new("implement auth handler").unwrap();
    
    let intent_ffi = IntentFFI {
        raw_input: raw_input.as_ptr(),
        prompt: prompt.as_ptr(),
        current_file: std::ptr::null(),
        language: std::ptr::null(),
    };
    
    unsafe {
        let intent = Intent::from_ffi(&intent_ffi).unwrap();
        assert_eq!(intent.raw_input, "implement auth");
        assert_eq!(intent.prompt, "implement auth handler");
        assert!(intent.current_file.is_none());
        assert!(intent.language.is_none());
    }
}

#[test]
fn test_intent_from_ffi_complete() {
    use std::ffi::CString;
    use maze::ffi::IntentFFI;
    
    let raw_input = CString::new("implement auth").unwrap();
    let prompt = CString::new("implement auth handler").unwrap();
    let current_file = CString::new("src/auth.rs").unwrap();
    let language = CString::new("rust").unwrap();
    
    let intent_ffi = IntentFFI {
        raw_input: raw_input.as_ptr(),
        prompt: prompt.as_ptr(),
        current_file: current_file.as_ptr(),
        language: language.as_ptr(),
    };
    
    unsafe {
        let intent = Intent::from_ffi(&intent_ffi).unwrap();
        assert_eq!(intent.raw_input, "implement auth");
        assert_eq!(intent.prompt, "implement auth handler");
        assert_eq!(intent.current_file, Some("src/auth.rs".to_string()));
        assert_eq!(intent.language, Some("rust".to_string()));
    }
}

#[test]
fn test_generation_result_to_ffi_success() {
    let result = GenerationResult {
        code: "fn main() {}".to_string(),
        success: true,
        error: None,
        tokens_generated: 10,
        generation_time_ms: 100,
    };

    let ffi = result.to_ffi();
    unsafe {
        assert!((*ffi).success);
        assert_eq!((*ffi).tokens_generated, 10);
        assert_eq!((*ffi).generation_time_ms, 100);
        assert!((*ffi).error.is_null());
        
        let code_str = std::ffi::CStr::from_ptr((*ffi).code);
        assert_eq!(code_str.to_str().unwrap(), "fn main() {}");
        
        maze::ffi::free_generation_result_ffi(ffi);
    }
}

#[test]
fn test_generation_result_to_ffi_failure() {
    let result = GenerationResult {
        code: String::new(),
        success: false,
        error: Some("Generation failed: timeout".to_string()),
        tokens_generated: 0,
        generation_time_ms: 5000,
    };

    let ffi = result.to_ffi();
    unsafe {
        assert!(!(*ffi).success);
        assert_eq!((*ffi).tokens_generated, 0);
        assert!(!(*ffi).error.is_null());
        
        let error_str = std::ffi::CStr::from_ptr((*ffi).error);
        assert_eq!(error_str.to_str().unwrap(), "Generation failed: timeout");
        
        maze::ffi::free_generation_result_ffi(ffi);
    }
}

#[test]
fn test_multiple_constraints_array() {
    let constraints = vec![
        ConstraintIR {
            name: "constraint1".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 1,
        },
        ConstraintIR {
            name: "constraint2".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 2,
        },
        ConstraintIR {
            name: "constraint3".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: None,
            priority: 3,
        },
    ];

    // Convert all to FFI
    let ffi_ptrs: Vec<_> = constraints.iter().map(|c| c.to_ffi()).collect();
    
    unsafe {
        // Verify all conversions
        for (i, &ffi_ptr) in ffi_ptrs.iter().enumerate() {
            let restored = ConstraintIR::from_ffi(ffi_ptr).unwrap();
            assert_eq!(restored.name, constraints[i].name);
            assert_eq!(restored.priority, constraints[i].priority);
        }
        
        // Cleanup
        for &ffi_ptr in &ffi_ptrs {
            maze::ffi::free_constraint_ir_ffi(ffi_ptr);
        }
    }
}

#[test]
fn test_constraint_ir_serialization() {
    let constraint = ConstraintIR {
        name: "test".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![
            RegexPattern {
                pattern: "test".to_string(),
                flags: "g".to_string(),
            },
        ],
        token_masks: None,
        priority: 1,
    };
    
    // Test JSON serialization
    let json = serde_json::to_string(&constraint).unwrap();
    let deserialized: ConstraintIR = serde_json::from_str(&json).unwrap();
    
    assert_eq!(constraint.name, deserialized.name);
    assert_eq!(constraint.priority, deserialized.priority);
    assert_eq!(constraint.regex_patterns.len(), deserialized.regex_patterns.len());
}

#[test]
fn test_intent_serialization() {
    let intent = Intent {
        raw_input: "test input".to_string(),
        prompt: "test prompt".to_string(),
        current_file: Some("test.rs".to_string()),
        language: Some("rust".to_string()),
    };
    
    let json = serde_json::to_string(&intent).unwrap();
    let deserialized: Intent = serde_json::from_str(&json).unwrap();
    
    assert_eq!(intent.raw_input, deserialized.raw_input);
    assert_eq!(intent.prompt, deserialized.prompt);
    assert_eq!(intent.current_file, deserialized.current_file);
    assert_eq!(intent.language, deserialized.language);
}
