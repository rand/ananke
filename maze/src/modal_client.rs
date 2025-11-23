//! Modal inference client
//!
//! Handles communication with Modal-hosted vLLM + llguidance inference service

use anyhow::{Context, Result, anyhow};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use url::Url;

use crate::GenerationContext;

/// Configuration for Modal inference service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModalConfig {
    /// Modal endpoint URL
    pub endpoint_url: String,

    /// API key for authentication
    pub api_key: Option<String>,

    /// Request timeout in seconds
    pub timeout_secs: u64,

    /// Model name (e.g., "meta-llama/Llama-3.1-8B-Instruct")
    pub model: String,

    /// Enable retry on failure
    pub enable_retry: bool,

    /// Maximum retry attempts
    pub max_retries: usize,
}

impl ModalConfig {
    /// Create configuration from environment variables
    ///
    /// Expected environment variables:
    /// - MODAL_ENDPOINT: Modal inference service URL
    /// - MODAL_API_KEY: API key for authentication (optional)
    /// - MODAL_MODEL: Model name (default: meta-llama/Llama-3.1-8B-Instruct)
    pub fn from_env() -> Result<Self> {
        let endpoint_url = std::env::var("MODAL_ENDPOINT")
            .context("MODAL_ENDPOINT environment variable not set")?;

        let api_key = std::env::var("MODAL_API_KEY").ok();

        let model = std::env::var("MODAL_MODEL")
            .unwrap_or_else(|_| "meta-llama/Llama-3.1-8B-Instruct".to_string());

        Ok(Self {
            endpoint_url,
            api_key,
            timeout_secs: 300,
            model,
            enable_retry: true,
            max_retries: 3,
        })
    }

    /// Create a new configuration
    pub fn new(endpoint_url: String, model: String) -> Self {
        Self {
            endpoint_url,
            api_key: None,
            timeout_secs: 300,
            model,
            enable_retry: true,
            max_retries: 3,
        }
    }

    /// Set API key
    pub fn with_api_key(mut self, api_key: String) -> Self {
        self.api_key = Some(api_key);
        self
    }

    /// Set timeout
    pub fn with_timeout(mut self, timeout_secs: u64) -> Self {
        self.timeout_secs = timeout_secs;
        self
    }
}

/// Client for Modal inference service
pub struct ModalClient {
    /// HTTP client
    client: reqwest::Client,

    /// Configuration
    config: ModalConfig,

    /// Base URL for API calls
    base_url: Url,
}

/// Request to Modal inference service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InferenceRequest {
    /// Generation prompt
    pub prompt: String,

    /// Compiled constraints in llguidance format
    pub constraints: serde_json::Value,

    /// Maximum tokens to generate
    pub max_tokens: usize,

    /// Sampling temperature
    pub temperature: f32,

    /// Optional context
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<GenerationContext>,
}

/// Response from Modal inference service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InferenceResponse {
    /// Generated text
    pub generated_text: String,

    /// Number of tokens generated
    pub tokens_generated: usize,

    /// Model used
    pub model: String,

    /// Generation statistics
    pub stats: GenerationStats,
}

/// Statistics from generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationStats {
    /// Total generation time in milliseconds
    pub total_time_ms: u64,

    /// Time per token in microseconds
    pub time_per_token_us: u64,

    /// Number of constraint checks performed
    pub constraint_checks: usize,

    /// Average constraint check time in microseconds
    pub avg_constraint_check_us: u64,
}

impl ModalClient {
    /// Create a new Modal client
    pub fn new(config: ModalConfig) -> Result<Self> {
        // Parse and validate endpoint URL
        let base_url = Url::parse(&config.endpoint_url)
            .context("Invalid Modal endpoint URL")?;

        // Build HTTP client with timeout
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(config.timeout_secs))
            .build()
            .context("Failed to build HTTP client")?;

        Ok(Self {
            client,
            config,
            base_url,
        })
    }

    /// Generate code with constraints
    pub async fn generate_constrained(&self, request: InferenceRequest) -> Result<InferenceResponse> {
        let mut attempts = 0;
        let max_attempts = if self.config.enable_retry {
            self.config.max_retries
        } else {
            1
        };

        loop {
            attempts += 1;

            match self.generate_internal(&request).await {
                Ok(response) => return Ok(response),
                Err(e) => {
                    if attempts >= max_attempts {
                        return Err(e).context(format!(
                            "Failed after {} attempts",
                            attempts
                        ));
                    }

                    tracing::warn!(
                        "Generation attempt {} failed: {}. Retrying...",
                        attempts,
                        e
                    );

                    // Exponential backoff
                    let backoff = Duration::from_millis(100 * 2_u64.pow(attempts as u32 - 1));
                    tokio::time::sleep(backoff).await;
                }
            }
        }
    }

    /// Internal generation method
    async fn generate_internal(&self, request: &InferenceRequest) -> Result<InferenceResponse> {
        // Build request URL
        let url = self.base_url.join("/generate")
            .context("Failed to build request URL")?;

        // Build request body
        let body = serde_json::json!({
            "prompt": request.prompt,
            "constraints": request.constraints,
            "max_tokens": request.max_tokens,
            "temperature": request.temperature,
            "model": self.config.model,
            "context": request.context,
        });

        // Build HTTP request
        let mut http_request = self.client
            .post(url)
            .header("Content-Type", "application/json")
            .json(&body);

        // Add API key if present
        if let Some(ref api_key) = self.config.api_key {
            http_request = http_request.header("Authorization", format!("Bearer {}", api_key));
        }

        // Send request
        tracing::debug!("Sending generation request to Modal: {:?}", request.prompt);
        let response = http_request
            .send()
            .await
            .context("Failed to send request to Modal")?;

        // Check response status
        let status = response.status();
        if !status.is_success() {
            let error_text = response.text().await
                .unwrap_or_else(|_| "Unable to read error response".to_string());
            return Err(anyhow!(
                "Modal inference failed with status {}: {}",
                status,
                error_text
            ));
        }

        // Parse response
        let inference_response: InferenceResponse = response
            .json()
            .await
            .context("Failed to parse Modal response")?;

        tracing::debug!(
            "Generated {} tokens in {}ms",
            inference_response.tokens_generated,
            inference_response.stats.total_time_ms
        );

        Ok(inference_response)
    }

    /// Health check for Modal service
    pub async fn health_check(&self) -> Result<bool> {
        let url = self.base_url.join("/health")
            .context("Failed to build health check URL")?;

        let response = self.client
            .get(url)
            .send()
            .await
            .context("Health check request failed")?;

        Ok(response.status().is_success())
    }

    /// Get available models from Modal service
    pub async fn list_models(&self) -> Result<Vec<String>> {
        let url = self.base_url.join("/models")
            .context("Failed to build models URL")?;

        let response = self.client
            .get(url)
            .send()
            .await
            .context("Models request failed")?;

        if !response.status().is_success() {
            return Err(anyhow!("Models request failed with status {}", response.status()));
        }

        let models: Vec<String> = response
            .json()
            .await
            .context("Failed to parse models response")?;

        Ok(models)
    }

    /// Stream generation (for future implementation)
    pub async fn generate_stream(&self, _request: InferenceRequest) -> Result<()> {
        // TODO: Implement streaming generation
        Err(anyhow!("Streaming generation not yet implemented"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_modal_config_new() {
        let config = ModalConfig::new(
            "https://example.modal.run".to_string(),
            "test-model".to_string(),
        );

        assert_eq!(config.endpoint_url, "https://example.modal.run");
        assert_eq!(config.model, "test-model");
        assert!(config.api_key.is_none());
    }

    #[test]
    fn test_modal_config_with_api_key() {
        let config = ModalConfig::new(
            "https://example.modal.run".to_string(),
            "test-model".to_string(),
        )
        .with_api_key("test-key".to_string());

        assert_eq!(config.api_key, Some("test-key".to_string()));
    }

    #[test]
    fn test_inference_request_serialization() {
        let request = InferenceRequest {
            prompt: "test prompt".to_string(),
            constraints: serde_json::json!({}),
            max_tokens: 100,
            temperature: 0.7,
            context: None,
        };

        let json = serde_json::to_string(&request).unwrap();
        let deserialized: InferenceRequest = serde_json::from_str(&json).unwrap();

        assert_eq!(request.prompt, deserialized.prompt);
        assert_eq!(request.max_tokens, deserialized.max_tokens);
    }

    #[tokio::test]
    async fn test_modal_client_creation() {
        let config = ModalConfig::new(
            "https://example.modal.run".to_string(),
            "test-model".to_string(),
        );

        let client = ModalClient::new(config);
        assert!(client.is_ok());
    }
}
