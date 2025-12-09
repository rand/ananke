//! Strategy statistics for adaptive selection
//!
//! Tracks success rates by hole scale, origin, and strategy combination.

use crate::telemetry::FillOutcome;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Key for strategy statistics
#[derive(Debug, Clone, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct StatsKey {
    /// Hole scale (expression, statement, block, function, module, specification)
    pub hole_scale: String,

    /// Hole origin (user_marked, generation_limit, etc.)
    pub hole_origin: String,

    /// Resolution strategy
    pub strategy: String,
}

impl StatsKey {
    pub fn new(scale: &str, origin: &str, strategy: &str) -> Self {
        Self {
            hole_scale: scale.to_string(),
            hole_origin: origin.to_string(),
            strategy: strategy.to_string(),
        }
    }
}

/// Statistics for a single strategy combination
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrategyStats {
    /// Total attempts
    pub attempts: u64,

    /// Successful fills (auto-accepted or user-accepted)
    pub successes: u64,

    /// User-accepted fills
    pub user_accepted: u64,

    /// User-rejected fills
    pub user_rejected: u64,

    /// Average confidence score
    pub avg_confidence: f64,

    /// Average time in milliseconds
    pub avg_time_ms: f64,

    /// Sum of confidence scores (for running average)
    confidence_sum: f64,

    /// Sum of times (for running average)
    time_sum: f64,

    /// Last update timestamp
    pub last_updated: u64,
}

impl Default for StrategyStats {
    fn default() -> Self {
        Self {
            attempts: 0,
            successes: 0,
            user_accepted: 0,
            user_rejected: 0,
            avg_confidence: 0.0,
            avg_time_ms: 0.0,
            confidence_sum: 0.0,
            time_sum: 0.0,
            last_updated: 0,
        }
    }
}

impl StrategyStats {
    /// Update stats with a new outcome
    pub fn update(&mut self, outcome: &FillOutcome) {
        self.attempts += 1;

        if outcome.success {
            self.successes += 1;
        }

        if let Some(accepted) = outcome.user_accepted {
            if accepted {
                self.user_accepted += 1;
            } else {
                self.user_rejected += 1;
            }
        }

        self.confidence_sum += outcome.confidence;
        self.time_sum += outcome.time_ms as f64;

        self.avg_confidence = self.confidence_sum / self.attempts as f64;
        self.avg_time_ms = self.time_sum / self.attempts as f64;

        self.last_updated = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
    }

    /// Calculate success rate
    pub fn success_rate(&self) -> f64 {
        if self.attempts == 0 {
            return 0.0;
        }
        self.successes as f64 / self.attempts as f64
    }

    /// Calculate user acceptance rate
    pub fn acceptance_rate(&self) -> f64 {
        let total_feedback = self.user_accepted + self.user_rejected;
        if total_feedback == 0 {
            return 0.5; // No feedback yet, assume neutral
        }
        self.user_accepted as f64 / total_feedback as f64
    }

    /// Calculate combined score (success rate weighted by acceptance)
    pub fn combined_score(&self) -> f64 {
        let success = self.success_rate();
        let acceptance = self.acceptance_rate();

        // Weight success more heavily if we have user feedback
        if self.user_accepted + self.user_rejected > 0 {
            success * 0.4 + acceptance * 0.6
        } else {
            success
        }
    }

    /// Apply time decay to statistics
    pub fn apply_decay(&mut self, decay_factor: f64) {
        self.successes = ((self.successes as f64) * decay_factor) as u64;
        self.attempts = ((self.attempts as f64) * decay_factor) as u64;
        self.user_accepted = ((self.user_accepted as f64) * decay_factor) as u64;
        self.user_rejected = ((self.user_rejected as f64) * decay_factor) as u64;
    }
}

/// Collection of strategy statistics
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct StrategyStatsStore {
    /// Stats by key
    pub stats: HashMap<StatsKey, StrategyStats>,

    /// Global stats (all strategies combined)
    pub global: StrategyStats,

    /// Total outcomes processed
    pub total_outcomes: u64,
}

impl StrategyStatsStore {
    /// Create new stats store
    pub fn new() -> Self {
        Self::default()
    }

    /// Update stats with a fill outcome
    pub fn record(&mut self, outcome: &FillOutcome) {
        let key = StatsKey::new(
            &outcome.hole_scale,
            &outcome.hole_origin,
            &outcome.strategy,
        );

        self.stats
            .entry(key)
            .or_default()
            .update(outcome);

        self.global.update(outcome);
        self.total_outcomes += 1;
    }

    /// Get stats for a specific key
    pub fn get(&self, key: &StatsKey) -> Option<&StrategyStats> {
        self.stats.get(key)
    }

    /// Get stats for a scale and origin (all strategies)
    pub fn get_for_hole(&self, scale: &str, origin: &str) -> Vec<(&String, &StrategyStats)> {
        self.stats
            .iter()
            .filter(|(k, _)| k.hole_scale == scale && k.hole_origin == origin)
            .map(|(k, v)| (&k.strategy, v))
            .collect()
    }

    /// Get best strategy for a hole type
    pub fn best_strategy_for(&self, scale: &str, origin: &str) -> Option<String> {
        let candidates = self.get_for_hole(scale, origin);

        if candidates.is_empty() {
            return None;
        }

        // Find strategy with highest combined score
        candidates
            .into_iter()
            .filter(|(_, stats)| stats.attempts >= 5) // Minimum sample size
            .max_by(|(_, a), (_, b)| {
                a.combined_score()
                    .partial_cmp(&b.combined_score())
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .map(|(strategy, _)| strategy.clone())
    }

    /// Get strategy ranking for a hole type
    pub fn strategy_ranking(&self, scale: &str, origin: &str) -> Vec<(String, f64)> {
        let mut ranking: Vec<_> = self
            .get_for_hole(scale, origin)
            .into_iter()
            .map(|(strategy, stats)| (strategy.clone(), stats.combined_score()))
            .collect();

        ranking.sort_by(|(_, a), (_, b)| b.partial_cmp(a).unwrap_or(std::cmp::Ordering::Equal));
        ranking
    }

    /// Apply decay to all stats (for aging old data)
    pub fn apply_global_decay(&mut self, decay_factor: f64) {
        for stats in self.stats.values_mut() {
            stats.apply_decay(decay_factor);
        }
        self.global.apply_decay(decay_factor);
    }

    /// Check if we have enough data for a hole type
    pub fn has_enough_data(&self, scale: &str, origin: &str, min_samples: u64) -> bool {
        self.get_for_hole(scale, origin)
            .iter()
            .any(|(_, stats)| stats.attempts >= min_samples)
    }

    /// Get summary statistics
    pub fn summary(&self) -> StatsSummary {
        StatsSummary {
            total_outcomes: self.total_outcomes,
            unique_combinations: self.stats.len(),
            global_success_rate: self.global.success_rate(),
            global_acceptance_rate: self.global.acceptance_rate(),
            avg_confidence: self.global.avg_confidence,
            avg_time_ms: self.global.avg_time_ms,
        }
    }
}

/// Summary of statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatsSummary {
    pub total_outcomes: u64,
    pub unique_combinations: usize,
    pub global_success_rate: f64,
    pub global_acceptance_rate: f64,
    pub avg_confidence: f64,
    pub avg_time_ms: f64,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_outcome(scale: &str, origin: &str, strategy: &str, success: bool) -> FillOutcome {
        let mut outcome = FillOutcome::new(
            "hole-1".to_string(),
            scale.to_string(),
            origin.to_string(),
            strategy.to_string(),
        );
        outcome.success = success;
        outcome.confidence = if success { 0.9 } else { 0.3 };
        outcome.time_ms = 100;
        outcome
    }

    #[test]
    fn test_strategy_stats() {
        let mut stats = StrategyStats::default();

        let outcome1 = make_outcome("statement", "user_marked", "llm_complete", true);
        let outcome2 = make_outcome("statement", "user_marked", "llm_complete", true);
        let outcome3 = make_outcome("statement", "user_marked", "llm_complete", false);

        stats.update(&outcome1);
        stats.update(&outcome2);
        stats.update(&outcome3);

        assert_eq!(stats.attempts, 3);
        assert_eq!(stats.successes, 2);
        assert!((stats.success_rate() - 0.666).abs() < 0.01);
    }

    #[test]
    fn test_stats_store() {
        let mut store = StrategyStatsStore::new();

        // LLM: 10 successes, 3 failures = 77% success rate
        for _ in 0..10 {
            store.record(&make_outcome("statement", "user_marked", "llm_complete", true));
        }
        for _ in 0..3 {
            store.record(&make_outcome("statement", "user_marked", "llm_complete", false));
        }

        // Decompose: 3 successes, 2 failures = 60% success rate (5 samples total to hit minimum)
        for _ in 0..3 {
            store.record(&make_outcome("statement", "user_marked", "decompose", true));
        }
        for _ in 0..2 {
            store.record(&make_outcome("statement", "user_marked", "decompose", false));
        }

        // LLM should win with 77% vs 60%
        let best = store.best_strategy_for("statement", "user_marked");
        assert_eq!(best, Some("llm_complete".to_string()));

        let ranking = store.strategy_ranking("statement", "user_marked");
        assert_eq!(ranking.len(), 2);
    }

    #[test]
    fn test_decay() {
        let mut stats = StrategyStats::default();

        for _ in 0..100 {
            let outcome = make_outcome("statement", "user_marked", "llm_complete", true);
            stats.update(&outcome);
        }

        assert_eq!(stats.attempts, 100);

        stats.apply_decay(0.5);
        assert_eq!(stats.attempts, 50);
    }
}
