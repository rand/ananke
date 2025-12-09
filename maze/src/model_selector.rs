//! Model selection logic for typed hole filling
//!
//! Determines whether to use autoregressive or diffusion models based on
//! hole characteristics, constraint complexity, and heuristics.

use serde::{Deserialize, Serialize};

use crate::ffi::HoleSpec;

/// Model choice for filling a hole
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ModelChoice {
    /// Use autoregressive model (e.g., GPT, Llama)
    Autoregressive {
        /// Sampling temperature (0.0-1.0)
        temperature: f32,

        /// Maximum tokens to generate
        max_tokens: usize,

        /// Top-p (nucleus) sampling threshold
        #[serde(skip_serializing_if = "Option::is_none")]
        top_p: Option<f32>,

        /// Model name override (if specific model needed)
        #[serde(skip_serializing_if = "Option::is_none")]
        model: Option<String>,
    },

    /// Use diffusion model (experimental)
    Diffusion {
        /// Number of diffusion steps
        num_steps: usize,

        /// Guidance scale for constraint adherence
        guidance_scale: f32,

        /// Noise schedule
        noise_schedule: String,
    },
}

impl Default for ModelChoice {
    fn default() -> Self {
        Self::Autoregressive {
            temperature: 0.7,
            max_tokens: 512,
            top_p: Some(0.95),
            model: None,
        }
    }
}

/// Model selector for choosing the best model for a hole
pub struct ModelSelector {
    /// Threshold for constraint count to prefer diffusion
    constraint_threshold: usize,

    /// Complexity threshold for preferring diffusion
    complexity_threshold: f32,

    /// Enable diffusion model support
    enable_diffusion: bool,
}

impl Default for ModelSelector {
    fn default() -> Self {
        Self {
            constraint_threshold: 5,
            complexity_threshold: 0.7,
            enable_diffusion: false,
        }
    }
}

impl ModelSelector {
    /// Create a new model selector
    pub fn new(
        constraint_threshold: usize,
        complexity_threshold: f32,
        enable_diffusion: bool,
    ) -> Self {
        Self {
            constraint_threshold,
            complexity_threshold,
            enable_diffusion,
        }
    }

    /// Select the best model for a given hole specification
    ///
    /// # Arguments
    /// * `hole_spec` - Specification of the hole to fill
    ///
    /// # Returns
    /// The recommended model choice with parameters
    ///
    /// # Selection Heuristics
    ///
    /// Prefers autoregressive models when:
    /// - Hole has simple constraints (< threshold)
    /// - Hole requires sequential/syntactic generation
    /// - Low complexity score
    /// - Diffusion is disabled
    ///
    /// Prefers diffusion models when:
    /// - Hole has many complex constraints (>= threshold)
    /// - High complexity score
    /// - Non-sequential generation beneficial
    /// - Diffusion is enabled
    pub fn select(&self, hole_spec: &HoleSpec) -> ModelChoice {
        let constraint_count = hole_spec.fill_constraints.len();
        let complexity = self.estimate_complexity(hole_spec);

        tracing::debug!(
            "Model selection: hole_id={}, constraints={}, complexity={}",
            hole_spec.hole_id,
            constraint_count,
            complexity
        );

        // If diffusion is disabled, always use autoregressive
        if !self.enable_diffusion {
            return self.select_autoregressive(hole_spec, complexity);
        }

        // Use diffusion if constraints are complex and numerous
        if constraint_count >= self.constraint_threshold
            && complexity >= self.complexity_threshold
        {
            tracing::debug!(
                "Selecting diffusion model for hole {} (high constraint count and complexity)",
                hole_spec.hole_id
            );
            return self.select_diffusion(hole_spec, complexity);
        }

        // Otherwise, use autoregressive
        tracing::debug!(
            "Selecting autoregressive model for hole {} (low/medium complexity)",
            hole_spec.hole_id
        );
        self.select_autoregressive(hole_spec, complexity)
    }

    /// Select autoregressive model with appropriate parameters
    fn select_autoregressive(&self, hole_spec: &HoleSpec, complexity: f32) -> ModelChoice {
        // Adjust temperature based on complexity
        // Higher complexity -> lower temperature (more conservative)
        let temperature = if complexity > 0.8 {
            0.3
        } else if complexity > 0.5 {
            0.5
        } else {
            0.7
        };

        // Estimate max tokens based on hole spec
        let max_tokens = self.estimate_max_tokens(hole_spec);

        // Use top_p sampling for better quality
        let top_p = Some(0.95);

        ModelChoice::Autoregressive {
            temperature,
            max_tokens,
            top_p,
            model: None, // Use default model
        }
    }

    /// Select diffusion model with appropriate parameters
    fn select_diffusion(&self, _hole_spec: &HoleSpec, complexity: f32) -> ModelChoice {
        // More steps for higher complexity
        let num_steps = if complexity > 0.8 {
            100
        } else if complexity > 0.6 {
            75
        } else {
            50
        };

        // Higher guidance scale for more constraints
        let guidance_scale = 7.5 + (complexity * 2.5);

        // Cosine schedule is generally good default
        let noise_schedule = "cosine".to_string();

        ModelChoice::Diffusion {
            num_steps,
            guidance_scale,
            noise_schedule,
        }
    }

    /// Estimate complexity of a hole based on its specification
    ///
    /// Returns a score from 0.0 (simple) to 1.0 (very complex)
    pub fn estimate_complexity(&self, hole_spec: &HoleSpec) -> f32 {
        let mut complexity = 0.0;
        let mut factors = 0;

        // Factor 1: Number of constraints
        let constraint_count = hole_spec.fill_constraints.len() as f32;
        complexity += (constraint_count / 10.0).min(1.0);
        factors += 1;

        // Factor 2: Schema complexity
        if let Some(ref schema) = hole_spec.fill_schema {
            let schema_complexity = self.estimate_schema_complexity(schema);
            complexity += schema_complexity;
            factors += 1;
        }

        // Factor 3: Grammar complexity
        if let Some(ref grammar) = hole_spec.fill_grammar {
            let grammar_complexity = self.estimate_grammar_complexity(grammar);
            complexity += grammar_complexity;
            factors += 1;
        }

        // Average the factors
        if factors > 0 {
            complexity / factors as f32
        } else {
            0.5 // Default medium complexity
        }
    }

    /// Estimate JSON schema complexity
    fn estimate_schema_complexity(&self, schema: &crate::ffi::JsonSchema) -> f32 {
        let mut complexity = 0.0;

        // More properties = more complex
        complexity += (schema.properties.len() as f32 / 20.0).min(0.5);

        // More required fields = more complex
        complexity += (schema.required.len() as f32 / 10.0).min(0.3);

        // Nested objects increase complexity
        let nested_count = schema
            .properties
            .values()
            .filter(|v| v.is_object())
            .count() as f32;
        complexity += (nested_count / 5.0).min(0.2);

        complexity.min(1.0)
    }

    /// Estimate grammar complexity
    fn estimate_grammar_complexity(&self, grammar: &crate::ffi::Grammar) -> f32 {
        let mut complexity = 0.0;

        // More rules = more complex
        complexity += (grammar.rules.len() as f32 / 50.0).min(0.5);

        // More symbols per rule = more complex
        let avg_symbols = if !grammar.rules.is_empty() {
            let total_symbols: usize = grammar.rules.iter().map(|r| r.rhs.len()).sum();
            total_symbols as f32 / grammar.rules.len() as f32
        } else {
            0.0
        };
        complexity += (avg_symbols / 10.0).min(0.5);

        complexity.min(1.0)
    }

    /// Estimate maximum tokens needed for a hole
    fn estimate_max_tokens(&self, hole_spec: &HoleSpec) -> usize {
        // Base estimate
        let mut max_tokens = 256;

        // Increase for schema complexity
        if hole_spec.fill_schema.is_some() {
            max_tokens += 128;
        }

        // Increase for grammar
        if hole_spec.fill_grammar.is_some() {
            max_tokens += 256;
        }

        // Increase for multiple constraints
        max_tokens += hole_spec.fill_constraints.len() * 32;

        // Cap at reasonable maximum
        max_tokens.min(2048)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::{FillConstraint, Grammar, GrammarRule, JsonSchema};
    use std::collections::HashMap;

    #[test]
    fn test_model_choice_default() {
        let choice = ModelChoice::default();
        match choice {
            ModelChoice::Autoregressive {
                temperature,
                max_tokens,
                ..
            } => {
                assert_eq!(temperature, 0.7);
                assert_eq!(max_tokens, 512);
            }
            _ => panic!("Expected autoregressive model"),
        }
    }

    #[test]
    fn test_model_selector_default() {
        let selector = ModelSelector::default();
        assert_eq!(selector.constraint_threshold, 5);
        assert_eq!(selector.complexity_threshold, 0.7);
        assert!(!selector.enable_diffusion);
    }

    #[test]
    fn test_select_autoregressive_simple() {
        let selector = ModelSelector::default();

        let hole_spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        let choice = selector.select(&hole_spec);
        match choice {
            ModelChoice::Autoregressive { temperature, .. } => {
                assert!(temperature > 0.0);
            }
            _ => panic!("Expected autoregressive for simple hole"),
        }
    }

    #[test]
    fn test_select_diffusion_complex() {
        // Lower thresholds to ensure diffusion is selected for complex holes
        let selector = ModelSelector::new(3, 0.4, true);

        let hole_spec = HoleSpec {
            hole_id: 1,
            fill_schema: Some(JsonSchema {
                schema_type: "object".to_string(),
                properties: (0..10)
                    .map(|i| (format!("prop{}", i), serde_json::json!({"type": "string"})))
                    .collect::<HashMap<_, _>>(),
                required: vec!["prop0".to_string(), "prop1".to_string()],
                additional_properties: false,
            }),
            fill_grammar: Some(Grammar {
                rules: vec![
                    GrammarRule {
                        lhs: "S".to_string(),
                        rhs: vec!["A".to_string(), "B".to_string()],
                    },
                    GrammarRule {
                        lhs: "A".to_string(),
                        rhs: vec!["a".to_string()],
                    },
                ],
                start_symbol: "S".to_string(),
            }),
            fill_constraints: vec![
                FillConstraint {
                    kind: "type".to_string(),
                    value: "function".to_string(),
                    error_message: None,
                },
                FillConstraint {
                    kind: "security".to_string(),
                    value: "no_unsafe".to_string(),
                    error_message: None,
                },
                FillConstraint {
                    kind: "style".to_string(),
                    value: "idiomatic".to_string(),
                    error_message: None,
                },
            ],
            grammar_ref: None,
        };

        let choice = selector.select(&hole_spec);
        match choice {
            ModelChoice::Diffusion { num_steps, .. } => {
                assert!(num_steps >= 50);
            }
            _ => panic!("Expected diffusion for complex hole"),
        }
    }

    #[test]
    fn test_estimate_complexity_simple() {
        let selector = ModelSelector::default();

        let hole_spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        let complexity = selector.estimate_complexity(&hole_spec);
        assert!(complexity < 0.3);
    }

    #[test]
    fn test_estimate_complexity_high() {
        let selector = ModelSelector::default();

        let hole_spec = HoleSpec {
            hole_id: 1,
            fill_schema: Some(JsonSchema {
                schema_type: "object".to_string(),
                properties: (0..20)
                    .map(|i| (format!("prop{}", i), serde_json::json!({"type": "string"})))
                    .collect::<HashMap<_, _>>(),
                required: (0..10).map(|i| format!("prop{}", i)).collect(),
                additional_properties: false,
            }),
            fill_grammar: None,
            fill_constraints: (0..8)
                .map(|i| FillConstraint {
                    kind: "constraint".to_string(),
                    value: format!("value{}", i),
                    error_message: None,
                })
                .collect(),
            grammar_ref: None,
        };

        let complexity = selector.estimate_complexity(&hole_spec);
        assert!(complexity > 0.5);
    }

    #[test]
    fn test_estimate_max_tokens() {
        let selector = ModelSelector::default();

        let simple_spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        let complex_spec = HoleSpec {
            hole_id: 2,
            fill_schema: Some(JsonSchema {
                schema_type: "object".to_string(),
                properties: HashMap::new(),
                required: vec![],
                additional_properties: false,
            }),
            fill_grammar: Some(Grammar {
                rules: vec![],
                start_symbol: "S".to_string(),
            }),
            fill_constraints: vec![
                FillConstraint {
                    kind: "test".to_string(),
                    value: "value".to_string(),
                    error_message: None,
                },
                FillConstraint {
                    kind: "test2".to_string(),
                    value: "value2".to_string(),
                    error_message: None,
                },
            ],
            grammar_ref: None,
        };

        let simple_tokens = selector.estimate_max_tokens(&simple_spec);
        let complex_tokens = selector.estimate_max_tokens(&complex_spec);

        assert!(simple_tokens < complex_tokens);
        assert!(complex_tokens <= 2048);
    }
}
