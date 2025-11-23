"""
Ananke Modal Inference Service

This module provides GPU-accelerated constrained code generation using vLLM
and llguidance. It's designed to scale to zero after 60 seconds of inactivity
and handle token-level constraint enforcement.

Architecture:
- Uses vLLM 0.8.2+ for efficient model serving
- Integrates llguidance for FSM-based constraint compilation
- Runs on A100 GPUs (40GB-80GB VRAM)
- Supports multiple model backends (Llama, Mistral, DeepSeek)
"""

import json
import logging
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import modal

# Modal app configuration
app = modal.App("ananke-inference")

# GPU configuration - A100 with 40GB VRAM
# For larger models, switch to memory=80
GPU_CONFIG = modal.gpu.A100(count=1, memory=40)

# Container idle timeout - scale to zero after 60 seconds
IDLE_TIMEOUT = 60

# Default model - Llama 3.1 8B Instruct
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-8B-Instruct"

# Model options with VRAM requirements
MODEL_CONFIGS = {
    "llama-3.1-8b": {
        "name": "meta-llama/Meta-Llama-3.1-8B-Instruct",
        "vram_gb": 16,
        "context_length": 128000,
    },
    "llama-3.1-70b": {
        "name": "meta-llama/Meta-Llama-3.1-70B-Instruct",
        "vram_gb": 80,
        "context_length": 128000,
    },
    "mistral-7b": {
        "name": "mistralai/Mistral-7B-Instruct-v0.3",
        "vram_gb": 14,
        "context_length": 32768,
    },
    "deepseek-coder-6.7b": {
        "name": "deepseek-ai/deepseek-coder-6.7b-instruct",
        "vram_gb": 13,
        "context_length": 16384,
    },
}

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@dataclass
class GenerationRequest:
    """Request for constrained code generation."""
    prompt: str
    constraints: Dict[str, Any]
    max_tokens: int = 2048
    temperature: float = 0.7
    top_p: float = 0.95
    top_k: int = 50
    stop_sequences: Optional[List[str]] = None
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class GenerationResponse:
    """Response from constrained generation."""
    generated_code: str
    tokens_generated: int
    generation_time_ms: float
    constraint_violations: int
    provenance: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = None


# Modal image with all dependencies
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "vllm==0.8.2",
        "llguidance==0.2.0",
        "torch==2.5.1",
        "transformers==4.46.0",
        "huggingface-hub==0.26.2",
        "pydantic==2.9.2",
    )
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1"})
)


@app.cls(
    gpu=GPU_CONFIG,
    image=image,
    container_idle_timeout=IDLE_TIMEOUT,
    secrets=[modal.Secret.from_name("huggingface-secret")],
    allow_concurrent_inputs=10,
    timeout=600,
)
class InferenceService:
    """
    Ananke inference service for constrained code generation.

    This service provides token-level constraint enforcement using llguidance
    integrated with vLLM for efficient GPU inference.
    """

    model_name: str = DEFAULT_MODEL

    def __init__(self, model_name: Optional[str] = None):
        """Initialize with optional model override."""
        if model_name:
            self.model_name = model_name

    @modal.enter()
    def load_model(self):
        """
        Load the LLM and initialize llguidance on container start.

        This happens once per container and is cached across requests.
        """
        logger.info(f"Loading model: {self.model_name}")
        start_time = time.time()

        try:
            from vllm import LLM, SamplingParams
            from llguidance import LLGuidance, Grammar

            # Initialize vLLM with optimized settings
            self.llm = LLM(
                model=self.model_name,
                gpu_memory_utilization=0.90,
                max_model_len=None,  # Auto-detect from model
                enforce_eager=True,  # Required for llguidance integration
                trust_remote_code=True,
                dtype="auto",
                tensor_parallel_size=1,
            )

            # Initialize llguidance for constraint compilation
            self.llguidance = LLGuidance()

            # Get tokenizer from vLLM
            self.tokenizer = self.llm.get_tokenizer()

            load_time = time.time() - start_time
            logger.info(f"Model loaded successfully in {load_time:.2f}s")

            # Store model metadata
            self.model_info = {
                "name": self.model_name,
                "vocab_size": len(self.tokenizer),
                "load_time_seconds": load_time,
            }

        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise

    def compile_constraints(self, constraints: Dict[str, Any]) -> Any:
        """
        Compile constraint specification to llguidance FSM.

        Args:
            constraints: Constraint specification (ConstraintIR from Braid)
                        Can include JSON schemas, regexes, grammars, etc.

        Returns:
            Compiled constraint object for logit masking
        """
        logger.info("Compiling constraints to FSM")
        start_time = time.time()

        try:
            from llguidance import Grammar, JsonSchema

            constraint_type = constraints.get("type", "json")

            if constraint_type == "json":
                # JSON schema constraint
                schema = constraints.get("schema", {})
                compiled = JsonSchema(schema)

            elif constraint_type == "grammar":
                # Custom grammar (EBNF or similar)
                grammar_spec = constraints.get("grammar", "")
                compiled = Grammar(grammar_spec)

            elif constraint_type == "regex":
                # Regular expression constraint
                pattern = constraints.get("pattern", ".*")
                compiled = Grammar.from_regex(pattern)

            elif constraint_type == "composite":
                # Multiple constraints combined
                sub_constraints = constraints.get("constraints", [])
                compiled_parts = [
                    self.compile_constraints(c) for c in sub_constraints
                ]
                compiled = Grammar.combine(compiled_parts)

            else:
                raise ValueError(f"Unknown constraint type: {constraint_type}")

            compile_time = time.time() - start_time
            logger.info(f"Constraints compiled in {compile_time*1000:.2f}ms")

            return compiled

        except Exception as e:
            logger.error(f"Constraint compilation failed: {e}")
            raise ValueError(f"Invalid constraint specification: {e}")

    @modal.method()
    def generate(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate code with token-level constraint enforcement.

        Args:
            request_data: Dictionary matching GenerationRequest schema

        Returns:
            Dictionary matching GenerationResponse schema
        """
        logger.info("Received generation request")
        request_start = time.time()

        try:
            # Parse request
            request = GenerationRequest(**request_data)

            # Compile constraints to FSM
            if not request.constraints:
                logger.warning("No constraints provided, using unconstrained generation")
                compiled_constraints = None
            else:
                compiled_constraints = self.compile_constraints(request.constraints)

            # Prepare sampling parameters
            from vllm import SamplingParams

            sampling_params = SamplingParams(
                temperature=request.temperature,
                top_p=request.top_p,
                top_k=request.top_k,
                max_tokens=request.max_tokens,
                stop=request.stop_sequences or [],
            )

            # Add constraint enforcement if compiled
            if compiled_constraints:
                # llguidance integration happens here
                # The compiled FSM masks invalid tokens during generation
                sampling_params.logits_processor = [
                    compiled_constraints.create_logits_processor(self.tokenizer)
                ]

            # Generate with constraints
            generation_start = time.time()
            outputs = self.llm.generate(
                prompts=[request.prompt],
                sampling_params=sampling_params,
                use_tqdm=False,
            )
            generation_time = (time.time() - generation_start) * 1000

            # Extract result
            output = outputs[0].outputs[0]
            generated_text = output.text
            tokens_generated = len(output.token_ids)

            # Count constraint violations (should be zero with llguidance)
            violations = 0
            if compiled_constraints:
                try:
                    is_valid = compiled_constraints.validate(generated_text)
                    if not is_valid:
                        violations = 1
                        logger.warning("Generated output violated constraints!")
                except Exception as e:
                    logger.error(f"Constraint validation failed: {e}")
                    violations = -1

            # Build response with provenance
            total_time = (time.time() - request_start) * 1000

            response = GenerationResponse(
                generated_code=generated_text,
                tokens_generated=tokens_generated,
                generation_time_ms=generation_time,
                constraint_violations=violations,
                provenance={
                    "model": self.model_name,
                    "model_info": self.model_info,
                    "timestamp": time.time(),
                    "request_id": request.metadata.get("request_id") if request.metadata else None,
                    "constraints_used": request.constraints.get("type") if request.constraints else None,
                    "total_latency_ms": total_time,
                    "tokens_per_second": tokens_generated / (generation_time / 1000) if generation_time > 0 else 0,
                },
                metadata=request.metadata,
            )

            logger.info(
                f"Generation complete: {tokens_generated} tokens in {generation_time:.2f}ms "
                f"({response.provenance['tokens_per_second']:.1f} tok/s)"
            )

            # Return as dict for JSON serialization
            return {
                "generated_code": response.generated_code,
                "tokens_generated": response.tokens_generated,
                "generation_time_ms": response.generation_time_ms,
                "constraint_violations": response.constraint_violations,
                "provenance": response.provenance,
                "metadata": response.metadata,
            }

        except Exception as e:
            logger.error(f"Generation failed: {e}", exc_info=True)
            return {
                "error": str(e),
                "error_type": type(e).__name__,
                "timestamp": time.time(),
            }

    @modal.method()
    def health_check(self) -> Dict[str, Any]:
        """Health check endpoint."""
        return {
            "status": "healthy",
            "model": self.model_name,
            "model_info": self.model_info,
            "timestamp": time.time(),
        }

    @modal.method()
    def validate_constraints(self, constraints: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate constraint specification without generating.

        Useful for testing constraint compilation before generation.
        """
        try:
            compiled = self.compile_constraints(constraints)
            return {
                "valid": True,
                "constraint_type": constraints.get("type"),
                "message": "Constraints compiled successfully",
            }
        except Exception as e:
            return {
                "valid": False,
                "error": str(e),
                "constraint_type": constraints.get("type"),
            }


@app.local_entrypoint()
def main():
    """
    Local entrypoint for testing the service.

    Run with: modal run modal_inference/inference.py
    """
    # Example constraint: JSON schema for a function
    example_constraints = {
        "type": "json",
        "schema": {
            "type": "object",
            "properties": {
                "function_name": {"type": "string"},
                "parameters": {
                    "type": "array",
                    "items": {"type": "string"}
                },
                "return_type": {"type": "string"},
                "body": {"type": "string"}
            },
            "required": ["function_name", "parameters", "return_type", "body"]
        }
    }

    # Example request
    request = {
        "prompt": "Generate a Python function that validates email addresses:",
        "constraints": example_constraints,
        "max_tokens": 512,
        "temperature": 0.7,
        "metadata": {
            "request_id": "test-001",
            "user": "local-test"
        }
    }

    # Create service instance and generate
    service = InferenceService()
    result = service.generate.remote(request)

    # Print results
    print("\n" + "="*80)
    print("GENERATION RESULT")
    print("="*80)
    print(json.dumps(result, indent=2))
    print("="*80 + "\n")


# Web endpoint for HTTP access
@app.function(
    image=image,
    secrets=[modal.Secret.from_name("huggingface-secret")],
)
@modal.web_endpoint(method="POST")
def generate_endpoint(request: Dict[str, Any]) -> Dict[str, Any]:
    """
    HTTP endpoint for generation requests.

    POST to this endpoint with GenerationRequest JSON.
    """
    service = InferenceService()
    return service.generate.remote(request)
