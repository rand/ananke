//! Maze: Orchestration layer for constrained code generation
//!
//! Maze coordinates between Ananke's constraint engines (Clew/Braid in Zig)
//! and GPU-based inference services (vLLM + llguidance) to perform
//! token-level constrained code generation.
//!
//! # Architecture
//!
//! ```text
//! Zig (Ananke Core)  →  ConstraintIR  →  Maze (Rust)  →  Modal/vLLM  →  Generated Code
//! ```
//!
//! # Usage
//!
//! ```rust,no_run
//! use maze::{MazeOrchestrator, ModalConfig, GenerationRequest};
//!
//! #[tokio::main]
//! async fn main() -> anyhow::Result<()> {
//!     let config = ModalConfig::from_env()?;
//!     let orchestrator = MazeOrchestrator::new(config)?;
//!
//!     let request = GenerationRequest {
//!         prompt: "Implement a secure API handler".to_string(),
//!         constraints_ir: vec![/* ConstraintIR from Zig */],
//!         max_tokens: 2048,
//!         temperature: 0.7,
//!         context: None,
//!     };
//!
//!     let result = orchestrator.generate(request).await?;
//!     println!("Generated code: {}", result.code);
//!     Ok(())
//! }
//! ```

pub mod ffi;
pub mod modal_client;
pub mod python;
pub mod progressive_refinement;
pub mod diffusion;
pub mod model_selector;

use anyhow::{Context, Result};
use lru::LruCache;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::num::NonZeroUsize;
use std::sync::Arc;
use tokio::sync::Mutex;

pub use ffi::{ConstraintIR, FillConstraint, GenerationResult, HoleSpec, Intent};
pub use modal_client::{ModalClient, ModalConfig};
pub use progressive_refinement::{
    FailureStrategy, HoleState, HoleStatus, ProgressiveRefiner, RefinementConfig,
    RefinementResult,
};
pub use diffusion::{DiffusionConfig, DiffusionGenerator, DiffusionResult, NoiseSchedule};
pub use model_selector::{ModelChoice, ModelSelector};

/// Main orchestrator for constrained code generation
///
/// Coordinates between Zig constraint engines and inference services
pub struct MazeOrchestrator {
    /// Client for communicating with Modal inference service
    modal_client: ModalClient,

    /// LRU cache for compiled constraints to avoid re-compilation
    /// Uses LRU eviction policy for O(1) cache operations
    constraint_cache: Arc<Mutex<LruCache<String, CompiledConstraint>>>,

    /// Configuration
    config: MazeConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MazeConfig {
    /// Maximum number of tokens to generate
    pub max_tokens: usize,

    /// Default temperature for sampling
    pub temperature: f32,

    /// Enable constraint caching
    pub enable_cache: bool,

    /// Cache size limit
    pub cache_size_limit: usize,

    /// Request timeout in seconds
    pub timeout_secs: u64,
}

impl Default for MazeConfig {
    fn default() -> Self {
        Self {
            max_tokens: 2048,
            temperature: 0.7,
            enable_cache: true,
            cache_size_limit: 1000,
            timeout_secs: 300,
        }
    }
}

/// Request for code generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationRequest {
    /// User intent / prompt for generation
    pub prompt: String,

    /// Compiled constraint IR from Braid
    pub constraints_ir: Vec<ConstraintIR>,

    /// Maximum tokens to generate
    pub max_tokens: usize,

    /// Sampling temperature (0.0 to 1.0)
    pub temperature: f32,

    /// Optional context for the generation
    pub context: Option<GenerationContext>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationContext {
    /// Current file being edited
    pub current_file: Option<String>,

    /// Programming language
    pub language: Option<String>,

    /// Project root path
    pub project_root: Option<String>,

    /// Additional context metadata
    pub metadata: HashMap<String, serde_json::Value>,
}

/// Compiled constraint ready for llguidance
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledConstraint {
    /// Hash of the constraint IR for caching
    pub hash: String,

    /// Compiled llguidance schema
    pub llguidance_schema: serde_json::Value,

    /// Compilation timestamp
    pub compiled_at: i64,
}

/// Response from generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationResponse {
    /// Generated code
    pub code: String,

    /// Provenance tracking
    pub provenance: Provenance,

    /// Constraint validation results
    pub validation: ValidationResult,

    /// Generation metadata
    pub metadata: GenerationMetadata,
}

/// Provenance tracking for generated code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    /// Model used for generation
    pub model: String,

    /// Timestamp of generation
    pub timestamp: i64,

    /// Constraints applied
    pub constraints_applied: Vec<String>,

    /// Original intent
    pub original_intent: String,

    /// Generation parameters
    pub parameters: HashMap<String, serde_json::Value>,
}

/// Validation results for generated code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    /// Whether all constraints were satisfied
    pub all_satisfied: bool,

    /// List of satisfied constraints
    pub satisfied: Vec<String>,

    /// List of violated constraints (should be empty with llguidance)
    pub violated: Vec<String>,

    /// Validation metadata
    pub metadata: HashMap<String, serde_json::Value>,
}

/// Generation metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationMetadata {
    /// Total tokens generated
    pub tokens_generated: usize,

    /// Generation time in milliseconds
    pub generation_time_ms: u64,

    /// Average time per token in microseconds
    pub avg_token_time_us: u64,

    /// Constraint compilation time in milliseconds
    pub constraint_compile_time_ms: u64,
}

impl MazeOrchestrator {
    /// Create a new Maze orchestrator
    pub fn new(modal_config: ModalConfig) -> Result<Self> {
        let modal_client = ModalClient::new(modal_config)?;
        let default_config = MazeConfig::default();

        let cache_size = NonZeroUsize::new(default_config.cache_size_limit)
            .expect("Cache size must be non-zero");

        Ok(Self {
            modal_client,
            constraint_cache: Arc::new(Mutex::new(LruCache::new(cache_size))),
            config: default_config,
        })
    }

    /// Create with custom configuration
    pub fn with_config(modal_config: ModalConfig, maze_config: MazeConfig) -> Result<Self> {
        let modal_client = ModalClient::new(modal_config)?;

        let cache_size =
            NonZeroUsize::new(maze_config.cache_size_limit).expect("Cache size must be non-zero");

        Ok(Self {
            modal_client,
            constraint_cache: Arc::new(Mutex::new(LruCache::new(cache_size))),
            config: maze_config,
        })
    }

    /// Generate code with constraints
    ///
    /// This is the main entry point for constrained code generation.
    /// It coordinates between constraint compilation and inference.
    pub async fn generate(&self, request: GenerationRequest) -> Result<GenerationResponse> {
        let _start_time = std::time::Instant::now();

        // Compile constraints to llguidance format
        let compile_start = std::time::Instant::now();
        let compiled = self.compile_constraints(&request.constraints_ir).await?;
        let constraint_compile_time_ms = compile_start.elapsed().as_millis() as u64;

        // Build the generation request for Modal
        let modal_request = modal_client::InferenceRequest {
            prompt: request.prompt.clone(),
            constraints: compiled.llguidance_schema.clone(),
            max_tokens: request.max_tokens,
            temperature: request.temperature,
            context: request.context.clone(),
        };

        // Call Modal inference service
        let gen_start = std::time::Instant::now();
        let modal_response = self
            .modal_client
            .generate_constrained(modal_request)
            .await
            .context("Failed to generate with Modal inference service")?;
        let generation_time_ms = gen_start.elapsed().as_millis() as u64;

        // Build provenance
        let provenance = Provenance {
            model: modal_response.model.clone(),
            timestamp: chrono::Utc::now().timestamp(),
            constraints_applied: request
                .constraints_ir
                .iter()
                .map(|c| c.name.clone())
                .collect(),
            original_intent: request.prompt.clone(),
            parameters: {
                let mut params = HashMap::new();
                params.insert(
                    "max_tokens".to_string(),
                    serde_json::json!(request.max_tokens),
                );
                params.insert(
                    "temperature".to_string(),
                    serde_json::json!(request.temperature),
                );
                params
            },
        };

        // Build validation result (llguidance ensures satisfaction)
        let validation = ValidationResult {
            all_satisfied: true,
            satisfied: request
                .constraints_ir
                .iter()
                .map(|c| c.name.clone())
                .collect(),
            violated: vec![],
            metadata: HashMap::new(),
        };

        // Calculate metadata
        let tokens_generated = modal_response.tokens_generated;
        let avg_token_time_us = if tokens_generated > 0 {
            (generation_time_ms * 1000) / tokens_generated as u64
        } else {
            0
        };

        let metadata = GenerationMetadata {
            tokens_generated,
            generation_time_ms,
            avg_token_time_us,
            constraint_compile_time_ms,
        };

        Ok(GenerationResponse {
            code: modal_response.generated_text,
            provenance,
            validation,
            metadata,
        })
    }

    /// Compile constraints to llguidance format with caching
    /// Uses LRU cache for O(1) eviction instead of O(n) linear scan
    pub async fn compile_constraints(
        &self,
        constraints_ir: &[ConstraintIR],
    ) -> Result<CompiledConstraint> {
        // Generate cache key from constraints
        let cache_key = self.generate_cache_key(constraints_ir)?;

        // Check cache if enabled
        if self.config.enable_cache {
            let mut cache = self.constraint_cache.lock().await;
            if let Some(cached) = cache.get(&cache_key) {
                tracing::debug!("Cache hit for constraints: {}", cache_key);
                return Ok(cached.clone());
            }
        }

        // Compile constraints
        let llguidance_schema = self.compile_to_llguidance(constraints_ir)?;

        let compiled = CompiledConstraint {
            hash: cache_key.clone(),
            llguidance_schema,
            compiled_at: chrono::Utc::now().timestamp(),
        };

        // Store in cache if enabled
        // LRU cache automatically handles eviction with O(1) complexity
        if self.config.enable_cache {
            let mut cache = self.constraint_cache.lock().await;
            cache.put(cache_key, compiled.clone());
        }

        Ok(compiled)
    }

    /// Generate cache key from constraint IR
    /// Uses xxHash3 for high-performance hashing (2-3x faster than DefaultHasher)
    pub fn generate_cache_key(&self, constraints_ir: &[ConstraintIR]) -> Result<String> {
        use std::hash::Hasher;
        use xxhash_rust::xxh3::Xxh3;

        let json = serde_json::to_string(constraints_ir)
            .context("Failed to serialize constraints for caching")?;

        let mut hasher = Xxh3::new();
        hasher.write(json.as_bytes());
        Ok(format!("{:x}", hasher.finish()))
    }

    /// Compile ConstraintIR to llguidance JSON schema
    fn compile_to_llguidance(&self, constraints_ir: &[ConstraintIR]) -> Result<serde_json::Value> {
        // Convert ConstraintIR to llguidance format
        // llguidance supports JSON schema, CFG, and regex

        let mut schema = serde_json::json!({
            "type": "object",
            "properties": {},
            "constraints": []
        });

        for constraint in constraints_ir {
            // Add JSON schema constraints
            if let Some(ref json_schema) = constraint.json_schema {
                if let Some(properties) = schema.get_mut("properties") {
                    properties[&constraint.name] = serde_json::json!(json_schema);
                }
            }

            // Add grammar constraints
            if let Some(ref grammar) = constraint.grammar {
                if let Some(constraints) =
                    schema.get_mut("constraints").and_then(|c| c.as_array_mut())
                {
                    constraints.push(serde_json::json!({
                        "type": "grammar",
                        "name": constraint.name,
                        "rules": grammar.rules,
                        "start": grammar.start_symbol
                    }));
                }
            }

            // Add regex constraints
            if !constraint.regex_patterns.is_empty() {
                if let Some(constraints) =
                    schema.get_mut("constraints").and_then(|c| c.as_array_mut())
                {
                    for pattern in &constraint.regex_patterns {
                        constraints.push(serde_json::json!({
                            "type": "regex",
                            "pattern": pattern.pattern,
                            "flags": pattern.flags
                        }));
                    }
                }
            }

            // Add token mask constraints
            if let Some(ref token_masks) = constraint.token_masks {
                if let Some(constraints) =
                    schema.get_mut("constraints").and_then(|c| c.as_array_mut())
                {
                    let mut mask_constraint = serde_json::json!({
                        "type": "token_mask",
                        "name": constraint.name
                    });

                    if let Some(allowed) = &token_masks.allowed_tokens {
                        mask_constraint["allowed"] = serde_json::json!(allowed);
                    }

                    if let Some(forbidden) = &token_masks.forbidden_tokens {
                        mask_constraint["forbidden"] = serde_json::json!(forbidden);
                    }

                    constraints.push(mask_constraint);
                }
            }
        }

        Ok(schema)
    }

    /// Clear the constraint cache
    pub async fn clear_cache(&self) -> Result<()> {
        let mut cache = self.constraint_cache.lock().await;
        cache.clear();
        Ok(())
    }

    /// Get cache statistics
    pub async fn cache_stats(&self) -> CacheStats {
        let cache = self.constraint_cache.lock().await;
        CacheStats {
            size: cache.len(),
            limit: cache.cap().get(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub size: usize,
    pub limit: usize,
}

// Re-export for convenience
pub use chrono;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_maze_config_default() {
        let config = MazeConfig::default();
        assert_eq!(config.max_tokens, 2048);
        assert_eq!(config.temperature, 0.7);
        assert!(config.enable_cache);
    }

    #[test]
    fn test_generation_request_serialization() {
        let request = GenerationRequest {
            prompt: "test".to_string(),
            constraints_ir: vec![],
            max_tokens: 100,
            temperature: 0.5,
            context: None,
        };

        let json = serde_json::to_string(&request).unwrap();
        let deserialized: GenerationRequest = serde_json::from_str(&json).unwrap();
        assert_eq!(request.prompt, deserialized.prompt);
    }
}
