//! Modal inference client
//!
//! Handles communication with Modal-hosted vLLM + llguidance inference service

use anyhow::{anyhow, Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;
use url::Url;

use crate::ffi::{ConstraintIR, HoleSpec};
use crate::model_router::{ModelEndpoint, ModelRouter, RoutingDecision};
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
#[derive(Clone)]
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

impl InferenceResponse {
    /// Calculate confidence score based on generation stats
    pub fn confidence(&self) -> f32 {
        // Simple heuristic: higher confidence if generation was fast and had few constraint checks
        // In production, this should use actual model confidence scores
        if self.tokens_generated == 0 {
            return 0.0;
        }

        let token_speed = self.stats.time_per_token_us as f32;
        let constraint_overhead = self.stats.avg_constraint_check_us as f32;

        // Normalize to 0-1 range (faster = higher confidence)
        let speed_score = 1.0 - (token_speed / 10000.0).min(1.0);
        let constraint_score = 1.0 - (constraint_overhead / 1000.0).min(1.0);

        (speed_score * 0.6 + constraint_score * 0.4).max(0.0).min(1.0)
    }
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
        let base_url = Url::parse(&config.endpoint_url).context("Invalid Modal endpoint URL")?;

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
    pub async fn generate_constrained(
        &self,
        request: InferenceRequest,
    ) -> Result<InferenceResponse> {
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
                        return Err(e).context(format!("Failed after {} attempts", attempts));
                    }

                    tracing::warn!("Generation attempt {} failed: {}. Retrying...", attempts, e);

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
        let url = self
            .base_url
            .join("/generate")
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
        let mut http_request = self
            .client
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
            let error_text = response
                .text()
                .await
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
        let url = self
            .base_url
            .join("/health")
            .context("Failed to build health check URL")?;

        let response = self
            .client
            .get(url)
            .send()
            .await
            .context("Health check request failed")?;

        Ok(response.status().is_success())
    }

    /// Get available models from Modal service
    pub async fn list_models(&self) -> Result<Vec<String>> {
        let url = self
            .base_url
            .join("/models")
            .context("Failed to build models URL")?;

        let response = self
            .client
            .get(url)
            .send()
            .await
            .context("Models request failed")?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Models request failed with status {}",
                response.status()
            ));
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

// ============================================================================
// Ensemble Client
// ============================================================================

/// Configuration for ensemble of models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnsembleConfig {
    pub endpoints: Vec<ModelEndpoint>,
    pub fallback_enabled: bool,
    pub best_of_n: Option<usize>,
    pub max_fallback_attempts: usize,
}

impl Default for EnsembleConfig {
    fn default() -> Self {
        Self {
            endpoints: vec![],
            fallback_enabled: true,
            best_of_n: None,
            max_fallback_attempts: 3,
        }
    }
}

/// Metrics for ensemble operations
#[derive(Debug, Default, Clone)]
pub struct EnsembleMetrics {
    pub per_model: HashMap<String, ModelMetrics>,
    pub total_requests: u64,
    pub total_fallbacks: u64,
}

#[derive(Debug, Default, Clone)]
pub struct ModelMetrics {
    pub requests: u64,
    pub successes: u64,
    pub failures: u64,
    pub total_latency_ms: u64,
    pub avg_confidence: f32,
}

impl ModelMetrics {
    pub fn success_rate(&self) -> f32 {
        if self.requests == 0 {
            0.0
        } else {
            self.successes as f32 / self.requests as f32
        }
    }

    pub fn avg_latency_ms(&self) -> u64 {
        if self.requests == 0 {
            0
        } else {
            self.total_latency_ms / self.requests
        }
    }
}

/// Ensemble client wrapping multiple ModalClient instances
pub struct EnsembleClient {
    clients: HashMap<String, ModalClient>,
    router: ModelRouter,
    config: EnsembleConfig,
    metrics: Arc<Mutex<EnsembleMetrics>>,
}

impl EnsembleClient {
    /// Create from ensemble configuration
    pub fn from_config(config: EnsembleConfig) -> Result<Self> {
        let mut clients = HashMap::new();

        for endpoint in &config.endpoints {
            let modal_config = ModalConfig {
                endpoint_url: endpoint.endpoint_url.clone(),
                api_key: endpoint.api_key.clone(),
                timeout_secs: endpoint.timeout_secs,
                model: endpoint.model.clone(),
                enable_retry: true,
                max_retries: 3,
            };

            let client = ModalClient::new(modal_config)?;
            clients.insert(endpoint.name.clone(), client);
        }

        let router = ModelRouter::new(config.endpoints.clone());

        Ok(Self {
            clients,
            router,
            config,
            metrics: Arc::new(Mutex::new(EnsembleMetrics::default())),
        })
    }

    /// Generate with automatic routing and fallback
    pub async fn generate_routed(
        &self,
        request: InferenceRequest,
        hole_spec: &HoleSpec,
        constraints: &[ConstraintIR],
    ) -> Result<InferenceResponse> {
        let routing = self.router.route(hole_spec, constraints);

        if self.config.fallback_enabled {
            self.generate_with_fallback(request, routing).await
        } else {
            self.generate_single(request, &routing.primary_model).await
        }
    }

    /// Generate with fallback on failure
    pub async fn generate_with_fallback(
        &self,
        request: InferenceRequest,
        routing: RoutingDecision,
    ) -> Result<InferenceResponse> {
        let mut last_error = None;
        let mut attempts = 0;

        for model_name in routing.all_models() {
            if attempts >= self.config.max_fallback_attempts {
                break;
            }

            let client = match self.clients.get(model_name) {
                Some(c) => c,
                None => {
                    tracing::warn!("Model {} not found in ensemble", model_name);
                    continue;
                }
            };

            let start = std::time::Instant::now();
            match client.generate_constrained(request.clone()).await {
                Ok(response) => {
                    self.record_success(
                        model_name,
                        start.elapsed().as_millis() as u64,
                        response.confidence(),
                    )
                    .await;
                    return Ok(response);
                }
                Err(e) => {
                    self.record_failure(model_name).await;
                    tracing::warn!("Model {} failed: {}, trying fallback", model_name, e);
                    last_error = Some(e);

                    if attempts > 0 {
                        let mut metrics = self.metrics.lock().await;
                        metrics.total_fallbacks += 1;
                    }
                }
            }

            attempts += 1;
        }

        Err(last_error.unwrap_or_else(|| anyhow::anyhow!("No models available in ensemble")))
    }

    /// Generate using best-of-N selection
    pub async fn generate_best_of_n(
        &self,
        request: InferenceRequest,
        n: usize,
        model_name: &str,
    ) -> Result<InferenceResponse> {
        let client = self
            .clients
            .get(model_name)
            .ok_or_else(|| anyhow::anyhow!("Model {} not found", model_name))?;

        let tasks: Vec<_> = (0..n)
            .map(|_| {
                let req = request.clone();
                let cli = client.clone();
                async move { cli.generate_constrained(req).await }
            })
            .collect();

        let results = futures::future::join_all(tasks).await;

        // Select best by confidence
        let best = results.into_iter().filter_map(Result::ok).max_by(|a, b| {
            a.confidence()
                .partial_cmp(&b.confidence())
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        best.ok_or_else(|| anyhow::anyhow!("All {} attempts failed", n))
    }

    async fn generate_single(
        &self,
        request: InferenceRequest,
        model_name: &str,
    ) -> Result<InferenceResponse> {
        let client = self
            .clients
            .get(model_name)
            .ok_or_else(|| anyhow::anyhow!("Model {} not found", model_name))?;

        let start = std::time::Instant::now();
        match client.generate_constrained(request).await {
            Ok(response) => {
                self.record_success(
                    model_name,
                    start.elapsed().as_millis() as u64,
                    response.confidence(),
                )
                .await;
                Ok(response)
            }
            Err(e) => {
                self.record_failure(model_name).await;
                Err(e)
            }
        }
    }

    async fn record_success(&self, model: &str, latency_ms: u64, confidence: f32) {
        let mut metrics = self.metrics.lock().await;
        metrics.total_requests += 1;

        let model_metrics = metrics
            .per_model
            .entry(model.to_string())
            .or_default();
        model_metrics.requests += 1;
        model_metrics.successes += 1;
        model_metrics.total_latency_ms += latency_ms;

        // Update rolling average confidence
        let total_success = model_metrics.successes as f32;
        model_metrics.avg_confidence =
            (model_metrics.avg_confidence * (total_success - 1.0) + confidence) / total_success;
    }

    async fn record_failure(&self, model: &str) {
        let mut metrics = self.metrics.lock().await;
        metrics.total_requests += 1;

        let model_metrics = metrics
            .per_model
            .entry(model.to_string())
            .or_default();
        model_metrics.requests += 1;
        model_metrics.failures += 1;
    }

    /// Get current metrics
    pub fn get_metrics(&self) -> Arc<Mutex<EnsembleMetrics>> {
        Arc::clone(&self.metrics)
    }

    /// Get the router for direct routing decisions
    pub fn router(&self) -> &ModelRouter {
        &self.router
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ensemble_config_default() {
        let config = EnsembleConfig::default();
        assert!(config.fallback_enabled);
        assert_eq!(config.max_fallback_attempts, 3);
        assert!(config.best_of_n.is_none());
    }

    #[test]
    fn test_model_metrics_success_rate() {
        let mut metrics = ModelMetrics::default();
        metrics.requests = 10;
        metrics.successes = 7;
        metrics.failures = 3;

        assert_eq!(metrics.success_rate(), 0.7);
    }

    #[test]
    fn test_model_metrics_avg_latency() {
        let mut metrics = ModelMetrics::default();
        metrics.requests = 5;
        metrics.total_latency_ms = 500;

        assert_eq!(metrics.avg_latency_ms(), 100);
    }

    #[test]
    fn test_ensemble_metrics_default() {
        let metrics = EnsembleMetrics::default();
        assert_eq!(metrics.total_requests, 0);
        assert_eq!(metrics.total_fallbacks, 0);
        assert!(metrics.per_model.is_empty());
    }

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
