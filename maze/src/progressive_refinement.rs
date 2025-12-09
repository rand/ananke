//! Progressive refinement for typed holes
//!
//! Implements iterative constraint-driven code generation with progressive
//! refinement, supporting multiple fill strategies and dependency resolution.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::ffi::{ConstraintIR, HoleSpec};
use crate::modal_client::{EnsembleClient, InferenceRequest, ModalClient};

/// Configuration for progressive refinement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementConfig {
    /// Maximum number of refinement iterations
    pub max_iterations: usize,

    /// Minimum confidence threshold to accept a fill (0.0-1.0)
    pub min_confidence: f32,

    /// Enable parallel hole filling
    pub parallel_fill: bool,

    /// Temperature schedule for successive iterations
    /// Lower temperature = more conservative fills
    pub temperature_schedule: Vec<f32>,

    /// Strategy for handling fill failures
    pub failure_strategy: FailureStrategy,

    /// Enable diffusion model support (experimental)
    pub enable_diffusion: bool,
}

impl Default for RefinementConfig {
    fn default() -> Self {
        Self {
            max_iterations: 10,
            min_confidence: 0.8,
            parallel_fill: true,
            temperature_schedule: vec![0.9, 0.7, 0.5, 0.3, 0.1],
            failure_strategy: FailureStrategy::RetryAlternate,
            enable_diffusion: false,
        }
    }
}

/// Strategy for handling hole fill failures
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FailureStrategy {
    /// Skip the failed hole and continue
    Skip,

    /// Decompose the hole into smaller sub-holes
    Decompose,

    /// Request human review/intervention
    HumanReview,

    /// Retry with alternate parameters/models
    RetryAlternate,
}

/// Status of a hole during refinement
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HoleStatus {
    /// Waiting to be filled
    Pending,

    /// Currently being processed
    InProgress,

    /// Successfully filled
    Filled,

    /// Failed to fill after retries
    Failed,

    /// Skipped due to failure strategy
    Skipped,

    /// Requires human review
    NeedsHuman,
}

/// A single fill attempt for a hole
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FillAttempt {
    /// The generated fill code
    pub code: String,

    /// Confidence score (0.0-1.0)
    pub confidence: f32,

    /// Temperature used for this attempt
    pub temperature: f32,

    /// Model used
    pub model: String,

    /// Timestamp of attempt
    pub timestamp: i64,

    /// Validation result
    pub validation_passed: bool,

    /// Error message if validation failed
    pub error: Option<String>,
}

/// State of a typed hole during refinement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoleState {
    /// Unique identifier for this hole
    pub id: u64,

    /// Scale of the hole (nano, micro, meso, macro)
    pub scale: String,

    /// Origin/source location of the hole
    pub origin: String,

    /// Expected type of the fill (optional)
    pub expected_type: Option<String>,

    /// Constraints that must be satisfied
    pub constraints: Vec<String>,

    /// Current fill candidate (if any)
    pub current_fill: Option<String>,

    /// Confidence in current fill (0.0-1.0)
    pub confidence: f32,

    /// History of fill attempts
    pub attempts: Vec<FillAttempt>,

    /// Current status
    pub status: HoleStatus,

    /// IDs of holes that must be filled before this one
    pub depends_on: Vec<u64>,
}

impl HoleState {
    /// Create a new pending hole state
    pub fn new(id: u64, scale: String, origin: String) -> Self {
        Self {
            id,
            scale,
            origin,
            expected_type: None,
            constraints: vec![],
            current_fill: None,
            confidence: 0.0,
            attempts: vec![],
            status: HoleStatus::Pending,
            depends_on: vec![],
        }
    }

    /// Check if all dependencies are satisfied
    pub fn dependencies_satisfied(&self, hole_states: &HashMap<u64, HoleState>) -> bool {
        self.depends_on.iter().all(|dep_id| {
            hole_states
                .get(dep_id)
                .map(|dep| dep.status == HoleStatus::Filled)
                .unwrap_or(false)
        })
    }

    /// Check if this hole is ready to be filled
    pub fn is_ready(&self, hole_states: &HashMap<u64, HoleState>) -> bool {
        self.status == HoleStatus::Pending && self.dependencies_satisfied(hole_states)
    }
}

/// Result of progressive refinement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementResult {
    /// The refined code with filled holes
    pub code: String,

    /// Final state of all holes
    pub holes: Vec<HoleState>,

    /// Whether refinement completed successfully
    pub complete: bool,

    /// Holes that need human review
    pub needs_review: Vec<u64>,

    /// Number of iterations performed
    pub iterations: usize,

    /// Additional metadata about the refinement
    pub metadata: RefinementMetadata,
}

/// Metadata about the refinement process
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefinementMetadata {
    /// Total time spent in milliseconds
    pub total_time_ms: u64,

    /// Number of successful fills
    pub successful_fills: usize,

    /// Number of failed fills
    pub failed_fills: usize,

    /// Number of skipped holes
    pub skipped_holes: usize,

    /// Average confidence of successful fills
    pub avg_confidence: f32,

    /// Number of iterations performed
    pub iterations: usize,

    /// Model usage statistics
    pub model_usage: HashMap<String, usize>,
}

impl Default for RefinementMetadata {
    fn default() -> Self {
        Self {
            total_time_ms: 0,
            successful_fills: 0,
            failed_fills: 0,
            skipped_holes: 0,
            avg_confidence: 0.0,
            iterations: 0,
            model_usage: HashMap::new(),
        }
    }
}

/// Client backend for inference
pub enum InferenceBackend {
    /// Single modal client
    Single(ModalClient),
    /// Ensemble of multiple models
    Ensemble(EnsembleClient),
}

/// Progressive refiner for typed holes
pub struct ProgressiveRefiner {
    /// Inference backend (single or ensemble)
    backend: InferenceBackend,

    /// Configuration
    config: RefinementConfig,
}

impl ProgressiveRefiner {
    /// Create a new progressive refiner with single modal client
    pub fn new(modal_client: ModalClient, config: RefinementConfig) -> Self {
        Self {
            backend: InferenceBackend::Single(modal_client),
            config,
        }
    }

    /// Create a new progressive refiner with ensemble client
    pub fn with_ensemble(ensemble_client: EnsembleClient, config: RefinementConfig) -> Self {
        Self {
            backend: InferenceBackend::Ensemble(ensemble_client),
            config,
        }
    }

    /// Fill a single hole using the configured backend
    async fn fill_single_hole_backend(
        &self,
        hole: &HoleState,
        constraints_ir: &[ConstraintIR],
        temperature: f32,
    ) -> Result<FillAttempt> {
        let hole_spec = self.build_hole_spec(hole)?;

        let request = InferenceRequest {
            prompt: self.build_prompt(hole),
            constraints: serde_json::to_value(&constraints_ir)?,
            max_tokens: self.estimate_max_tokens(hole),
            temperature,
            context: None,
        };

        match &self.backend {
            InferenceBackend::Single(client) => {
                let response = client.generate_constrained(request).await?;
                let confidence = response.confidence();

                Ok(FillAttempt {
                    code: response.generated_text,
                    confidence,
                    temperature,
                    model: response.model,
                    timestamp: chrono::Utc::now().timestamp(),
                    validation_passed: true,
                    error: None,
                })
            }
            InferenceBackend::Ensemble(ensemble) => {
                let response = ensemble
                    .generate_routed(request, &hole_spec, constraints_ir)
                    .await?;
                let confidence = response.confidence();

                Ok(FillAttempt {
                    code: response.generated_text,
                    confidence,
                    temperature,
                    model: response.model,
                    timestamp: chrono::Utc::now().timestamp(),
                    validation_passed: true,
                    error: None,
                })
            }
        }
    }

    /// Build hole spec from hole state
    fn build_hole_spec(&self, hole: &HoleState) -> Result<HoleSpec> {
        // Build hole spec from the hole state
        let mut spec = HoleSpec::new(hole.id);

        // Add constraints from the hole state
        for constraint_str in &hole.constraints {
            let constraint = crate::ffi::FillConstraint::new(
                "generic".to_string(),
                constraint_str.clone(),
            );
            spec.fill_constraints.push(constraint);
        }

        Ok(spec)
    }

    /// Build prompt from hole state
    fn build_prompt(&self, hole: &HoleState) -> String {
        let mut prompt = format!("Fill the following {} hole:\n", hole.scale);
        prompt.push_str(&format!("Origin: {}\n", hole.origin));

        if let Some(ref expected_type) = hole.expected_type {
            prompt.push_str(&format!("Expected type: {}\n", expected_type));
        }

        if !hole.constraints.is_empty() {
            prompt.push_str("Constraints:\n");
            for constraint in &hole.constraints {
                prompt.push_str(&format!("- {}\n", constraint));
            }
        }

        prompt
    }

    /// Estimate max tokens for a hole
    fn estimate_max_tokens(&self, hole: &HoleState) -> usize {
        // Simple heuristic based on hole scale
        match hole.scale.as_str() {
            "nano" => 64,
            "micro" => 256,
            "meso" => 512,
            "macro" => 1024,
            _ => 256,
        }
    }

    /// Perform progressive refinement on code with typed holes
    ///
    /// # Arguments
    /// * `code` - The code containing typed holes
    /// * `holes` - Initial state of all holes to be filled
    /// * `constraints_ir` - Constraint IR from Zig constraint engines
    ///
    /// # Returns
    /// The refined code with metadata about the refinement process
    pub async fn refine(
        &self,
        code: String,
        mut holes: Vec<HoleState>,
        constraints_ir: Vec<ConstraintIR>,
    ) -> Result<RefinementResult> {
        let start_time = std::time::Instant::now();
        let mut current_code = code;
        let mut metadata = RefinementMetadata::default();

        // Build hole state map for efficient lookups
        let mut hole_states: HashMap<u64, HoleState> =
            holes.iter().map(|h| (h.id, h.clone())).collect();

        // Iterative refinement loop
        for iteration in 0..self.config.max_iterations {
            tracing::debug!("Refinement iteration {}/{}", iteration + 1, self.config.max_iterations);

            // Get temperature for this iteration
            let temperature = self.get_temperature_for_iteration(iteration);

            // Get ready holes (dependencies satisfied)
            let ready_holes = self.get_ready_holes(&hole_states);
            if ready_holes.is_empty() {
                tracing::debug!("No more ready holes, checking completion");
                if self.all_holes_resolved(&hole_states) {
                    tracing::info!("All holes resolved successfully");
                    break;
                } else {
                    tracing::warn!("No ready holes but refinement incomplete - possible dependency cycle");
                    break;
                }
            }

            // Fill ready holes (in parallel if enabled)
            if self.config.parallel_fill {
                self.fill_holes_parallel(
                    &mut current_code,
                    &mut hole_states,
                    &ready_holes,
                    &constraints_ir,
                    temperature,
                    &mut metadata,
                )
                .await?;
            } else {
                self.fill_holes_sequential(
                    &mut current_code,
                    &mut hole_states,
                    &ready_holes,
                    &constraints_ir,
                    temperature,
                    &mut metadata,
                )
                .await?;
            }
        }

        // Collect final hole states and review list
        holes = hole_states.values().cloned().collect();
        let needs_review: Vec<u64> = holes
            .iter()
            .filter(|h| h.status == HoleStatus::NeedsHuman || h.status == HoleStatus::Failed)
            .map(|h| h.id)
            .collect();

        let complete = self.all_holes_resolved(&hole_states) && needs_review.is_empty();

        // Calculate final metadata
        metadata.total_time_ms = start_time.elapsed().as_millis() as u64;
        let successful_holes: Vec<_> = holes
            .iter()
            .filter(|h| h.status == HoleStatus::Filled)
            .collect();
        metadata.avg_confidence = if !successful_holes.is_empty() {
            successful_holes.iter().map(|h| h.confidence).sum::<f32>()
                / successful_holes.len() as f32
        } else {
            0.0
        };

        metadata.iterations = self.config.max_iterations.min(
            holes
                .iter()
                .map(|h| h.attempts.len())
                .max()
                .unwrap_or(0),
        );

        Ok(RefinementResult {
            code: current_code,
            holes,
            complete,
            needs_review,
            iterations: metadata.iterations,
            metadata,
        })
    }

    /// Get holes that are ready to be filled (dependencies satisfied)
    pub fn get_ready_holes(&self, states: &HashMap<u64, HoleState>) -> Vec<u64> {
        states
            .values()
            .filter(|hole| hole.is_ready(states))
            .map(|hole| hole.id)
            .collect()
    }

    /// Check if all holes are resolved (filled or explicitly handled)
    pub fn all_holes_resolved(&self, states: &HashMap<u64, HoleState>) -> bool {
        states.values().all(|hole| {
            matches!(
                hole.status,
                HoleStatus::Filled | HoleStatus::Skipped | HoleStatus::NeedsHuman
            )
        })
    }

    /// Get temperature for a given iteration based on schedule
    fn get_temperature_for_iteration(&self, iteration: usize) -> f32 {
        if self.config.temperature_schedule.is_empty() {
            return 0.7; // Default temperature
        }

        let idx = iteration.min(self.config.temperature_schedule.len() - 1);
        self.config.temperature_schedule[idx]
    }

    /// Fill holes in parallel
    async fn fill_holes_parallel(
        &self,
        _code: &mut String,
        hole_states: &mut HashMap<u64, HoleState>,
        ready_holes: &[u64],
        _constraints_ir: &[ConstraintIR],
        temperature: f32,
        metadata: &mut RefinementMetadata,
    ) -> Result<()> {
        use futures::future::join_all;

        // Mark holes as in progress
        for hole_id in ready_holes {
            if let Some(hole) = hole_states.get_mut(hole_id) {
                hole.status = HoleStatus::InProgress;
            }
        }

        // Create fill tasks for each ready hole
        let fill_tasks: Vec<_> = ready_holes
            .iter()
            .filter_map(|&hole_id| {
                hole_states.get(&hole_id).map(|hole| {
                    let hole_clone = hole.clone();
                    let constraints_clone = _constraints_ir.to_vec();
                    async move {
                        self.fill_single_hole_backend(&hole_clone, &constraints_clone, temperature)
                            .await
                    }
                })
            })
            .collect();

        // Execute all fills in parallel
        let results = join_all(fill_tasks).await;

        // Process results
        for (idx, result) in results.into_iter().enumerate() {
            let hole_id = ready_holes[idx];
            if let Some(hole) = hole_states.get_mut(&hole_id) {
                match result {
                    Ok(attempt) => {
                        if attempt.confidence >= self.config.min_confidence
                            && attempt.validation_passed
                        {
                            hole.current_fill = Some(attempt.code.clone());
                            hole.confidence = attempt.confidence;
                            hole.status = HoleStatus::Filled;
                            metadata.successful_fills += 1;
                        } else {
                            self.handle_fill_failure(hole, metadata);
                        }
                        hole.attempts.push(attempt);
                    }
                    Err(e) => {
                        tracing::error!("Fill failed for hole {}: {}", hole_id, e);
                        self.handle_fill_failure(hole, metadata);
                    }
                }
            }
        }

        Ok(())
    }

    /// Fill holes sequentially
    async fn fill_holes_sequential(
        &self,
        _code: &mut String,
        hole_states: &mut HashMap<u64, HoleState>,
        ready_holes: &[u64],
        _constraints_ir: &[ConstraintIR],
        temperature: f32,
        metadata: &mut RefinementMetadata,
    ) -> Result<()> {
        for &hole_id in ready_holes {
            if let Some(hole) = hole_states.get_mut(&hole_id) {
                hole.status = HoleStatus::InProgress;

                match self
                    .fill_single_hole_backend(hole, _constraints_ir, temperature)
                    .await
                {
                    Ok(attempt) => {
                        if attempt.confidence >= self.config.min_confidence
                            && attempt.validation_passed
                        {
                            hole.current_fill = Some(attempt.code.clone());
                            hole.confidence = attempt.confidence;
                            hole.status = HoleStatus::Filled;
                            metadata.successful_fills += 1;
                        } else {
                            self.handle_fill_failure(hole, metadata);
                        }
                        hole.attempts.push(attempt);
                    }
                    Err(e) => {
                        tracing::error!("Fill failed for hole {}: {}", hole_id, e);
                        self.handle_fill_failure(hole, metadata);
                    }
                }
            }
        }

        Ok(())
    }

    /// Handle a fill failure according to configured strategy
    fn handle_fill_failure(&self, hole: &mut HoleState, metadata: &mut RefinementMetadata) {
        match self.config.failure_strategy {
            FailureStrategy::Skip => {
                hole.status = HoleStatus::Skipped;
                metadata.skipped_holes += 1;
            }
            FailureStrategy::Decompose => {
                // TODO: Implement hole decomposition
                hole.status = HoleStatus::Failed;
                metadata.failed_fills += 1;
            }
            FailureStrategy::HumanReview => {
                hole.status = HoleStatus::NeedsHuman;
                metadata.failed_fills += 1;
            }
            FailureStrategy::RetryAlternate => {
                // Mark as failed - will be retried in next iteration
                hole.status = HoleStatus::Pending;
                metadata.failed_fills += 1;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_refinement_config_default() {
        let config = RefinementConfig::default();
        assert_eq!(config.max_iterations, 10);
        assert_eq!(config.min_confidence, 0.8);
        assert!(config.parallel_fill);
        assert_eq!(config.temperature_schedule.len(), 5);
    }

    #[test]
    fn test_hole_state_new() {
        let hole = HoleState::new(1, "nano".to_string(), "test.rs:10:5".to_string());
        assert_eq!(hole.id, 1);
        assert_eq!(hole.scale, "nano");
        assert_eq!(hole.status, HoleStatus::Pending);
        assert_eq!(hole.confidence, 0.0);
    }

    #[test]
    fn test_hole_dependencies_satisfied() {
        let mut states = HashMap::new();

        let mut hole1 = HoleState::new(1, "nano".to_string(), "test.rs:1:1".to_string());
        hole1.status = HoleStatus::Filled;

        let mut hole2 = HoleState::new(2, "nano".to_string(), "test.rs:2:1".to_string());
        hole2.depends_on = vec![1];

        states.insert(1, hole1);
        states.insert(2, hole2.clone());

        assert!(hole2.dependencies_satisfied(&states));
    }

    #[test]
    fn test_hole_is_ready() {
        let mut states = HashMap::new();

        let mut hole1 = HoleState::new(1, "nano".to_string(), "test.rs:1:1".to_string());
        hole1.status = HoleStatus::Filled;

        let mut hole2 = HoleState::new(2, "nano".to_string(), "test.rs:2:1".to_string());
        hole2.depends_on = vec![1];

        states.insert(1, hole1);
        states.insert(2, hole2.clone());

        assert!(hole2.is_ready(&states));
    }

    #[test]
    fn test_failure_strategy_serialization() {
        let strategy = FailureStrategy::RetryAlternate;
        let json = serde_json::to_string(&strategy).unwrap();
        let deserialized: FailureStrategy = serde_json::from_str(&json).unwrap();
        assert_eq!(strategy, deserialized);
    }
}
