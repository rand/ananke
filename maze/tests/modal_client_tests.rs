//! Integration tests for Modal client with mocking
//!
//! Tests HTTP communication with Modal inference service

use maze::modal_client::{
    ModalClient, ModalConfig, InferenceRequest, InferenceResponse,
};
use mockito::Server;

#[tokio::test]
async fn test_modal_client_health_check() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("GET", "/health")
        .with_status(200)
        .with_body("OK")
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    let result = client.health_check().await;
    
    assert!(result.is_ok());
    assert!(result.unwrap());
}

#[tokio::test]
async fn test_modal_client_health_check_failure() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("GET", "/health")
        .with_status(503)
        .with_body("Service Unavailable")
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    let result = client.health_check().await;
    
    assert!(result.is_ok());
    assert!(!result.unwrap());
}

#[tokio::test]
async fn test_modal_client_list_models() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("GET", "/models")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"["model1", "model2", "model3"]"#)
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    let models = client.list_models().await.unwrap();
    
    assert_eq!(models.len(), 3);
    assert_eq!(models[0], "model1");
    assert_eq!(models[1], "model2");
    assert_eq!(models[2], "model3");
}

#[tokio::test]
async fn test_modal_client_generate_success() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "fn main() {}",
        "tokens_generated": 10,
        "model": "test-model",
        "stats": {
            "total_time_ms": 100,
            "time_per_token_us": 10000,
            "constraint_checks": 5,
            "avg_constraint_check_us": 50
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "implement a function".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 100,
        temperature: 0.7,
        context: None,
    };
    
    let response = client.generate_constrained(request).await.unwrap();
    
    assert_eq!(response.generated_text, "fn main() {}");
    assert_eq!(response.tokens_generated, 10);
    assert_eq!(response.model, "test-model");
    assert_eq!(response.stats.total_time_ms, 100);
    assert_eq!(response.stats.constraint_checks, 5);
}

#[tokio::test]
async fn test_modal_client_generate_with_api_key() {
    let mut server = Server::new_async().await;
    
    let response_body = serde_json::json!({
        "generated_text": "result",
        "tokens_generated": 5,
        "model": "test-model",
        "stats": {
            "total_time_ms": 50,
            "time_per_token_us": 10000,
            "constraint_checks": 2,
            "avg_constraint_check_us": 25
        }
    });
    
    let _m = server.mock("POST", "/generate")
        .match_header("Authorization", "Bearer test-api-key")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    )
    .with_api_key("test-api-key".to_string());
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "test".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 10,
        temperature: 0.5,
        context: None,
    };
    
    let response = client.generate_constrained(request).await.unwrap();
    assert_eq!(response.generated_text, "result");
}

#[tokio::test]
async fn test_modal_client_generate_failure_401() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("POST", "/generate")
        .with_status(401)
        .with_body("Unauthorized")
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "test".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 10,
        temperature: 0.5,
        context: None,
    };
    
    let response = client.generate_constrained(request).await;
    assert!(response.is_err());

    // Just verify it failed - the error message format may vary
    // The important thing is that the client properly handles HTTP errors
}

#[tokio::test]
async fn test_modal_client_generate_failure_500() {
    let mut server = Server::new_async().await;
    
    let _m = server.mock("POST", "/generate")
        .with_status(500)
        .with_body("Internal Server Error")
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "test".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 10,
        temperature: 0.5,
        context: None,
    };
    
    let response = client.generate_constrained(request).await;
    assert!(response.is_err());
}

#[tokio::test]
async fn test_modal_client_retry_on_failure() {
    let mut server = Server::new_async().await;
    
    // First attempt fails
    let m1 = server.mock("POST", "/generate")
        .with_status(503)
        .with_body("Service Unavailable")
        .expect(1)
        .create_async()
        .await;
    
    // Second attempt succeeds
    let response_body = serde_json::json!({
        "generated_text": "success",
        "tokens_generated": 3,
        "model": "test-model",
        "stats": {
            "total_time_ms": 30,
            "time_per_token_us": 10000,
            "constraint_checks": 1,
            "avg_constraint_check_us": 30
        }
    });
    
    let m2 = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response_body.to_string())
        .expect(1)
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "test".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 10,
        temperature: 0.5,
        context: None,
    };
    
    let response = client.generate_constrained(request).await.unwrap();
    assert_eq!(response.generated_text, "success");
    
    m1.assert_async().await;
    m2.assert_async().await;
}

#[tokio::test]
async fn test_modal_client_retry_exhausted() {
    let mut server = Server::new_async().await;
    
    // All attempts fail
    let _m = server.mock("POST", "/generate")
        .with_status(503)
        .with_body("Service Unavailable")
        .expect(3)  // Default max_retries is 3
        .create_async()
        .await;
    
    let config = ModalConfig::new(
        server.url(),
        "test-model".to_string(),
    );
    
    let client = ModalClient::new(config).unwrap();
    
    let request = InferenceRequest {
        prompt: "test".to_string(),
        constraints: serde_json::json!({}),
        max_tokens: 10,
        temperature: 0.5,
        context: None,
    };
    
    let response = client.generate_constrained(request).await;
    assert!(response.is_err());
    
    let error_msg = response.unwrap_err().to_string();
    assert!(error_msg.contains("Failed after"));
}

#[test]
fn test_modal_config_from_builder() {
    let config = ModalConfig::new(
        "https://test.modal.run".to_string(),
        "test-model".to_string(),
    )
    .with_api_key("key".to_string())
    .with_timeout(600);
    
    assert_eq!(config.endpoint_url, "https://test.modal.run");
    assert_eq!(config.model, "test-model");
    assert_eq!(config.api_key, Some("key".to_string()));
    assert_eq!(config.timeout_secs, 600);
}

#[test]
fn test_inference_request_serialization() {
    let request = InferenceRequest {
        prompt: "test prompt".to_string(),
        constraints: serde_json::json!({"type": "test"}),
        max_tokens: 100,
        temperature: 0.7,
        context: None,
    };
    
    let json = serde_json::to_string(&request).unwrap();
    let deserialized: InferenceRequest = serde_json::from_str(&json).unwrap();
    
    assert_eq!(request.prompt, deserialized.prompt);
    assert_eq!(request.max_tokens, deserialized.max_tokens);
}

#[test]
fn test_inference_response_deserialization() {
    let json = r#"{
        "generated_text": "fn main() {}",
        "tokens_generated": 10,
        "model": "test-model",
        "stats": {
            "total_time_ms": 100,
            "time_per_token_us": 10000,
            "constraint_checks": 5,
            "avg_constraint_check_us": 50
        }
    }"#;
    
    let response: InferenceResponse = serde_json::from_str(json).unwrap();
    
    assert_eq!(response.generated_text, "fn main() {}");
    assert_eq!(response.tokens_generated, 10);
    assert_eq!(response.model, "test-model");
    assert_eq!(response.stats.total_time_ms, 100);
}
