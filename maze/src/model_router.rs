//! Constraint-aware model routing for multi-model ensemble

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::ffi::{ConstraintIR, HoleSpec};
use crate::model_selector::ModelSelector;

/// Capabilities a model can have
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ModelCapability {
    CodeCompletion,
    LongContext,
    ConstrainedGeneration,
    FastInference,
    HighQuality,
    SecurityAware,
}

/// Configuration for a single model endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelEndpoint {
    pub name: String,
    pub endpoint_url: String,
    pub model: String,
    pub api_key: Option<String>,
    pub timeout_secs: u64,
    pub capabilities: Vec<ModelCapability>,
    pub priority: u32, // Lower = higher priority for fallback
    pub cost_per_1k_tokens: f32,
}

impl Default for ModelEndpoint {
    fn default() -> Self {
        Self {
            name: "default".to_string(),
            endpoint_url: String::new(),
            model: "meta-llama/Llama-3.1-8B-Instruct".to_string(),
            api_key: None,
            timeout_secs: 300,
            capabilities: vec![ModelCapability::CodeCompletion],
            priority: 0,
            cost_per_1k_tokens: 0.0,
        }
    }
}

/// Routing decision for a request
#[derive(Debug, Clone)]
pub struct RoutingDecision {
    pub primary_model: String,
    pub fallback_models: Vec<String>,
    pub reason: String,
}

impl RoutingDecision {
    /// Iterator over primary then fallbacks
    pub fn all_models(&self) -> impl Iterator<Item = &String> {
        std::iter::once(&self.primary_model).chain(self.fallback_models.iter())
    }
}

/// Router for selecting models based on constraints and hole characteristics
pub struct ModelRouter {
    endpoints: HashMap<String, ModelEndpoint>,
    selector: ModelSelector,
    default_model: String,
}

impl ModelRouter {
    pub fn new(endpoints: Vec<ModelEndpoint>) -> Self {
        let mut endpoint_map = HashMap::new();
        let default_model = endpoints
            .first()
            .map(|e| e.name.clone())
            .unwrap_or_default();

        for endpoint in endpoints {
            endpoint_map.insert(endpoint.name.clone(), endpoint);
        }

        Self {
            endpoints: endpoint_map,
            selector: ModelSelector::default(),
            default_model,
        }
    }

    /// Route a request based on hole spec and constraints
    pub fn route(&self, hole_spec: &HoleSpec, constraints: &[ConstraintIR]) -> RoutingDecision {
        let complexity = self.selector.estimate_complexity(hole_spec);

        // Analyze constraint characteristics
        let has_security = constraints.iter().any(|c| c.token_masks.is_some());
        let has_grammar = constraints.iter().any(|c| c.grammar.is_some());
        let constraint_count = hole_spec.fill_constraints.len();

        // Select primary model based on characteristics
        let (primary_model, reason) = if has_security {
            self.find_model_with_capability(ModelCapability::SecurityAware)
                .map(|m| (m, "security constraints require security-aware model"))
                .unwrap_or((
                    self.default_model.clone(),
                    "no security-aware model, using default",
                ))
        } else if constraint_count > 10 || has_grammar {
            self.find_model_with_capability(ModelCapability::ConstrainedGeneration)
                .map(|m| (m, "complex constraints require constrained generation"))
                .unwrap_or((
                    self.default_model.clone(),
                    "no constrained generation model, using default",
                ))
        } else if complexity < 0.3 {
            self.find_model_with_capability(ModelCapability::FastInference)
                .map(|m| (m, "simple hole, using fast inference"))
                .unwrap_or((self.default_model.clone(), "no fast model, using default"))
        } else if complexity > 0.7 {
            self.find_model_with_capability(ModelCapability::HighQuality)
                .map(|m| (m, "complex hole, using high quality model"))
                .unwrap_or((
                    self.default_model.clone(),
                    "no high quality model, using default",
                ))
        } else {
            (
                self.default_model.clone(),
                "default selection for medium complexity",
            )
        };

        // Build fallback chain
        let fallback_models = self.build_fallback_chain(&primary_model);

        tracing::debug!(
            "Routing decision: primary={}, fallbacks={:?}, reason={}",
            primary_model,
            fallback_models,
            reason
        );

        RoutingDecision {
            primary_model,
            fallback_models,
            reason: reason.to_string(),
        }
    }

    fn find_model_with_capability(&self, capability: ModelCapability) -> Option<String> {
        self.endpoints
            .values()
            .filter(|e| e.capabilities.contains(&capability))
            .min_by_key(|e| e.priority)
            .map(|e| e.name.clone())
    }

    fn build_fallback_chain(&self, primary: &str) -> Vec<String> {
        let mut fallbacks: Vec<_> = self
            .endpoints
            .values()
            .filter(|e| e.name != primary)
            .collect();

        fallbacks.sort_by_key(|e| e.priority);
        fallbacks.into_iter().map(|e| e.name.clone()).collect()
    }

    pub fn get_endpoint(&self, name: &str) -> Option<&ModelEndpoint> {
        self.endpoints.get(name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::{FillConstraint, TokenMaskRules};

    fn create_test_endpoints() -> Vec<ModelEndpoint> {
        vec![
            ModelEndpoint {
                name: "fast".to_string(),
                capabilities: vec![ModelCapability::FastInference],
                priority: 1,
                ..Default::default()
            },
            ModelEndpoint {
                name: "quality".to_string(),
                capabilities: vec![
                    ModelCapability::HighQuality,
                    ModelCapability::SecurityAware,
                ],
                priority: 2,
                ..Default::default()
            },
            ModelEndpoint {
                name: "constrained".to_string(),
                capabilities: vec![ModelCapability::ConstrainedGeneration],
                priority: 3,
                ..Default::default()
            },
        ]
    }

    #[test]
    fn test_route_simple_hole_to_fast() {
        let router = ModelRouter::new(create_test_endpoints());

        let simple_spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        let routing = router.route(&simple_spec, &[]);
        assert_eq!(routing.primary_model, "fast");
    }

    #[test]
    fn test_route_security_constraints_to_security_aware() {
        let router = ModelRouter::new(create_test_endpoints());

        let spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        let constraints = vec![ConstraintIR {
            name: "security".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: Some(TokenMaskRules {
                allowed_tokens: None,
                forbidden_tokens: None,
            }),
            priority: 0,
        }];

        let routing = router.route(&spec, &constraints);
        assert_eq!(routing.primary_model, "quality");
    }

    #[test]
    fn test_route_many_constraints_to_constrained() {
        let router = ModelRouter::new(create_test_endpoints());

        let spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: (0..15)
                .map(|i| FillConstraint {
                    kind: "constraint".to_string(),
                    value: format!("value{}", i),
                    error_message: None,
                })
                .collect(),
            grammar_ref: None,
        };

        let routing = router.route(&spec, &[]);
        assert_eq!(routing.primary_model, "constrained");
    }

    #[test]
    fn test_fallback_chain_by_priority() {
        let router = ModelRouter::new(create_test_endpoints());

        let spec = HoleSpec::default();
        let routing = router.route(&spec, &[]);

        // Primary is "fast" (priority 1)
        // Fallbacks should be ordered by priority: quality (2), constrained (3)
        assert_eq!(routing.fallback_models, vec!["quality", "constrained"]);
    }

    #[test]
    fn test_default_model_fallback() {
        let router = ModelRouter::new(vec![ModelEndpoint {
            name: "only-model".to_string(),
            capabilities: vec![],
            priority: 1,
            ..Default::default()
        }]);

        let spec = HoleSpec {
            hole_id: 1,
            fill_schema: None,
            fill_grammar: None,
            fill_constraints: vec![],
            grammar_ref: None,
        };

        // Security constraints but no security-aware model
        let constraints = vec![ConstraintIR {
            name: "security".to_string(),
            json_schema: None,
            grammar: None,
            regex_patterns: vec![],
            token_masks: Some(TokenMaskRules {
                allowed_tokens: None,
                forbidden_tokens: None,
            }),
            priority: 0,
        }];

        let routing = router.route(&spec, &constraints);
        assert_eq!(routing.primary_model, "only-model");
        assert!(routing.reason.contains("no security-aware model"));
    }
}
