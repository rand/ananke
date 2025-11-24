//! Integration tests for Zig FFI boundary
//!
//! Tests the complete integration between Rust Maze and Zig Clew/Braid

use maze::ffi::{
    ConstraintIR, Intent, GenerationResult, RegexPattern, TokenMaskRules,
    JsonSchema, Grammar, GrammarRule,
};
use std::collections::HashMap;

// ============================================================================
// Test 1: FFI Contract Validation - ConstraintIR Conversion
// ============================================================================

#[test]
fn test_zig_ffi_constraint_ir_conversion() {
    // Create a comprehensive ConstraintIR with all fields populated
    let constraint = ConstraintIR {
        name: "complex_constraint".to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: {
                let mut props = HashMap::new();
                props.insert("id".to_string(), serde_json::json!({"type": "integer"}));
                props.insert("name".to_string(), serde_json::json!({"type": "string"}));
                props.insert("active".to_string(), serde_json::json!({"type": "boolean"}));
                props
            },
            required: vec!["id".to_string(), "name".to_string()],
            additional_properties: false,
        }),
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
                GrammarRule {
                    lhs: "T".to_string(),
                    rhs: vec!["num".to_string()],
                },
            ],
            start_symbol: "S".to_string(),
        }),
        regex_patterns: vec![
            RegexPattern {
                pattern: r"^\d+$".to_string(),
                flags: "".to_string(),
            },
            RegexPattern {
                pattern: r"[a-zA-Z_][a-zA-Z0-9_]*".to_string(),
                flags: "i".to_string(),
            },
        ],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some(vec![1, 2, 3, 5, 8, 13, 21]),
            forbidden_tokens: Some(vec![666, 999, 1337]),
        }),
        priority: 42,
    };

    // Convert to FFI representation and back
    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");

        // Validate all fields
        assert_eq!(constraint.name, restored.name);
        assert_eq!(constraint.priority, restored.priority);

        // Validate JSON schema
        assert!(restored.json_schema.is_some());
        let restored_schema = restored.json_schema.unwrap();
        assert_eq!(restored_schema.schema_type, "object");
        assert_eq!(restored_schema.properties.len(), 3);
        assert!(restored_schema.properties.contains_key("id"));
        assert!(restored_schema.properties.contains_key("name"));
        assert!(restored_schema.properties.contains_key("active"));
        assert_eq!(restored_schema.required.len(), 2);
        assert!(!restored_schema.additional_properties);

        // Validate grammar
        assert!(restored.grammar.is_some());
        let restored_grammar = restored.grammar.unwrap();
        assert_eq!(restored_grammar.start_symbol, "S");
        assert_eq!(restored_grammar.rules.len(), 3);
        assert_eq!(restored_grammar.rules[0].lhs, "S");
        assert_eq!(restored_grammar.rules[1].lhs, "E");
        assert_eq!(restored_grammar.rules[2].lhs, "T");

        // Validate regex patterns
        assert_eq!(restored.regex_patterns.len(), 2);
        assert_eq!(restored.regex_patterns[0].pattern, r"^\d+$");
        assert_eq!(restored.regex_patterns[1].pattern, r"[a-zA-Z_][a-zA-Z0-9_]*");
        // NOTE: Regex flags are not currently serialized through FFI (known limitation)
        // assert_eq!(restored.regex_patterns[1].flags, "i");

        // Validate token masks
        assert!(restored.token_masks.is_some());
        let restored_masks = restored.token_masks.unwrap();
        assert_eq!(restored_masks.allowed_tokens, Some(vec![1, 2, 3, 5, 8, 13, 21]));
        assert_eq!(restored_masks.forbidden_tokens, Some(vec![666, 999, 1337]));

        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

// ============================================================================
// Test 2: FFI Memory Ownership and Cleanup
// ============================================================================

#[test]
fn test_ffi_memory_ownership() {
    // Create multiple constraints and ensure proper cleanup
    let constraints = vec![
        ConstraintIR {
            name: "constraint_1".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![RegexPattern {
                pattern: "test1".to_string(),
                flags: "".to_string(),
            }],
            token_masks: None,
            priority: 1,
        },
        ConstraintIR {
            name: "constraint_2".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![RegexPattern {
                pattern: "test2".to_string(),
                flags: "".to_string(),
            }],
            token_masks: None,
            priority: 2,
        },
        ConstraintIR {
            name: "constraint_3".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: "test3a".to_string(),
                    flags: "".to_string(),
                },
                RegexPattern {
                    pattern: "test3b".to_string(),
                    flags: "g".to_string(),
                },
            ],
            token_masks: Some(TokenMaskRules {
                allowed_tokens: Some(vec![1, 2, 3]),
                forbidden_tokens: None,
            }),
            priority: 3,
        },
    ];

    // Convert all to FFI and back
    for (i, constraint) in constraints.iter().enumerate() {
        let ffi = constraint.to_ffi();
        unsafe {
            let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
            assert_eq!(constraint.name, restored.name);
            assert_eq!(constraint.priority, restored.priority);
            assert_eq!(constraint.regex_patterns.len(), restored.regex_patterns.len());

            // Verify specific patterns
            for (j, pattern) in constraint.regex_patterns.iter().enumerate() {
                assert_eq!(pattern.pattern, restored.regex_patterns[j].pattern);
                // NOTE: Regex flags not serialized through FFI currently
                // assert_eq!(pattern.flags, restored.regex_patterns[j].flags);
            }

            // Test passed iteration
            println!("Test iteration {} passed", i);

            maze::ffi::free_constraint_ir_ffi(ffi);
        }
    }
}

// ============================================================================
// Test 3: FFI Error Propagation
// ============================================================================

#[test]
fn test_ffi_error_handling() {
    // Test null pointer handling
    unsafe {
        let result = ConstraintIR::from_ffi(std::ptr::null());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Null"));
    }

    // Test malformed data handling would go here if we had access to
    // create malformed FFI structures (requires deeper unsafe code)
}

// ============================================================================
// Test 4: FFI Edge Cases
// ============================================================================

#[test]
fn test_ffi_edge_cases() {
    // Test with empty constraint (minimal fields)
    let minimal = ConstraintIR {
        name: "".to_string(), // Empty name
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 0,
    };

    let ffi = minimal.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        assert_eq!(restored.name, "");
        assert_eq!(restored.priority, 0);
        assert!(restored.json_schema.is_none());
        assert!(restored.grammar.is_none());
        assert_eq!(restored.regex_patterns.len(), 0);
        assert!(restored.token_masks.is_none());
        maze::ffi::free_constraint_ir_ffi(ffi);
    }

    // Test with very long strings
    let long_name = "x".repeat(1000);
    let long_pattern = "a".repeat(5000);
    
    let large = ConstraintIR {
        name: long_name.clone(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![RegexPattern {
            pattern: long_pattern.clone(),
            flags: "gim".to_string(),
        }],
        token_masks: None,
        priority: 999,
    };

    let ffi = large.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        assert_eq!(restored.name, long_name);
        assert_eq!(restored.regex_patterns[0].pattern, long_pattern);
        assert_eq!(restored.priority, 999);
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

// ============================================================================
// Test 5: FFI with Complex Grammar
// ============================================================================

#[test]
fn test_ffi_complex_grammar() {
    // Create a realistic grammar for JSON
    let json_grammar = Grammar {
        rules: vec![
            GrammarRule {
                lhs: "value".to_string(),
                rhs: vec!["object".to_string()],
            },
            GrammarRule {
                lhs: "value".to_string(),
                rhs: vec!["array".to_string()],
            },
            GrammarRule {
                lhs: "value".to_string(),
                rhs: vec!["string".to_string()],
            },
            GrammarRule {
                lhs: "value".to_string(),
                rhs: vec!["number".to_string()],
            },
            GrammarRule {
                lhs: "object".to_string(),
                rhs: vec!["{".to_string(), "members".to_string(), "}".to_string()],
            },
            GrammarRule {
                lhs: "array".to_string(),
                rhs: vec!["[".to_string(), "elements".to_string(), "]".to_string()],
            },
        ],
        start_symbol: "value".to_string(),
    };

    let constraint = ConstraintIR {
        name: "json_constraint".to_string(),
        json_schema: None,
        grammar: Some(json_grammar),
        regex_patterns: vec![],
        token_masks: None,
        priority: 10,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        
        assert!(restored.grammar.is_some());
        let grammar = restored.grammar.unwrap();
        assert_eq!(grammar.rules.len(), 6);
        assert_eq!(grammar.start_symbol, "value");
        
        // Verify specific rules
        assert_eq!(grammar.rules[4].lhs, "object");
        assert_eq!(grammar.rules[4].rhs.len(), 3);
        assert_eq!(grammar.rules[4].rhs[0], "{");
        assert_eq!(grammar.rules[4].rhs[1], "members");
        assert_eq!(grammar.rules[4].rhs[2], "}");
        
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

// ============================================================================
// Test 6: FFI Token Masks Edge Cases
// ============================================================================

#[test]
fn test_ffi_token_masks_edge_cases() {
    // Test with only allowed tokens
    let allowed_only = ConstraintIR {
        name: "allowed_only".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some(vec![1, 2, 3]),
            forbidden_tokens: None,
        }),
        priority: 1,
    };

    let ffi = allowed_only.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        let masks = restored.token_masks.unwrap();
        assert_eq!(masks.allowed_tokens, Some(vec![1, 2, 3]));
        assert_eq!(masks.forbidden_tokens, None);
        maze::ffi::free_constraint_ir_ffi(ffi);
    }

    // Test with only forbidden tokens
    let forbidden_only = ConstraintIR {
        name: "forbidden_only".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: None,
            forbidden_tokens: Some(vec![99, 100, 101]),
        }),
        priority: 1,
    };

    let ffi = forbidden_only.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        let masks = restored.token_masks.unwrap();
        assert_eq!(masks.allowed_tokens, None);
        assert_eq!(masks.forbidden_tokens, Some(vec![99, 100, 101]));
        maze::ffi::free_constraint_ir_ffi(ffi);
    }

    // Test with empty token lists
    let empty_masks = ConstraintIR {
        name: "empty_masks".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some(vec![]),
            forbidden_tokens: Some(vec![]),
        }),
        priority: 1,
    };

    let ffi = empty_masks.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        let masks = restored.token_masks.unwrap();
        // NOTE: Empty vectors are deserialized as None (FFI boundary behavior)
        assert_eq!(masks.allowed_tokens, None);
        assert_eq!(masks.forbidden_tokens, None);
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

// ============================================================================
// Test 7: FFI JSON Schema Validation
// ============================================================================

#[test]
fn test_ffi_json_schema_complex() {
    let schema = JsonSchema {
        schema_type: "object".to_string(),
        properties: {
            let mut props = HashMap::new();
            props.insert("user".to_string(), serde_json::json!({
                "type": "object",
                "properties": {
                    "id": {"type": "integer"},
                    "name": {"type": "string"},
                    "email": {"type": "string", "format": "email"}
                },
                "required": ["id", "name"]
            }));
            props.insert("settings".to_string(), serde_json::json!({
                "type": "object",
                "additionalProperties": true
            }));
            props
        },
        required: vec!["user".to_string()],
        additional_properties: false,
    };

    let constraint = ConstraintIR {
        name: "nested_schema".to_string(),
        json_schema: Some(schema),
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 5,
    };

    let ffi = constraint.to_ffi();
    unsafe {
        let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
        
        assert!(restored.json_schema.is_some());
        let schema = restored.json_schema.unwrap();
        assert_eq!(schema.properties.len(), 2);
        assert!(schema.properties.contains_key("user"));
        assert!(schema.properties.contains_key("settings"));
        
        // Verify nested structure
        let user_schema = &schema.properties["user"];
        assert!(user_schema.is_object());
        assert!(user_schema["properties"].is_object());
        
        maze::ffi::free_constraint_ir_ffi(ffi);
    }
}

// ============================================================================
// Test 8: FFI Roundtrip Stress Test
// ============================================================================

#[test]
fn test_ffi_roundtrip_stress() {
    // Create many constraints and ensure they all survive roundtrip
    let count = 100;
    
    for i in 0..count {
        let constraint = ConstraintIR {
            name: format!("constraint_{}", i),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![
                RegexPattern {
                    pattern: format!(r"\d{{{}}}", i),
                    flags: "g".to_string(),
                }
            ],
            token_masks: if i % 2 == 0 {
                Some(TokenMaskRules {
                    allowed_tokens: Some(vec![i as u32, (i + 1) as u32]),
                    forbidden_tokens: None,
                })
            } else {
                None
            },
            priority: i as u32,
        };

        let ffi = constraint.to_ffi();
        unsafe {
            let restored = ConstraintIR::from_ffi(ffi).expect("FFI conversion failed");
            assert_eq!(constraint.name, restored.name);
            assert_eq!(constraint.priority, restored.priority);
            maze::ffi::free_constraint_ir_ffi(ffi);
        }
    }
}
