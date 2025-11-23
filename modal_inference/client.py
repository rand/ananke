"""
Ananke Inference Client

Convenient Python client for the Modal inference service.
Use this from Maze or other Ananke components.
"""

import json
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Union

import modal


@dataclass
class ConstraintSpec:
    """Constraint specification for code generation."""
    constraint_type: str  # "json", "regex", "grammar", "composite"
    schema: Optional[Dict[str, Any]] = None
    pattern: Optional[str] = None
    grammar: Optional[str] = None
    constraints: Optional[List['ConstraintSpec']] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API request."""
        result = {"type": self.constraint_type}

        if self.schema:
            result["schema"] = self.schema
        if self.pattern:
            result["pattern"] = self.pattern
        if self.grammar:
            result["grammar"] = self.grammar
        if self.constraints:
            result["constraints"] = [c.to_dict() for c in self.constraints]

        return result


@dataclass
class GenerationConfig:
    """Configuration for code generation."""
    max_tokens: int = 2048
    temperature: float = 0.7
    top_p: float = 0.95
    top_k: int = 50
    stop_sequences: List[str] = field(default_factory=list)


@dataclass
class GenerationResult:
    """Result from code generation."""
    code: str
    tokens_generated: int
    generation_time_ms: float
    constraint_violations: int
    provenance: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = None

    @property
    def tokens_per_second(self) -> float:
        """Calculate tokens per second."""
        return self.provenance.get("tokens_per_second", 0.0)

    @property
    def model_name(self) -> str:
        """Get model name from provenance."""
        return self.provenance.get("model", "unknown")

    @property
    def is_valid(self) -> bool:
        """Check if generation satisfied all constraints."""
        return self.constraint_violations == 0


class AnankeInferenceClient:
    """
    Client for Ananke Modal inference service.

    Usage:
        client = AnankeInferenceClient()
        result = client.generate("Create a function", constraints)
    """

    def __init__(
        self,
        app_name: str = "ananke-inference",
        class_name: str = "InferenceService",
        timeout: int = 600,
    ):
        """
        Initialize client.

        Args:
            app_name: Modal app name
            class_name: Service class name
            timeout: Request timeout in seconds
        """
        self.app_name = app_name
        self.class_name = class_name
        self.timeout = timeout
        self._service = None

    def _get_service(self):
        """Lazy load service reference."""
        if self._service is None:
            try:
                ServiceClass = modal.Cls.lookup(self.app_name, self.class_name)
                self._service = ServiceClass()
            except Exception as e:
                raise RuntimeError(
                    f"Failed to connect to {self.app_name}.{self.class_name}. "
                    f"Is the service deployed? Error: {e}"
                )
        return self._service

    def generate(
        self,
        prompt: str,
        constraints: Optional[Union[ConstraintSpec, Dict[str, Any]]] = None,
        config: Optional[GenerationConfig] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """
        Generate code with constraints.

        Args:
            prompt: Natural language prompt
            constraints: Constraint specification
            config: Generation configuration
            metadata: Optional metadata to attach

        Returns:
            GenerationResult with code and provenance

        Raises:
            RuntimeError: If generation fails
        """
        service = self._get_service()

        # Prepare config
        if config is None:
            config = GenerationConfig()

        # Convert constraints
        constraint_dict = None
        if constraints:
            if isinstance(constraints, ConstraintSpec):
                constraint_dict = constraints.to_dict()
            else:
                constraint_dict = constraints

        # Build request
        request = {
            "prompt": prompt,
            "constraints": constraint_dict or {},
            "max_tokens": config.max_tokens,
            "temperature": config.temperature,
            "top_p": config.top_p,
            "top_k": config.top_k,
            "stop_sequences": config.stop_sequences,
            "metadata": metadata,
        }

        # Make request
        try:
            response = service.generate.remote(request)
        except Exception as e:
            raise RuntimeError(f"Generation request failed: {e}")

        # Check for errors
        if "error" in response:
            raise RuntimeError(
                f"Generation failed: {response['error']} "
                f"({response.get('error_type', 'Unknown')})"
            )

        # Parse result
        return GenerationResult(
            code=response["generated_code"],
            tokens_generated=response["tokens_generated"],
            generation_time_ms=response["generation_time_ms"],
            constraint_violations=response["constraint_violations"],
            provenance=response["provenance"],
            metadata=response.get("metadata"),
        )

    def generate_with_json_schema(
        self,
        prompt: str,
        schema: Dict[str, Any],
        config: Optional[GenerationConfig] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """
        Convenience method for JSON schema constraints.

        Args:
            prompt: Natural language prompt
            schema: JSON schema
            config: Generation configuration
            metadata: Optional metadata

        Returns:
            GenerationResult
        """
        constraints = ConstraintSpec(
            constraint_type="json",
            schema=schema,
        )
        return self.generate(prompt, constraints, config, metadata)

    def generate_with_regex(
        self,
        prompt: str,
        pattern: str,
        config: Optional[GenerationConfig] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """
        Convenience method for regex constraints.

        Args:
            prompt: Natural language prompt
            pattern: Regular expression pattern
            config: Generation configuration
            metadata: Optional metadata

        Returns:
            GenerationResult
        """
        constraints = ConstraintSpec(
            constraint_type="regex",
            pattern=pattern,
        )
        return self.generate(prompt, constraints, config, metadata)

    def generate_with_grammar(
        self,
        prompt: str,
        grammar: str,
        config: Optional[GenerationConfig] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """
        Convenience method for grammar constraints.

        Args:
            prompt: Natural language prompt
            grammar: EBNF grammar specification
            config: Generation configuration
            metadata: Optional metadata

        Returns:
            GenerationResult
        """
        constraints = ConstraintSpec(
            constraint_type="grammar",
            grammar=grammar,
        )
        return self.generate(prompt, constraints, config, metadata)

    def health_check(self) -> Dict[str, Any]:
        """
        Check service health.

        Returns:
            Health status dictionary
        """
        service = self._get_service()
        return service.health_check.remote()

    def validate_constraints(
        self,
        constraints: Union[ConstraintSpec, Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Validate constraint specification without generating.

        Args:
            constraints: Constraint specification to validate

        Returns:
            Validation result with 'valid' boolean and optional 'error'
        """
        service = self._get_service()

        constraint_dict = (
            constraints.to_dict()
            if isinstance(constraints, ConstraintSpec)
            else constraints
        )

        return service.validate_constraints.remote(constraint_dict)


class AnankeInferenceHTTPClient:
    """
    HTTP client for Ananke inference service.

    Use this when you can't use Modal directly (e.g., from Rust/Zig).
    """

    def __init__(self, endpoint_url: str, api_key: Optional[str] = None):
        """
        Initialize HTTP client.

        Args:
            endpoint_url: Full URL to inference endpoint
            api_key: Optional API key for authentication
        """
        self.endpoint_url = endpoint_url
        self.api_key = api_key
        self.session = None

    def _get_session(self):
        """Lazy load requests session."""
        if self.session is None:
            import requests
            self.session = requests.Session()
            if self.api_key:
                self.session.headers["Authorization"] = f"Bearer {self.api_key}"
        return self.session

    def generate(
        self,
        prompt: str,
        constraints: Optional[Union[ConstraintSpec, Dict[str, Any]]] = None,
        config: Optional[GenerationConfig] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """
        Generate code via HTTP API.

        Args:
            prompt: Natural language prompt
            constraints: Constraint specification
            config: Generation configuration
            metadata: Optional metadata

        Returns:
            GenerationResult

        Raises:
            RuntimeError: If request fails
        """
        session = self._get_session()

        # Prepare config
        if config is None:
            config = GenerationConfig()

        # Convert constraints
        constraint_dict = None
        if constraints:
            if isinstance(constraints, ConstraintSpec):
                constraint_dict = constraints.to_dict()
            else:
                constraint_dict = constraints

        # Build request
        request_data = {
            "prompt": prompt,
            "constraints": constraint_dict or {},
            "max_tokens": config.max_tokens,
            "temperature": config.temperature,
            "top_p": config.top_p,
            "top_k": config.top_k,
            "stop_sequences": config.stop_sequences,
            "metadata": metadata,
        }

        # Make request
        try:
            response = session.post(
                self.endpoint_url,
                json=request_data,
                timeout=600,
            )
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            raise RuntimeError(f"HTTP request failed: {e}")

        # Check for errors
        if "error" in data:
            raise RuntimeError(
                f"Generation failed: {data['error']} "
                f"({data.get('error_type', 'Unknown')})"
            )

        # Parse result
        return GenerationResult(
            code=data["generated_code"],
            tokens_generated=data["tokens_generated"],
            generation_time_ms=data["generation_time_ms"],
            constraint_violations=data["constraint_violations"],
            provenance=data["provenance"],
            metadata=data.get("metadata"),
        )


# Convenience functions
def create_client(endpoint_url: Optional[str] = None) -> Union[AnankeInferenceClient, AnankeInferenceHTTPClient]:
    """
    Create appropriate client based on environment.

    Args:
        endpoint_url: If provided, create HTTP client. Otherwise Modal client.

    Returns:
        Client instance
    """
    if endpoint_url:
        return AnankeInferenceHTTPClient(endpoint_url)
    else:
        return AnankeInferenceClient()


# Example usage
if __name__ == "__main__":
    # Example 1: Using Modal client
    print("Example 1: Modal Client")
    client = AnankeInferenceClient()

    # Check health
    health = client.health_check()
    print(f"Service health: {health['status']}")
    print(f"Model: {health['model']}")

    # Generate with JSON schema
    result = client.generate_with_json_schema(
        prompt="Generate a Python function that validates email addresses:",
        schema={
            "type": "object",
            "properties": {
                "function_name": {"type": "string"},
                "body": {"type": "string"}
            },
            "required": ["function_name", "body"]
        },
        metadata={"example": "client_demo"}
    )

    print(f"\nGenerated code ({result.tokens_generated} tokens):")
    print(result.code)
    print(f"\nValid: {result.is_valid}")
    print(f"Speed: {result.tokens_per_second:.1f} tok/s")

    # Example 2: Using constraint spec
    print("\n\nExample 2: ConstraintSpec")
    constraints = ConstraintSpec(
        constraint_type="regex",
        pattern=r"def \w+\(.*\):.*"
    )

    result = client.generate(
        prompt="Create a simple hello world function:",
        constraints=constraints,
        config=GenerationConfig(max_tokens=256, temperature=0.5),
    )

    print(f"Generated code ({result.tokens_generated} tokens):")
    print(result.code)
