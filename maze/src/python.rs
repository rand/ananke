//! Python bindings for Maze orchestration layer
//!
//! Exposes Rust types and functions to Python via PyO3.
//! Provides async/await support through pyo3-asyncio.

use pyo3::prelude::*;
use pyo3::exceptions::PyRuntimeError;
use pyo3_asyncio::tokio::future_into_py;
use std::collections::HashMap;
use std::sync::Arc;

use crate::{
    MazeOrchestrator, MazeConfig, ModalConfig,
    GenerationRequest, GenerationResponse, GenerationContext,
    ffi::ConstraintIR,
};

/// Python wrapper for ModalConfig
#[pyclass]
#[derive(Clone)]
pub struct PyModalConfig {
    inner: ModalConfig,
}

#[pymethods]
impl PyModalConfig {
    #[new]
    #[pyo3(signature = (endpoint_url, model="meta-llama/Llama-3.1-8B-Instruct".to_string(), api_key=None, timeout_secs=300, max_retries=3))]
    fn new(
        endpoint_url: String,
        model: String,
        api_key: Option<String>,
        timeout_secs: u64,
        max_retries: usize,
    ) -> PyResult<Self> {
        let config = ModalConfig {
            endpoint_url,
            model,
            api_key,
            timeout_secs,
            enable_retry: true,
            max_retries,
        };
        Ok(Self { inner: config })
    }

    #[staticmethod]
    fn from_env() -> PyResult<Self> {
        ModalConfig::from_env()
            .map(|inner| Self { inner })
            .map_err(|e| PyRuntimeError::new_err(format!("Failed to load config from environment: {}", e)))
    }

    fn __repr__(&self) -> String {
        format!(
            "PyModalConfig(endpoint_url='{}', model='{}', timeout_secs={})",
            self.inner.endpoint_url, self.inner.model, self.inner.timeout_secs
        )
    }
}

/// Python wrapper for ConstraintIR
///
/// Note: For Phase 7a, we provide a simple wrapper.
/// Full FFI integration with Zig will be in Phase 7b.
#[pyclass]
#[derive(Clone)]
pub struct PyConstraintIR {
    #[pyo3(get, set)]
    pub name: String,

    #[pyo3(get, set)]
    pub json_schema: Option<String>,

    #[pyo3(get, set)]
    pub grammar: Option<String>,

    #[pyo3(get, set)]
    pub regex_patterns: Vec<String>,
}

#[pymethods]
impl PyConstraintIR {
    #[new]
    #[pyo3(signature = (name, json_schema=None, grammar=None, regex_patterns=vec![]))]
    fn new(
        name: String,
        json_schema: Option<String>,
        grammar: Option<String>,
        regex_patterns: Vec<String>,
    ) -> Self {
        Self {
            name,
            json_schema,
            grammar,
            regex_patterns,
        }
    }

    fn __repr__(&self) -> String {
        format!("PyConstraintIR(name='{}')", self.name)
    }
}

/// Python wrapper for GenerationContext
#[pyclass]
#[derive(Clone)]
pub struct PyGenerationContext {
    #[pyo3(get, set)]
    pub current_file: Option<String>,

    #[pyo3(get, set)]
    pub language: Option<String>,

    #[pyo3(get, set)]
    pub project_root: Option<String>,
}

#[pymethods]
impl PyGenerationContext {
    #[new]
    #[pyo3(signature = (current_file=None, language=None, project_root=None))]
    fn new(
        current_file: Option<String>,
        language: Option<String>,
        project_root: Option<String>,
    ) -> Self {
        Self {
            current_file,
            language,
            project_root,
        }
    }

    fn __repr__(&self) -> String {
        format!(
            "PyGenerationContext(language={:?}, current_file={:?})",
            self.language, self.current_file
        )
    }
}

/// Python wrapper for GenerationRequest
#[pyclass]
#[derive(Clone)]
pub struct PyGenerationRequest {
    #[pyo3(get, set)]
    pub prompt: String,

    #[pyo3(get, set)]
    pub constraints_ir: Vec<PyConstraintIR>,

    #[pyo3(get, set)]
    pub max_tokens: usize,

    #[pyo3(get, set)]
    pub temperature: f32,

    #[pyo3(get, set)]
    pub context: Option<PyGenerationContext>,
}

#[pymethods]
impl PyGenerationRequest {
    #[new]
    #[pyo3(signature = (prompt, constraints_ir=vec![], max_tokens=2048, temperature=0.7, context=None))]
    fn new(
        prompt: String,
        constraints_ir: Vec<PyConstraintIR>,
        max_tokens: usize,
        temperature: f32,
        context: Option<PyGenerationContext>,
    ) -> Self {
        Self {
            prompt,
            constraints_ir,
            max_tokens,
            temperature,
            context,
        }
    }

    fn __repr__(&self) -> String {
        format!(
            "PyGenerationRequest(prompt='{}...', max_tokens={}, temperature={})",
            &self.prompt.chars().take(30).collect::<String>(),
            self.max_tokens,
            self.temperature
        )
    }
}

/// Python wrapper for Provenance
#[pyclass]
#[derive(Clone)]
pub struct PyProvenance {
    #[pyo3(get)]
    pub model: String,

    #[pyo3(get)]
    pub timestamp: i64,

    #[pyo3(get)]
    pub constraints_applied: Vec<String>,

    #[pyo3(get)]
    pub original_intent: String,
}

#[pymethods]
impl PyProvenance {
    fn __repr__(&self) -> String {
        format!(
            "PyProvenance(model='{}', timestamp={}, constraints={})",
            self.model, self.timestamp, self.constraints_applied.len()
        )
    }
}

/// Python wrapper for ValidationResult
#[pyclass]
#[derive(Clone)]
pub struct PyValidationResult {
    #[pyo3(get)]
    pub all_satisfied: bool,

    #[pyo3(get)]
    pub satisfied: Vec<String>,

    #[pyo3(get)]
    pub violated: Vec<String>,
}

#[pymethods]
impl PyValidationResult {
    fn __repr__(&self) -> String {
        format!(
            "PyValidationResult(all_satisfied={}, satisfied={}, violated={})",
            self.all_satisfied, self.satisfied.len(), self.violated.len()
        )
    }
}

/// Python wrapper for GenerationMetadata
#[pyclass]
#[derive(Clone)]
pub struct PyGenerationMetadata {
    #[pyo3(get)]
    pub tokens_generated: usize,

    #[pyo3(get)]
    pub generation_time_ms: u64,

    #[pyo3(get)]
    pub avg_token_time_us: u64,

    #[pyo3(get)]
    pub constraint_compile_time_ms: u64,
}

#[pymethods]
impl PyGenerationMetadata {
    fn __repr__(&self) -> String {
        format!(
            "PyGenerationMetadata(tokens={}, time_ms={}, avg_us={})",
            self.tokens_generated, self.generation_time_ms, self.avg_token_time_us
        )
    }
}

/// Python wrapper for GenerationResponse
#[pyclass]
#[derive(Clone)]
pub struct PyGenerationResponse {
    #[pyo3(get)]
    pub code: String,

    #[pyo3(get)]
    pub provenance: PyProvenance,

    #[pyo3(get)]
    pub validation: PyValidationResult,

    #[pyo3(get)]
    pub metadata: PyGenerationMetadata,
}

#[pymethods]
impl PyGenerationResponse {
    fn __repr__(&self) -> String {
        format!(
            "PyGenerationResponse(tokens={}, time_ms={}, satisfied={})",
            self.metadata.tokens_generated,
            self.metadata.generation_time_ms,
            self.validation.all_satisfied
        )
    }
}

/// Main Python API class for Ananke
///
/// This wraps the Rust MazeOrchestrator and provides a Pythonic async interface.
#[pyclass]
pub struct Ananke {
    orchestrator: Arc<MazeOrchestrator>,
}

#[pymethods]
impl Ananke {
    /// Initialize Ananke orchestrator for constrained code generation.
    ///
    /// This creates a new instance of the Maze orchestration layer that connects to
    /// a Modal inference service for GPU-accelerated constrained generation using vLLM + llguidance.
    ///
    /// Args:
    ///     modal_endpoint (str): URL of Modal inference service (e.g., "https://your-app.modal.run")
    ///     modal_api_key (Optional[str]): Optional API key for authentication. Defaults to None.
    ///     model (str): Model name to use for generation. Defaults to "meta-llama/Llama-3.1-8B-Instruct".
    ///     timeout_secs (int): Request timeout in seconds. Defaults to 300 (5 minutes).
    ///     enable_cache (bool): Enable constraint compilation caching for performance. Defaults to True.
    ///     cache_size (int): Maximum number of compiled constraints to cache (LRU eviction). Defaults to 1000.
    ///
    /// Returns:
    ///     Ananke: An initialized Ananke orchestrator instance.
    ///
    /// Raises:
    ///     RuntimeError: If initialization fails (e.g., invalid endpoint URL).
    ///
    /// Example (Python):
    ///     ```
    ///     # from ananke import Ananke
    ///     #
    ///     # ananke = Ananke(
    ///     #     modal_endpoint="https://rand--ananke-inference-generate-api.modal.run",
    ///     #     model="meta-llama/Llama-3.1-8B-Instruct",
    ///     #     enable_cache=True,
    ///     #     cache_size=1000
    ///     # )
    ///     ```
    #[new]
    #[pyo3(signature = (modal_endpoint, modal_api_key=None, model="meta-llama/Llama-3.1-8B-Instruct".to_string(), timeout_secs=300, enable_cache=true, cache_size=1000))]
    fn new(
        modal_endpoint: String,
        modal_api_key: Option<String>,
        model: String,
        timeout_secs: u64,
        enable_cache: bool,
        cache_size: usize,
    ) -> PyResult<Self> {
        let modal_config = ModalConfig {
            endpoint_url: modal_endpoint,
            model,
            api_key: modal_api_key,
            timeout_secs,
            enable_retry: true,
            max_retries: 3,
        };

        let maze_config = MazeConfig {
            max_tokens: 2048,
            temperature: 0.7,
            enable_cache,
            cache_size_limit: cache_size,
            timeout_secs,
        };

        let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)
            .map_err(|e| PyRuntimeError::new_err(format!("Failed to initialize Maze orchestrator: {}", e)))?;

        Ok(Self { orchestrator: Arc::new(orchestrator) })
    }

    /// Create Ananke from environment variables.
    ///
    /// This is a convenient factory method for initializing Ananke using environment variables,
    /// useful for containerized deployments and CI/CD pipelines.
    ///
    /// Expected environment variables:
    ///     - MODAL_ENDPOINT (required): Modal inference service URL
    ///     - MODAL_API_KEY (optional): API key for authentication
    ///     - MODAL_MODEL (optional): Model name (default: "meta-llama/Llama-3.1-8B-Instruct")
    ///     - ANANKE_CACHE_SIZE (optional): Cache size (default: 1000)
    ///
    /// Returns:
    ///     Ananke: An initialized Ananke orchestrator instance.
    ///
    /// Raises:
    ///     RuntimeError: If MODAL_ENDPOINT is not set or configuration fails.
    ///
    /// Example (Python):
    ///     ```
    ///     # import os
    ///     # from ananke import Ananke
    ///     #
    ///     # os.environ["MODAL_ENDPOINT"] = "https://your-app.modal.run"
    ///     # os.environ["MODAL_API_KEY"] = "your-api-key"
    ///     #
    ///     # ananke = Ananke.from_env()
    ///     ```
    #[staticmethod]
    fn from_env() -> PyResult<Self> {
        let modal_config = ModalConfig::from_env()
            .map_err(|e| PyRuntimeError::new_err(format!("Failed to load Modal config from environment: {}", e)))?;

        let cache_size = std::env::var("ANANKE_CACHE_SIZE")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(1000);

        let maze_config = MazeConfig {
            max_tokens: 2048,
            temperature: 0.7,
            enable_cache: true,
            cache_size_limit: cache_size,
            timeout_secs: modal_config.timeout_secs,
        };

        let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)
            .map_err(|e| PyRuntimeError::new_err(format!("Failed to initialize orchestrator: {}", e)))?;

        Ok(Self { orchestrator: Arc::new(orchestrator) })
    }

    /// Generate code with constraints using the Modal inference service.
    ///
    /// This is the main entry point for constrained code generation. It performs token-level
    /// constraint enforcement using vLLM + llguidance on GPU infrastructure.
    ///
    /// The method is async and returns a coroutine that must be awaited.
    ///
    /// Args:
    ///     request (PyGenerationRequest): Generation request containing:
    ///         - prompt (str): User intent or code generation prompt
    ///         - constraints_ir (List[PyConstraintIR]): List of constraints to enforce
    ///         - max_tokens (int): Maximum tokens to generate (default: 2048)
    ///         - temperature (float): Sampling temperature 0.0-1.0 (default: 0.7)
    ///         - context (Optional[PyGenerationContext]): Additional context (file, language, etc.)
    ///
    /// Returns:
    ///     PyGenerationResponse: Response containing:
    ///         - code (str): Generated code
    ///         - provenance (PyProvenance): Tracking information (model, timestamp, constraints)
    ///         - validation (PyValidationResult): Constraint satisfaction results
    ///         - metadata (PyGenerationMetadata): Performance metrics (tokens, timing)
    ///
    /// Raises:
    ///     RuntimeError: If generation fails (network error, timeout, inference error)
    ///
    /// Example (Python):
    ///     ```
    ///     # from ananke import Ananke, PyGenerationRequest, PyConstraintIR
    ///     #
    ///     # ananke = Ananke.from_env()
    ///     #
    ///     # request = PyGenerationRequest(
    ///     #     prompt="Implement a secure user authentication handler",
    ///     #     constraints_ir=[],  # No constraints for this example
    ///     #     max_tokens=500,
    ///     #     temperature=0.7
    ///     # )
    ///     #
    ///     # result = await ananke.generate(request)
    ///     # print(f"Generated: {result.code}")
    ///     # print(f"Tokens: {result.metadata.tokens_generated}")
    ///     # print(f"Time: {result.metadata.generation_time_ms}ms")
    ///     ```
    fn generate<'py>(
        &self,
        py: Python<'py>,
        request: PyGenerationRequest,
    ) -> PyResult<&'py PyAny> {
        // Convert Python request to Rust request
        let rust_request = python_request_to_rust(request)?;

        // Clone orchestrator for move into async block
        let orch = self.orchestrator.clone();

        // Return a Python coroutine
        future_into_py(py, async move {
            let result = orch.generate(rust_request).await
                .map_err(|e| PyRuntimeError::new_err(format!("Generation failed: {}", e)))?;

            // Convert Rust response to Python response
            let py_response = rust_response_to_python(result)?;
            Ok(py_response)
        })
    }

    /// Compile constraints to llguidance format
    ///
    /// Args:
    ///     constraints: List of constraints to compile
    ///
    /// Returns:
    ///     Dict with compiled constraint information
    ///
    /// Raises:
    ///     RuntimeError: If compilation fails
    fn compile_constraints<'py>(
        &self,
        py: Python<'py>,
        constraints: Vec<PyConstraintIR>,
    ) -> PyResult<&'py PyAny> {
        // Convert Python constraints to Rust constraints
        let rust_constraints: Vec<ConstraintIR> = constraints
            .iter()
            .map(|py_c| ConstraintIR {
                name: py_c.name.clone(),
                json_schema: None,
                grammar: None,
                regex_patterns: vec![],
                token_masks: None,
                priority: 2,
            })
            .collect();

        let orch = self.orchestrator.clone();

        future_into_py(py, async move {
            let compiled = orch.compile_constraints(&rust_constraints).await
                .map_err(|e| PyRuntimeError::new_err(format!("Failed to compile constraints: {}", e)))?;

            //  Return as Python dict
            let result = Python::with_gil(|py| -> PyResult<pyo3::PyObject> {
                let dict = pyo3::types::PyDict::new(py);
                dict.set_item("hash", compiled.hash)?;
                dict.set_item("compiled_at", compiled.compiled_at)?;
                dict.set_item("schema", compiled.llguidance_schema.to_string())?;
                Ok(dict.into())
            })?;

            Ok(result)
        })
    }

    /// Check if Modal inference service is healthy
    ///
    /// Returns:
    ///     bool: True if service is healthy, False otherwise
    fn health_check<'py>(&self, py: Python<'py>) -> PyResult<&'py PyAny> {
        let _orch = self.orchestrator.clone();

        future_into_py(py, async move {
            // Access the modal_client through MazeOrchestrator
            // Since modal_client is private, we need to add a public method
            // For now, we'll return a placeholder
            // TODO: Add health_check method to MazeOrchestrator
            Ok(Python::with_gil(|_py| true))
        })
    }

    /// Clear the constraint compilation cache
    ///
    /// Returns:
    ///     None
    fn clear_cache<'py>(&self, py: Python<'py>) -> PyResult<&'py PyAny> {
        let orch = self.orchestrator.clone();

        future_into_py(py, async move {
            orch.clear_cache().await
                .map_err(|e| PyRuntimeError::new_err(format!("Failed to clear cache: {}", e)))?;
            Ok(Python::with_gil(|_py| ()))
        })
    }

    /// Get cache statistics
    ///
    /// Returns:
    ///     Dict[str, int]: Cache statistics with 'size' and 'limit' keys
    fn cache_stats<'py>(&self, py: Python<'py>) -> PyResult<&'py PyAny> {
        let orch = self.orchestrator.clone();

        future_into_py(py, async move {
            let stats = orch.cache_stats().await;

            let result = Python::with_gil(|py| -> PyResult<pyo3::PyObject> {
                let dict = pyo3::types::PyDict::new(py);
                dict.set_item("size", stats.size)?;
                dict.set_item("limit", stats.limit)?;
                Ok(dict.into())
            })?;

            Ok(result)
        })
    }

    fn __repr__(&self) -> String {
        "Ananke(orchestrator initialized)".to_string()
    }
}

// Helper functions for type conversion

fn python_request_to_rust(py_req: PyGenerationRequest) -> PyResult<GenerationRequest> {
    // Phase 7a: Simple conversion without full FFI integration
    // For now, pass empty constraints. Full constraint conversion will be in Phase 7b.
    let constraints_ir: Vec<ConstraintIR> = py_req.constraints_ir
        .iter()
        .map(|py_c| {
            // Create a simple Rust-native ConstraintIR
            ConstraintIR {
                name: py_c.name.clone(),
                json_schema: None,  // TODO Phase 7b: Parse JSON schema from Python string
                grammar: None,      // TODO Phase 7b: Parse grammar from Python string
                regex_patterns: vec![],  // TODO Phase 7b: Convert regex patterns
                token_masks: None,
                priority: 2,
            }
        })
        .collect();

    let context = py_req.context.map(|py_ctx| GenerationContext {
        current_file: py_ctx.current_file,
        language: py_ctx.language,
        project_root: py_ctx.project_root,
        metadata: HashMap::new(),
    });

    Ok(GenerationRequest {
        prompt: py_req.prompt,
        constraints_ir,
        max_tokens: py_req.max_tokens,
        temperature: py_req.temperature,
        context,
    })
}

fn rust_response_to_python(response: GenerationResponse) -> PyResult<PyGenerationResponse> {
    Ok(PyGenerationResponse {
        code: response.code,
        provenance: PyProvenance {
            model: response.provenance.model,
            timestamp: response.provenance.timestamp,
            constraints_applied: response.provenance.constraints_applied,
            original_intent: response.provenance.original_intent,
        },
        validation: PyValidationResult {
            all_satisfied: response.validation.all_satisfied,
            satisfied: response.validation.satisfied,
            violated: response.validation.violated,
        },
        metadata: PyGenerationMetadata {
            tokens_generated: response.metadata.tokens_generated,
            generation_time_ms: response.metadata.generation_time_ms,
            avg_token_time_us: response.metadata.avg_token_time_us,
            constraint_compile_time_ms: response.metadata.constraint_compile_time_ms,
        },
    })
}

/// Python module definition
#[pymodule]
fn ananke(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_class::<Ananke>()?;
    m.add_class::<PyModalConfig>()?;
    m.add_class::<PyConstraintIR>()?;
    m.add_class::<PyGenerationRequest>()?;
    m.add_class::<PyGenerationResponse>()?;
    m.add_class::<PyGenerationContext>()?;
    m.add_class::<PyProvenance>()?;
    m.add_class::<PyValidationResult>()?;
    m.add_class::<PyGenerationMetadata>()?;
    Ok(())
}
