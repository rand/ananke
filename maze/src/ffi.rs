//! FFI bindings for Zig integration
//!
//! Provides C-compatible FFI layer for communication between
//! Rust Maze orchestration and Zig constraint engines (Clew/Braid)

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::slice;

/// C-compatible ConstraintIR matching Zig definition
///
/// This struct must match the memory layout of the Zig ConstraintIR type
#[repr(C)]
#[derive(Debug, Clone)]
pub struct ConstraintIRFFI {
    /// JSON schema pointer (nullable)
    pub json_schema: *const c_char,

    /// Grammar rules pointer (nullable)
    pub grammar: *const c_char,

    /// Regex patterns array
    pub regex_patterns: *const *const c_char,
    pub regex_patterns_len: usize,

    /// Token masks
    pub token_masks: *const TokenMaskRulesFFI,

    /// Priority for conflict resolution
    pub priority: u32,

    /// Constraint name
    pub name: *const c_char,
}

/// C-compatible TokenMaskRules
#[repr(C)]
#[derive(Debug, Clone)]
pub struct TokenMaskRulesFFI {
    /// Allowed tokens array
    pub allowed_tokens: *const u32,
    pub allowed_tokens_len: usize,

    /// Forbidden tokens array
    pub forbidden_tokens: *const u32,
    pub forbidden_tokens_len: usize,
}

/// Rust-native ConstraintIR for internal use
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintIR {
    /// Constraint name
    pub name: String,

    /// JSON schema for structured constraints
    #[serde(skip_serializing_if = "Option::is_none")]
    pub json_schema: Option<JsonSchema>,

    /// Context-free grammar for syntax constraints
    #[serde(skip_serializing_if = "Option::is_none")]
    pub grammar: Option<Grammar>,

    /// Regular expression patterns
    #[serde(default)]
    pub regex_patterns: Vec<RegexPattern>,

    /// Token masking rules
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token_masks: Option<TokenMaskRules>,

    /// Priority for conflict resolution
    #[serde(default)]
    pub priority: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonSchema {
    pub schema_type: String,
    #[serde(default)]
    pub properties: HashMap<String, serde_json::Value>,
    #[serde(default)]
    pub required: Vec<String>,
    #[serde(default)]
    pub additional_properties: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Grammar {
    pub rules: Vec<GrammarRule>,
    pub start_symbol: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GrammarRule {
    pub lhs: String,
    pub rhs: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexPattern {
    pub pattern: String,
    #[serde(default)]
    pub flags: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenMaskRules {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allowed_tokens: Option<Vec<u32>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub forbidden_tokens: Option<Vec<u32>>,
}

/// C-compatible Intent structure
#[repr(C)]
#[derive(Debug, Clone)]
pub struct IntentFFI {
    /// Raw user input
    pub raw_input: *const c_char,

    /// Parsed prompt
    pub prompt: *const c_char,

    /// Context file path (nullable)
    pub current_file: *const c_char,

    /// Programming language (nullable)
    pub language: *const c_char,
}

/// Rust-native Intent
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Intent {
    pub raw_input: String,
    pub prompt: String,
    pub current_file: Option<String>,
    pub language: Option<String>,
}

/// C-compatible GenerationResult
#[repr(C)]
#[derive(Debug)]
pub struct GenerationResultFFI {
    /// Generated code
    pub code: *const c_char,

    /// Success flag
    pub success: bool,

    /// Error message (nullable, only if success=false)
    pub error: *const c_char,

    /// Number of tokens generated
    pub tokens_generated: usize,

    /// Generation time in milliseconds
    pub generation_time_ms: u64,
}

/// Rust-native GenerationResult
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationResult {
    pub code: String,
    pub success: bool,
    pub error: Option<String>,
    pub tokens_generated: usize,
    pub generation_time_ms: u64,
}

// ============================================================================
// FFI Conversion Functions
// ============================================================================

impl ConstraintIR {
    /// Convert from C FFI representation to Rust
    ///
    /// # Safety
    /// The FFI pointer must be valid and point to properly initialized memory
    pub unsafe fn from_ffi(ffi: *const ConstraintIRFFI) -> Result<Self, String> {
        if ffi.is_null() {
            return Err("Null ConstraintIR pointer".to_string());
        }

        let ffi_ref = &*ffi;

        // Convert name
        let name = if !ffi_ref.name.is_null() {
            CStr::from_ptr(ffi_ref.name)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in name: {}", e))?
                .to_string()
        } else {
            "unnamed".to_string()
        };

        // Convert JSON schema
        let json_schema = if !ffi_ref.json_schema.is_null() {
            let schema_str = CStr::from_ptr(ffi_ref.json_schema)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in JSON schema: {}", e))?;
            Some(
                serde_json::from_str(schema_str)
                    .map_err(|e| format!("Invalid JSON schema: {}", e))?,
            )
        } else {
            None
        };

        // Convert grammar
        let grammar = if !ffi_ref.grammar.is_null() {
            let grammar_str = CStr::from_ptr(ffi_ref.grammar)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in grammar: {}", e))?;
            Some(serde_json::from_str(grammar_str).map_err(|e| format!("Invalid grammar: {}", e))?)
        } else {
            None
        };

        // Convert regex patterns
        let regex_patterns = if !ffi_ref.regex_patterns.is_null() && ffi_ref.regex_patterns_len > 0
        {
            let patterns_slice =
                slice::from_raw_parts(ffi_ref.regex_patterns, ffi_ref.regex_patterns_len);

            patterns_slice
                .iter()
                .map(|&pattern_ptr| {
                    if pattern_ptr.is_null() {
                        return Err("Null pattern pointer".to_string());
                    }
                    let pattern_str = CStr::from_ptr(pattern_ptr)
                        .to_str()
                        .map_err(|e| format!("Invalid UTF-8 in regex pattern: {}", e))?;
                    Ok(RegexPattern {
                        pattern: pattern_str.to_string(),
                        flags: String::new(),
                    })
                })
                .collect::<Result<Vec<_>, String>>()?
        } else {
            vec![]
        };

        // Convert token masks
        let token_masks = if !ffi_ref.token_masks.is_null() {
            let masks_ref = &*ffi_ref.token_masks;

            let allowed_tokens = if !masks_ref.allowed_tokens.is_null()
                && masks_ref.allowed_tokens_len > 0
            {
                Some(
                    slice::from_raw_parts(masks_ref.allowed_tokens, masks_ref.allowed_tokens_len)
                        .to_vec(),
                )
            } else {
                None
            };

            let forbidden_tokens =
                if !masks_ref.forbidden_tokens.is_null() && masks_ref.forbidden_tokens_len > 0 {
                    Some(
                        slice::from_raw_parts(
                            masks_ref.forbidden_tokens,
                            masks_ref.forbidden_tokens_len,
                        )
                        .to_vec(),
                    )
                } else {
                    None
                };

            Some(TokenMaskRules {
                allowed_tokens,
                forbidden_tokens,
            })
        } else {
            None
        };

        Ok(ConstraintIR {
            name,
            json_schema,
            grammar,
            regex_patterns,
            token_masks,
            priority: ffi_ref.priority,
        })
    }

    /// Convert to C FFI representation
    ///
    /// The caller is responsible for freeing the returned pointer
    /// using `free_constraint_ir_ffi`
    pub fn to_ffi(&self) -> *mut ConstraintIRFFI {
        let name = CString::new(self.name.clone()).unwrap();

        let json_schema = self.json_schema.as_ref().map(|schema| {
            let json = serde_json::to_string(schema).unwrap();
            CString::new(json).unwrap()
        });

        let grammar = self.grammar.as_ref().map(|g| {
            let json = serde_json::to_string(g).unwrap();
            CString::new(json).unwrap()
        });

        // Allocate regex patterns
        let (regex_patterns, regex_patterns_len) = if !self.regex_patterns.is_empty() {
            let patterns: Vec<*const c_char> = self
                .regex_patterns
                .iter()
                .map(|p| CString::new(p.pattern.clone()).unwrap().into_raw() as *const c_char)
                .collect();
            let len = patterns.len();
            let ptr = Box::into_raw(patterns.into_boxed_slice()) as *const *const c_char;
            (ptr, len)
        } else {
            (ptr::null(), 0)
        };

        // Allocate token masks
        let token_masks = self
            .token_masks
            .as_ref()
            .map(|masks| {
                Box::into_raw(Box::new(TokenMaskRulesFFI {
                    allowed_tokens: masks
                        .allowed_tokens
                        .as_ref()
                        .map(|v| Box::into_raw(v.clone().into_boxed_slice()) as *const u32)
                        .unwrap_or(ptr::null()),
                    allowed_tokens_len: masks.allowed_tokens.as_ref().map(|v| v.len()).unwrap_or(0),
                    forbidden_tokens: masks
                        .forbidden_tokens
                        .as_ref()
                        .map(|v| Box::into_raw(v.clone().into_boxed_slice()) as *const u32)
                        .unwrap_or(ptr::null()),
                    forbidden_tokens_len: masks
                        .forbidden_tokens
                        .as_ref()
                        .map(|v| v.len())
                        .unwrap_or(0),
                }))
            })
            .unwrap_or(ptr::null_mut());

        Box::into_raw(Box::new(ConstraintIRFFI {
            name: name.into_raw(),
            json_schema: json_schema.map(|s| s.into_raw()).unwrap_or(ptr::null_mut()),
            grammar: grammar.map(|g| g.into_raw()).unwrap_or(ptr::null_mut()),
            regex_patterns,
            regex_patterns_len,
            token_masks,
            priority: self.priority,
        }))
    }
}

impl Intent {
    /// Convert from C FFI representation to Rust
    ///
    /// # Safety
    /// The FFI pointer must be valid and point to properly initialized memory
    pub unsafe fn from_ffi(ffi: *const IntentFFI) -> Result<Self, String> {
        if ffi.is_null() {
            return Err("Null Intent pointer".to_string());
        }

        let ffi_ref = &*ffi;

        let raw_input = if !ffi_ref.raw_input.is_null() {
            CStr::from_ptr(ffi_ref.raw_input)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in raw_input: {}", e))?
                .to_string()
        } else {
            return Err("Null raw_input".to_string());
        };

        let prompt = if !ffi_ref.prompt.is_null() {
            CStr::from_ptr(ffi_ref.prompt)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in prompt: {}", e))?
                .to_string()
        } else {
            raw_input.clone()
        };

        let current_file = if !ffi_ref.current_file.is_null() {
            Some(
                CStr::from_ptr(ffi_ref.current_file)
                    .to_str()
                    .map_err(|e| format!("Invalid UTF-8 in current_file: {}", e))?
                    .to_string(),
            )
        } else {
            None
        };

        let language = if !ffi_ref.language.is_null() {
            Some(
                CStr::from_ptr(ffi_ref.language)
                    .to_str()
                    .map_err(|e| format!("Invalid UTF-8 in language: {}", e))?
                    .to_string(),
            )
        } else {
            None
        };

        Ok(Intent {
            raw_input,
            prompt,
            current_file,
            language,
        })
    }
}

impl GenerationResult {
    /// Convert to C FFI representation
    pub fn to_ffi(&self) -> *mut GenerationResultFFI {
        let code = CString::new(self.code.clone()).unwrap();
        let error = self
            .error
            .as_ref()
            .map(|e| CString::new(e.clone()).unwrap());

        Box::into_raw(Box::new(GenerationResultFFI {
            code: code.into_raw(),
            success: self.success,
            error: error.map(|e| e.into_raw()).unwrap_or(ptr::null_mut()),
            tokens_generated: self.tokens_generated,
            generation_time_ms: self.generation_time_ms,
        }))
    }
}

// ============================================================================
// FFI Memory Management Functions (C-callable)
// ============================================================================

/// Free a ConstraintIR FFI structure
///
/// # Safety
/// Must be called exactly once on a pointer returned from `to_ffi`
#[no_mangle]
pub unsafe extern "C" fn free_constraint_ir_ffi(ptr: *mut ConstraintIRFFI) {
    if ptr.is_null() {
        return;
    }

    let ffi = Box::from_raw(ptr);

    // Free name
    if !ffi.name.is_null() {
        let _ = CString::from_raw(ffi.name as *mut c_char);
    }

    // Free JSON schema
    if !ffi.json_schema.is_null() {
        let _ = CString::from_raw(ffi.json_schema as *mut c_char);
    }

    // Free grammar
    if !ffi.grammar.is_null() {
        let _ = CString::from_raw(ffi.grammar as *mut c_char);
    }

    // Free regex patterns
    if !ffi.regex_patterns.is_null() {
        let patterns = slice::from_raw_parts(ffi.regex_patterns, ffi.regex_patterns_len);
        for &pattern in patterns {
            if !pattern.is_null() {
                let _ = CString::from_raw(pattern as *mut c_char);
            }
        }
        let _ = Box::from_raw(ffi.regex_patterns as *mut *const c_char);
    }

    // Free token masks
    if !ffi.token_masks.is_null() {
        let masks = Box::from_raw(ffi.token_masks as *mut TokenMaskRulesFFI);
        if !masks.allowed_tokens.is_null() {
            let _ = Box::from_raw(core::ptr::slice_from_raw_parts_mut(
                masks.allowed_tokens as *mut u32,
                masks.allowed_tokens_len,
            ));
        }
        if !masks.forbidden_tokens.is_null() {
            let _ = Box::from_raw(core::ptr::slice_from_raw_parts_mut(
                masks.forbidden_tokens as *mut u32,
                masks.forbidden_tokens_len,
            ));
        }
    }
}

/// Free a GenerationResult FFI structure
///
/// # Safety
/// Must be called exactly once on a pointer returned from `to_ffi`
#[no_mangle]
pub unsafe extern "C" fn free_generation_result_ffi(ptr: *mut GenerationResultFFI) {
    if ptr.is_null() {
        return;
    }

    let result = Box::from_raw(ptr);

    // Free code
    if !result.code.is_null() {
        let _ = CString::from_raw(result.code as *mut c_char);
    }

    // Free error
    if !result.error.is_null() {
        let _ = CString::from_raw(result.error as *mut c_char);
    }
}

// ============================================================================
// HoleSpec FFI Types
// ============================================================================

/// Specification for a typed hole to be filled
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoleSpec {
    /// Unique identifier for the hole
    pub hole_id: u64,

    /// Optional JSON schema constraint for the fill
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fill_schema: Option<JsonSchema>,

    /// Optional grammar constraint for the fill
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fill_grammar: Option<Grammar>,

    /// List of constraints that must be satisfied
    #[serde(default)]
    pub fill_constraints: Vec<FillConstraint>,

    /// Reference to a named grammar definition
    #[serde(skip_serializing_if = "Option::is_none")]
    pub grammar_ref: Option<String>,
}

/// A constraint on hole filling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FillConstraint {
    /// Type/kind of constraint (e.g., "type", "security", "style")
    pub kind: String,

    /// Constraint value or specification
    pub value: String,

    /// Optional custom error message
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

impl HoleSpec {
    /// Create a new hole specification
    pub fn new(hole_id: u64) -> Self {
        Self {
            hole_id,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        }
    }

    /// Add a JSON schema constraint
    pub fn with_schema(mut self, schema: JsonSchema) -> Self {
        self.fill_schema = Some(schema);
        self
    }

    /// Add a grammar constraint
    pub fn with_grammar(mut self, grammar: Grammar) -> Self {
        self.fill_grammar = Some(grammar);
        self
    }

    /// Add a fill constraint
    pub fn with_constraint(mut self, constraint: FillConstraint) -> Self {
        self.fill_constraints.push(constraint);
        self
    }

    /// Add a grammar reference
    pub fn with_grammar_ref(mut self, grammar_ref: String) -> Self {
        self.grammar_ref = Some(grammar_ref);
        self
    }
}

impl FillConstraint {
    /// Create a new fill constraint
    pub fn new(kind: String, value: String) -> Self {
        Self {
            kind,
            value,
            error_message: None,
        }
    }

    /// Add a custom error message
    pub fn with_error_message(mut self, message: String) -> Self {
        self.error_message = Some(message);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_constraint_ir_roundtrip() {
        let constraint = ConstraintIR {
            name: "test_constraint".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![RegexPattern {
                pattern: r"\d+".to_string(),
                flags: "g".to_string(),
            }],
            token_masks: None,
            priority: 1,
        };

        let ffi = constraint.to_ffi();
        unsafe {
            let restored = ConstraintIR::from_ffi(ffi).unwrap();
            assert_eq!(constraint.name, restored.name);
            assert_eq!(
                constraint.regex_patterns.len(),
                restored.regex_patterns.len()
            );
            free_constraint_ir_ffi(ffi);
        }
    }

    #[test]
    fn test_generation_result_to_ffi() {
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
            free_generation_result_ffi(ffi);
        }
    }
}
