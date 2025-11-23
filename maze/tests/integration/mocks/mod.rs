//! Mock implementations for integration testing
//!
//! Provides realistic mock implementations of external services
//! to enable comprehensive testing without network dependencies.

pub mod modal_service;

pub use modal_service::{MockModalService, MockScenario, MockResponse};
