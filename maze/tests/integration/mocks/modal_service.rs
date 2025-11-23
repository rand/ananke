//! Mock Modal inference service helpers for integration testing

use serde_json::json;

/// Mock scenario types
#[derive(Debug, Clone)]
pub enum MockScenario {
    Success,
    Timeout,
    ServerError,
    RateLimited,
    PartialResponse,
    LargeResponse,
    ConstraintViolation,
}

/// Mock response configuration
#[derive(Debug, Clone)]
pub struct MockResponse {
    pub generated_text: String,
    pub tokens_generated: usize,
    pub model: String,
    pub total_time_ms: u64,
}

impl Default for MockResponse {
    fn default() -> Self {
        Self {
            generated_text: "fn example() {}".to_string(),
            tokens_generated: 5,
            model: "test-model".to_string(),
            total_time_ms: 100,
        }
    }
}

/// Mock Modal service - just a wrapper around Server with helpers
pub struct MockModalService;

impl MockModalService {
    /// Get mock response JSON for a scenario
    pub fn scenario_response(scenario: MockScenario) -> serde_json::Value {
        match scenario {
            MockScenario::Success => json!({
                "generated_text": "fn authenticate(user: &str) -> Result<bool, Error> {\n    Ok(true)\n}",
                "tokens_generated": 20,
                "model": "test-model",
                "stats": {
                    "total_time_ms": 200,
                    "time_per_token_us": 10000,
                    "constraint_checks": 10,
                    "avg_constraint_check_us": 50
                }
            }),
            MockScenario::LargeResponse => {
                let large_code = "fn large_function() {\n".to_string() 
                    + &"    // line\n".repeat(100) 
                    + "}\n";
                
                json!({
                    "generated_text": large_code,
                    "tokens_generated": 500,
                    "model": "test-model",
                    "stats": {
                        "total_time_ms": 5000,
                        "time_per_token_us": 10000,
                        "constraint_checks": 250,
                        "avg_constraint_check_us": 100
                    }
                })
            },
            _ => json!({
                "generated_text": "fn example() {}",
                "tokens_generated": 5,
                "model": "test-model",
                "stats": {
                    "total_time_ms": 100,
                    "time_per_token_us": 20000,
                    "constraint_checks": 3,
                    "avg_constraint_check_us": 33
                }
            }),
        }
    }
    
    /// Get status code for scenario
    pub fn scenario_status(scenario: MockScenario) -> usize {
        match scenario {
            MockScenario::Success | MockScenario::LargeResponse | MockScenario::PartialResponse => 200,
            MockScenario::ConstraintViolation => 400,
            MockScenario::RateLimited => 429,
            MockScenario::ServerError => 500,
            MockScenario::Timeout => 504,
        }
    }
    
    /// Convert custom response to JSON
    pub fn custom_response(response: MockResponse) -> serde_json::Value {
        json!({
            "generated_text": response.generated_text,
            "tokens_generated": response.tokens_generated,
            "model": response.model,
            "stats": {
                "total_time_ms": response.total_time_ms,
                "time_per_token_us": if response.tokens_generated > 0 {
                    (response.total_time_ms * 1000) / response.tokens_generated as u64
                } else {
                    0
                },
                "constraint_checks": response.tokens_generated / 2,
                "avg_constraint_check_us": 50
            }
        })
    }
}
