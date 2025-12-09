//! Adaptive strategy selection using epsilon-greedy algorithm
//!
//! Learns optimal strategies over time based on fill outcomes.

use crate::strategy_stats::{StatsKey, StrategyStatsStore};
use crate::telemetry::{FillOutcome, TelemetryStore};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Available resolution strategies
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Strategy {
    LlmComplete,
    HumanRequired,
    ExampleAdapt,
    Decompose,
    Skip,
    Template,
    DiffusionRefine,
}

impl Strategy {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::LlmComplete => "llm_complete",
            Self::HumanRequired => "human_required",
            Self::ExampleAdapt => "example_adapt",
            Self::Decompose => "decompose",
            Self::Skip => "skip",
            Self::Template => "template",
            Self::DiffusionRefine => "diffusion_refine",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "llm_complete" => Some(Self::LlmComplete),
            "human_required" => Some(Self::HumanRequired),
            "example_adapt" => Some(Self::ExampleAdapt),
            "decompose" => Some(Self::Decompose),
            "skip" => Some(Self::Skip),
            "template" => Some(Self::Template),
            "diffusion_refine" => Some(Self::DiffusionRefine),
            _ => None,
        }
    }

    /// All strategies that can be auto-selected
    pub fn auto_selectable() -> Vec<Self> {
        vec![
            Self::LlmComplete,
            Self::ExampleAdapt,
            Self::Decompose,
            Self::Template,
            Self::DiffusionRefine,
        ]
    }
}

/// Configuration for adaptive selection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdaptiveConfig {
    /// Exploration rate (probability of trying random strategy)
    pub exploration_rate: f64,

    /// Minimum samples before using learned preferences
    pub min_samples: u64,

    /// Decay factor for old statistics (applied periodically)
    pub decay_factor: f64,

    /// Days before applying decay
    pub decay_interval_days: u64,

    /// Enable logging of selection decisions
    pub log_decisions: bool,
}

impl Default for AdaptiveConfig {
    fn default() -> Self {
        Self {
            exploration_rate: 0.1, // 10% exploration
            min_samples: 50,
            decay_factor: 0.9,
            decay_interval_days: 7,
            log_decisions: false,
        }
    }
}

/// Decision record for debugging/analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SelectionDecision {
    pub hole_scale: String,
    pub hole_origin: String,
    pub selected_strategy: String,
    pub reason: SelectionReason,
    pub alternatives: Vec<(String, f64)>,
    pub was_exploration: bool,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SelectionReason {
    /// Used learned statistics
    Learned { score: f64 },
    /// Exploration (random selection)
    Exploration,
    /// Not enough data, using default
    ColdStart,
    /// Static heuristic fallback
    Heuristic,
}

/// Adaptive strategy selector
pub struct AdaptiveStrategySelector {
    /// Statistics store
    stats: StrategyStatsStore,

    /// Telemetry store
    telemetry: TelemetryStore,

    /// Configuration
    config: AdaptiveConfig,

    /// Recent decisions (for debugging)
    recent_decisions: Vec<SelectionDecision>,

    /// RNG for exploration
    rng: rand::rngs::ThreadRng,
}

impl AdaptiveStrategySelector {
    /// Create new adaptive selector
    pub fn new(data_dir: PathBuf, config: AdaptiveConfig) -> std::io::Result<Self> {
        let telemetry = TelemetryStore::new(data_dir)?;

        Ok(Self {
            stats: StrategyStatsStore::new(),
            telemetry,
            config,
            recent_decisions: Vec::new(),
            rng: rand::thread_rng(),
        })
    }

    /// Create with default configuration
    pub fn default_config(data_dir: PathBuf) -> std::io::Result<Self> {
        Self::new(data_dir, AdaptiveConfig::default())
    }

    /// Select strategy for a hole
    pub fn select(&mut self, scale: &str, origin: &str) -> Strategy {
        let decision = self.make_decision(scale, origin);
        let strategy = Strategy::from_str(&decision.selected_strategy)
            .unwrap_or(Strategy::LlmComplete);

        if self.config.log_decisions {
            self.recent_decisions.push(decision);
            if self.recent_decisions.len() > 100 {
                self.recent_decisions.remove(0);
            }
        }

        strategy
    }

    /// Make selection decision with full details
    fn make_decision(&mut self, scale: &str, origin: &str) -> SelectionDecision {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Check if we should explore
        let explore = self.rng.gen::<f64>() < self.config.exploration_rate;

        if explore {
            let strategies = Strategy::auto_selectable();
            let idx = self.rng.gen_range(0..strategies.len());
            let selected = strategies[idx];

            return SelectionDecision {
                hole_scale: scale.to_string(),
                hole_origin: origin.to_string(),
                selected_strategy: selected.as_str().to_string(),
                reason: SelectionReason::Exploration,
                alternatives: vec![],
                was_exploration: true,
                timestamp,
            };
        }

        // Check if we have enough data
        if !self.stats.has_enough_data(scale, origin, self.config.min_samples) {
            let strategy = self.heuristic_select(scale, origin);

            return SelectionDecision {
                hole_scale: scale.to_string(),
                hole_origin: origin.to_string(),
                selected_strategy: strategy.as_str().to_string(),
                reason: SelectionReason::ColdStart,
                alternatives: vec![],
                was_exploration: false,
                timestamp,
            };
        }

        // Use learned statistics
        let ranking = self.stats.strategy_ranking(scale, origin);

        if let Some((best_strategy, score)) = ranking.first() {
            SelectionDecision {
                hole_scale: scale.to_string(),
                hole_origin: origin.to_string(),
                selected_strategy: best_strategy.clone(),
                reason: SelectionReason::Learned { score: *score },
                alternatives: ranking.clone(),
                was_exploration: false,
                timestamp,
            }
        } else {
            let strategy = self.heuristic_select(scale, origin);

            SelectionDecision {
                hole_scale: scale.to_string(),
                hole_origin: origin.to_string(),
                selected_strategy: strategy.as_str().to_string(),
                reason: SelectionReason::Heuristic,
                alternatives: vec![],
                was_exploration: false,
                timestamp,
            }
        }
    }

    /// Static heuristic for cold start
    fn heuristic_select(&self, scale: &str, origin: &str) -> Strategy {
        // Default heuristics based on hole characteristics
        match (scale, origin) {
            // Large holes should be decomposed
            ("specification", _) | ("module", _) => Strategy::Decompose,

            // User-marked holes likely need LLM
            (_, "user_marked") => Strategy::LlmComplete,

            // Constraint conflicts might need human review
            (_, "constraint_conflict") => Strategy::HumanRequired,

            // Structural holes can often use templates
            (_, "structural") => Strategy::Template,

            // Type inference failures need LLM
            (_, "type_inference_failure") => Strategy::LlmComplete,

            // Small uncertain holes try LLM first
            ("expression", "uncertainty") => Strategy::LlmComplete,

            // Default to LLM
            _ => Strategy::LlmComplete,
        }
    }

    /// Record fill outcome
    pub fn record_outcome(&mut self, outcome: FillOutcome) -> std::io::Result<()> {
        self.stats.record(&outcome);
        self.telemetry.record(outcome)
    }

    /// Load historical data
    pub fn load_history(&mut self) -> std::io::Result<()> {
        let outcomes = self.telemetry.load_outcomes(None)?;
        for outcome in outcomes {
            self.stats.record(&outcome);
        }
        Ok(())
    }

    /// Get statistics summary
    pub fn get_stats_summary(&self) -> crate::strategy_stats::StatsSummary {
        self.stats.summary()
    }

    /// Get recent decisions
    pub fn get_recent_decisions(&self) -> &[SelectionDecision] {
        &self.recent_decisions
    }

    /// Apply decay to old statistics
    pub fn apply_decay(&mut self) {
        self.stats.apply_global_decay(self.config.decay_factor);
    }

    /// Clear all learned data
    pub fn reset(&mut self) -> std::io::Result<()> {
        self.stats = StrategyStatsStore::new();
        self.telemetry.clear_all()?;
        self.recent_decisions.clear();
        Ok(())
    }

    /// Export learned data for analysis
    pub fn export_data(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(&self.stats)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn create_selector(temp_dir: &TempDir) -> AdaptiveStrategySelector {
        AdaptiveStrategySelector::new(
            temp_dir.path().to_path_buf(),
            AdaptiveConfig {
                exploration_rate: 0.0, // Disable exploration for deterministic tests
                min_samples: 5,
                ..Default::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn test_cold_start_heuristics() {
        let temp_dir = TempDir::new().unwrap();
        let mut selector = create_selector(&temp_dir);

        // Large holes should decompose
        let strategy = selector.select("specification", "user_marked");
        assert_eq!(strategy, Strategy::Decompose);

        // Constraint conflicts need human
        let strategy = selector.select("statement", "constraint_conflict");
        assert_eq!(strategy, Strategy::HumanRequired);
    }

    #[test]
    fn test_learned_selection() {
        let temp_dir = TempDir::new().unwrap();
        let mut selector = create_selector(&temp_dir);

        // Train on successful LLM outcomes
        for i in 0..10 {
            let mut outcome = FillOutcome::new(
                format!("hole-{}", i),
                "statement".to_string(),
                "user_marked".to_string(),
                "llm_complete".to_string(),
            );
            outcome.success = true;
            outcome.confidence = 0.9;
            selector.record_outcome(outcome).unwrap();
        }

        // Train on less successful decompose outcomes
        for i in 0..5 {
            let mut outcome = FillOutcome::new(
                format!("hole-decompose-{}", i),
                "statement".to_string(),
                "user_marked".to_string(),
                "decompose".to_string(),
            );
            outcome.success = i < 2; // 40% success
            outcome.confidence = 0.5;
            selector.record_outcome(outcome).unwrap();
        }

        // Should prefer LLM based on learned data
        let strategy = selector.select("statement", "user_marked");
        assert_eq!(strategy, Strategy::LlmComplete);
    }

    #[test]
    fn test_exploration() {
        let temp_dir = TempDir::new().unwrap();
        let mut selector = AdaptiveStrategySelector::new(
            temp_dir.path().to_path_buf(),
            AdaptiveConfig {
                exploration_rate: 1.0, // Always explore
                ..Default::default()
            },
        )
        .unwrap();

        // With 100% exploration, we should get random strategies
        let mut strategies = std::collections::HashSet::new();
        for _ in 0..100 {
            let strategy = selector.select("statement", "user_marked");
            strategies.insert(strategy);
        }

        // Should have explored multiple strategies
        assert!(strategies.len() > 1);
    }
}
