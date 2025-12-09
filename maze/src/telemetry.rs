//! Local telemetry for tracking fill outcomes
//!
//! Privacy-first design: all data stored locally, no external transmission.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

/// Outcome of a fill attempt
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FillOutcome {
    /// Unique outcome ID
    pub id: String,

    /// Hole ID that was filled
    pub hole_id: String,

    /// Scale of the hole
    pub hole_scale: String,

    /// Origin of the hole
    pub hole_origin: String,

    /// Strategy used for fill
    pub strategy: String,

    /// Model used (if applicable)
    pub model: Option<String>,

    /// Whether fill was successful
    pub success: bool,

    /// Confidence score of the fill
    pub confidence: f64,

    /// Whether user accepted the fill
    pub user_accepted: Option<bool>,

    /// Reason for rejection (if rejected)
    pub rejection_reason: Option<String>,

    /// Time taken in milliseconds
    pub time_ms: u64,

    /// Number of constraints satisfied
    pub constraints_satisfied: usize,

    /// Number of constraints violated
    pub constraints_violated: usize,

    /// Timestamp of the outcome
    pub timestamp: u64,

    /// Additional metadata
    pub metadata: HashMap<String, String>,
}

impl FillOutcome {
    /// Create a new fill outcome
    pub fn new(
        hole_id: String,
        hole_scale: String,
        hole_origin: String,
        strategy: String,
    ) -> Self {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Self {
            id: format!("outcome-{}-{}", hole_id, timestamp),
            hole_id,
            hole_scale,
            hole_origin,
            strategy,
            model: None,
            success: false,
            confidence: 0.0,
            user_accepted: None,
            rejection_reason: None,
            time_ms: 0,
            constraints_satisfied: 0,
            constraints_violated: 0,
            timestamp,
            metadata: HashMap::new(),
        }
    }

    /// Mark as successful
    pub fn with_success(mut self, confidence: f64) -> Self {
        self.success = true;
        self.confidence = confidence;
        self
    }

    /// Mark as failed
    pub fn with_failure(mut self, reason: &str) -> Self {
        self.success = false;
        self.rejection_reason = Some(reason.to_string());
        self
    }

    /// Set model used
    pub fn with_model(mut self, model: &str) -> Self {
        self.model = Some(model.to_string());
        self
    }

    /// Set timing
    pub fn with_time(mut self, time_ms: u64) -> Self {
        self.time_ms = time_ms;
        self
    }

    /// Set constraint results
    pub fn with_constraints(mut self, satisfied: usize, violated: usize) -> Self {
        self.constraints_satisfied = satisfied;
        self.constraints_violated = violated;
        self
    }

    /// Record user feedback
    pub fn with_user_feedback(mut self, accepted: bool, reason: Option<&str>) -> Self {
        self.user_accepted = Some(accepted);
        if !accepted {
            self.rejection_reason = reason.map(|s| s.to_string());
        }
        self
    }
}

/// Local telemetry storage
pub struct TelemetryStore {
    /// Storage directory
    data_dir: PathBuf,

    /// In-memory cache of recent outcomes
    recent_outcomes: Vec<FillOutcome>,

    /// Maximum outcomes to keep in memory
    max_cached: usize,
}

impl TelemetryStore {
    /// Create new telemetry store
    pub fn new(data_dir: PathBuf) -> std::io::Result<Self> {
        // Ensure directory exists
        fs::create_dir_all(&data_dir)?;

        Ok(Self {
            data_dir,
            recent_outcomes: Vec::new(),
            max_cached: 1000,
        })
    }

    /// Create with default data directory
    pub fn default_location() -> std::io::Result<Self> {
        let data_dir = dirs::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("ananke")
            .join("telemetry");

        Self::new(data_dir)
    }

    /// Record a fill outcome
    pub fn record(&mut self, outcome: FillOutcome) -> std::io::Result<()> {
        // Add to memory cache
        self.recent_outcomes.push(outcome.clone());

        // Trim cache if needed
        if self.recent_outcomes.len() > self.max_cached {
            self.recent_outcomes.remove(0);
        }

        // Persist to disk
        self.persist_outcome(&outcome)?;

        Ok(())
    }

    /// Persist outcome to disk
    fn persist_outcome(&self, outcome: &FillOutcome) -> std::io::Result<()> {
        let file_path = self.data_dir.join(format!("{}.json", outcome.id));
        let json = serde_json::to_string_pretty(outcome)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        fs::write(file_path, json)
    }

    /// Load outcomes from disk
    pub fn load_outcomes(&self, limit: Option<usize>) -> std::io::Result<Vec<FillOutcome>> {
        let mut outcomes: Vec<FillOutcome> = Vec::new();

        for entry in fs::read_dir(&self.data_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().map(|e| e == "json").unwrap_or(false) {
                let content = fs::read_to_string(&path)?;
                if let Ok(outcome) = serde_json::from_str(&content) {
                    outcomes.push(outcome);
                }
            }

            if let Some(lim) = limit {
                if outcomes.len() >= lim {
                    break;
                }
            }
        }

        // Sort by timestamp descending
        outcomes.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

        Ok(outcomes)
    }

    /// Get recent outcomes from cache
    pub fn get_recent(&self, count: usize) -> &[FillOutcome] {
        let start = self.recent_outcomes.len().saturating_sub(count);
        &self.recent_outcomes[start..]
    }

    /// Get outcomes for a specific hole scale
    pub fn get_by_scale(&self, scale: &str) -> Vec<&FillOutcome> {
        self.recent_outcomes
            .iter()
            .filter(|o| o.hole_scale == scale)
            .collect()
    }

    /// Get outcomes for a specific strategy
    pub fn get_by_strategy(&self, strategy: &str) -> Vec<&FillOutcome> {
        self.recent_outcomes
            .iter()
            .filter(|o| o.strategy == strategy)
            .collect()
    }

    /// Clear all telemetry data
    pub fn clear_all(&mut self) -> std::io::Result<()> {
        self.recent_outcomes.clear();

        for entry in fs::read_dir(&self.data_dir)? {
            let entry = entry?;
            fs::remove_file(entry.path())?;
        }

        Ok(())
    }

    /// Get total outcome count
    pub fn count(&self) -> usize {
        self.recent_outcomes.len()
    }

    /// Export outcomes to JSON
    pub fn export_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(&self.recent_outcomes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_fill_outcome_creation() {
        let outcome = FillOutcome::new(
            "hole-1".to_string(),
            "statement".to_string(),
            "user_marked".to_string(),
            "llm_complete".to_string(),
        )
        .with_success(0.9)
        .with_model("claude")
        .with_time(150)
        .with_constraints(5, 0);

        assert!(outcome.success);
        assert_eq!(outcome.confidence, 0.9);
        assert_eq!(outcome.model, Some("claude".to_string()));
        assert_eq!(outcome.constraints_satisfied, 5);
    }

    #[test]
    fn test_telemetry_store() {
        let temp_dir = TempDir::new().unwrap();
        let mut store = TelemetryStore::new(temp_dir.path().to_path_buf()).unwrap();

        let outcome = FillOutcome::new(
            "hole-1".to_string(),
            "statement".to_string(),
            "user_marked".to_string(),
            "llm_complete".to_string(),
        )
        .with_success(0.85);

        store.record(outcome).unwrap();

        assert_eq!(store.count(), 1);

        let recent = store.get_recent(10);
        assert_eq!(recent.len(), 1);
        assert!(recent[0].success);
    }

    #[test]
    fn test_load_outcomes() {
        let temp_dir = TempDir::new().unwrap();
        let mut store = TelemetryStore::new(temp_dir.path().to_path_buf()).unwrap();

        for i in 0..5 {
            let outcome = FillOutcome::new(
                format!("hole-{}", i),
                "statement".to_string(),
                "user_marked".to_string(),
                "llm_complete".to_string(),
            );
            store.record(outcome).unwrap();
        }

        // Create new store instance to test loading from disk
        let store2 = TelemetryStore::new(temp_dir.path().to_path_buf()).unwrap();
        let loaded = store2.load_outcomes(None).unwrap();

        assert_eq!(loaded.len(), 5);
    }
}
