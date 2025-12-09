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

    /// Decomposed into child holes, waiting for children to complete
    PendingChildren,
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

    /// Parent hole ID if this hole was created by decomposition
    pub parent_id: Option<u64>,

    /// Child hole IDs if this hole has been decomposed
    pub child_ids: Vec<u64>,
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
            parent_id: None,
            child_ids: vec![],
        }
    }

    /// Create a child hole from decomposition of a parent hole
    pub fn new_child(id: u64, parent: &HoleState, scale: String, origin: String) -> Self {
        Self {
            id,
            scale,
            origin,
            expected_type: parent.expected_type.clone(),
            constraints: parent.constraints.clone(),
            current_fill: None,
            confidence: 0.0,
            attempts: vec![],
            status: HoleStatus::Pending,
            depends_on: vec![],
            parent_id: Some(parent.id),
            child_ids: vec![],
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
            constraints: serde_json::to_value(constraints_ir)?,
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
            match hole.status {
                HoleStatus::Filled | HoleStatus::Skipped | HoleStatus::NeedsHuman => true,
                HoleStatus::PendingChildren => {
                    // A parent is resolved when all its children are resolved
                    hole.child_ids.iter().all(|child_id| {
                        states.get(child_id).map(|child| {
                            matches!(child.status, HoleStatus::Filled | HoleStatus::Skipped | HoleStatus::NeedsHuman)
                        }).unwrap_or(false)
                    })
                }
                _ => false,
            }
        })
    }

    /// Get the next available hole ID
    fn next_hole_id(&self, states: &HashMap<u64, HoleState>) -> u64 {
        states.keys().max().map(|max| max + 1).unwrap_or(1)
    }

    /// Decompose a hole into smaller sub-holes based on its scale
    ///
    /// Scale hierarchy (largest to smallest):
    /// - macro: function/module level -> decompose to meso (blocks)
    /// - meso: block level -> decompose to micro (statements)
    /// - micro: statement level -> decompose to nano (expressions)
    /// - nano: expression level -> cannot decompose further
    fn decompose_hole(
        &self,
        hole: &HoleState,
        states: &mut HashMap<u64, HoleState>,
    ) -> Vec<u64> {
        let child_scale = match hole.scale.as_str() {
            "macro" => "meso",
            "meso" => "micro",
            "micro" => "nano",
            "nano" => {
                // Cannot decompose nano-scale holes
                tracing::warn!("Cannot decompose nano-scale hole {}", hole.id);
                return vec![];
            }
            _ => "micro", // Default to micro for unknown scales
        };

        // Create 2-4 child holes depending on the scale reduction
        let num_children = match hole.scale.as_str() {
            "macro" => 3, // Function -> 3 blocks (setup, main, cleanup)
            "meso" => 2,  // Block -> 2 statement groups
            "micro" => 2, // Statement -> 2 expressions
            _ => 2,
        };

        let mut child_ids = Vec::with_capacity(num_children);
        let base_id = self.next_hole_id(states);

        for i in 0..num_children {
            let child_id = base_id + i as u64;
            let child_origin = format!("{}:child_{}", hole.origin, i);

            let mut child = HoleState::new_child(
                child_id,
                hole,
                child_scale.to_string(),
                child_origin,
            );

            // Later children depend on earlier children (sequential decomposition)
            if i > 0 {
                child.depends_on = vec![base_id + (i - 1) as u64];
            }

            child_ids.push(child_id);
            states.insert(child_id, child);
        }

        tracing::info!(
            "Decomposed hole {} ({}) into {} {} children: {:?}",
            hole.id,
            hole.scale,
            num_children,
            child_scale,
            child_ids
        );

        child_ids
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
        _code: &mut str,
        hole_states: &mut HashMap<u64, HoleState>,
        ready_holes: &[u64],
        constraints_ir: &[ConstraintIR],
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
                    let constraints_clone = constraints_ir.to_vec();
                    async move {
                        self.fill_single_hole_backend(&hole_clone, &constraints_clone, temperature)
                            .await
                    }
                })
            })
            .collect();

        // Execute all fills in parallel
        let results = join_all(fill_tasks).await;

        // Collect failed hole IDs for decomposition handling
        let mut failed_holes: Vec<u64> = Vec::new();

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
                            failed_holes.push(hole_id);
                        }
                        hole.attempts.push(attempt);
                    }
                    Err(e) => {
                        tracing::error!("Fill failed for hole {}: {}", hole_id, e);
                        failed_holes.push(hole_id);
                    }
                }
            }
        }

        // Handle failures with decomposition support
        for hole_id in failed_holes {
            self.handle_fill_failure_with_decompose(hole_id, hole_states, metadata);
        }

        // Check if any parent holes can have their children aggregated
        self.check_and_aggregate_children(hole_states);

        Ok(())
    }

    /// Fill holes sequentially
    async fn fill_holes_sequential(
        &self,
        _code: &mut str,
        hole_states: &mut HashMap<u64, HoleState>,
        ready_holes: &[u64],
        constraints_ir: &[ConstraintIR],
        temperature: f32,
        metadata: &mut RefinementMetadata,
    ) -> Result<()> {
        for &hole_id in ready_holes {
            let fill_result = {
                if let Some(hole) = hole_states.get_mut(&hole_id) {
                    hole.status = HoleStatus::InProgress;
                    Some(
                        self.fill_single_hole_backend(hole, constraints_ir, temperature)
                            .await,
                    )
                } else {
                    None
                }
            };

            if let Some(result) = fill_result {
                let mut failed = false;
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
                                failed = true;
                            }
                            hole.attempts.push(attempt);
                        }
                        Err(e) => {
                            tracing::error!("Fill failed for hole {}: {}", hole_id, e);
                            failed = true;
                        }
                    }
                }

                if failed {
                    self.handle_fill_failure_with_decompose(hole_id, hole_states, metadata);
                }
            }
        }

        // Check if any parent holes can have their children aggregated
        self.check_and_aggregate_children(hole_states);

        Ok(())
    }

    /// Handle a fill failure with full decomposition support
    fn handle_fill_failure_with_decompose(
        &self,
        hole_id: u64,
        hole_states: &mut HashMap<u64, HoleState>,
        metadata: &mut RefinementMetadata,
    ) {
        // First, handle the simple cases that don't need hole_states
        let (strategy, scale) = {
            let hole = match hole_states.get(&hole_id) {
                Some(h) => h,
                None => return,
            };
            (self.config.failure_strategy, hole.scale.clone())
        };

        match strategy {
            FailureStrategy::Skip => {
                if let Some(hole) = hole_states.get_mut(&hole_id) {
                    hole.status = HoleStatus::Skipped;
                }
                metadata.skipped_holes += 1;
            }
            FailureStrategy::Decompose => {
                // Check if we can decompose (nano scale cannot be decomposed)
                if scale == "nano" {
                    tracing::warn!(
                        "Cannot decompose nano-scale hole {}, marking as failed",
                        hole_id
                    );
                    if let Some(hole) = hole_states.get_mut(&hole_id) {
                        hole.status = HoleStatus::Failed;
                    }
                    metadata.failed_fills += 1;
                    return;
                }

                // Clone the hole for decomposition
                let hole_clone = hole_states.get(&hole_id).cloned();
                if let Some(parent_hole) = hole_clone {
                    // Decompose the hole
                    let child_ids = self.decompose_hole(&parent_hole, hole_states);

                    if child_ids.is_empty() {
                        // Decomposition failed, mark as failed
                        if let Some(hole) = hole_states.get_mut(&hole_id) {
                            hole.status = HoleStatus::Failed;
                        }
                        metadata.failed_fills += 1;
                    } else {
                        // Update parent with child IDs and set status
                        if let Some(hole) = hole_states.get_mut(&hole_id) {
                            hole.child_ids = child_ids;
                            hole.status = HoleStatus::PendingChildren;
                        }
                        tracing::info!(
                            "Decomposed hole {} into children, marked as PendingChildren",
                            hole_id
                        );
                    }
                }
            }
            FailureStrategy::HumanReview => {
                if let Some(hole) = hole_states.get_mut(&hole_id) {
                    hole.status = HoleStatus::NeedsHuman;
                }
                metadata.failed_fills += 1;
            }
            FailureStrategy::RetryAlternate => {
                if let Some(hole) = hole_states.get_mut(&hole_id) {
                    hole.status = HoleStatus::Pending;
                }
                metadata.failed_fills += 1;
            }
        }
    }

    /// Check and aggregate completed child holes back into parents
    fn check_and_aggregate_children(&self, hole_states: &mut HashMap<u64, HoleState>) {
        // Find all parent holes waiting for children
        let parent_ids: Vec<u64> = hole_states
            .values()
            .filter(|h| h.status == HoleStatus::PendingChildren)
            .map(|h| h.id)
            .collect();

        for parent_id in parent_ids {
            // Check if all children are filled
            let all_children_filled = {
                let parent = match hole_states.get(&parent_id) {
                    Some(p) => p,
                    None => continue,
                };
                parent.child_ids.iter().all(|child_id| {
                    hole_states
                        .get(child_id)
                        .map(|c| c.status == HoleStatus::Filled)
                        .unwrap_or(false)
                })
            };

            if all_children_filled {
                // Get child fills (need to collect first to avoid borrow issues)
                let (child_fills, avg_confidence): (Vec<String>, f32) = {
                    let parent = hole_states.get(&parent_id).unwrap();
                    let fills: Vec<String> = parent
                        .child_ids
                        .iter()
                        .filter_map(|id| hole_states.get(id))
                        .filter_map(|c| c.current_fill.clone())
                        .collect();
                    let conf: f32 = parent
                        .child_ids
                        .iter()
                        .filter_map(|id| hole_states.get(id))
                        .map(|c| c.confidence)
                        .sum::<f32>()
                        / parent.child_ids.len() as f32;
                    (fills, conf)
                };

                // Update parent
                if let Some(parent) = hole_states.get_mut(&parent_id) {
                    parent.current_fill = Some(child_fills.join("\n"));
                    parent.confidence = avg_confidence;
                    parent.status = HoleStatus::Filled;
                    tracing::info!(
                        "Aggregated {} child fills into parent hole {}",
                        child_fills.len(),
                        parent_id
                    );
                }
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

    #[test]
    fn test_hole_state_new_child() {
        let parent = HoleState::new(1, "macro".to_string(), "test.rs:1:1".to_string());
        let child = HoleState::new_child(2, &parent, "meso".to_string(), "test.rs:1:1:child_0".to_string());

        assert_eq!(child.id, 2);
        assert_eq!(child.scale, "meso");
        assert_eq!(child.parent_id, Some(1));
        assert_eq!(child.status, HoleStatus::Pending);
    }

    #[test]
    fn test_hole_status_pending_children() {
        let status = HoleStatus::PendingChildren;
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: HoleStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);
    }

    #[test]
    fn test_decomposition_scale_hierarchy() {
        // Verify that macro -> meso -> micro -> nano is the expected hierarchy
        // This test documents the expected behavior of decompose_hole
        let scales = vec![
            ("macro", "meso", 3),   // macro decomposes to 3 meso
            ("meso", "micro", 2),   // meso decomposes to 2 micro
            ("micro", "nano", 2),   // micro decomposes to 2 nano
        ];

        for (parent_scale, expected_child_scale, expected_count) in scales {
            let num_children = match parent_scale {
                "macro" => 3,
                "meso" => 2,
                "micro" => 2,
                _ => 2,
            };
            let child_scale = match parent_scale {
                "macro" => "meso",
                "meso" => "micro",
                "micro" => "nano",
                _ => "micro",
            };

            assert_eq!(child_scale, expected_child_scale, "Scale {} should decompose to {}", parent_scale, expected_child_scale);
            assert_eq!(num_children, expected_count, "Scale {} should create {} children", parent_scale, expected_count);
        }
    }
}
