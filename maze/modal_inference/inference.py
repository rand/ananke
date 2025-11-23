"""
Ananke Modal Inference Service

GPU-based constrained code generation using vLLM 0.11.0 with llguidance.
Provides HTTP API for token-level constraint enforcement during inference.

Architecture:
- Qwen2.5-Coder-32B-Instruct for code generation
- vLLM 0.11.0 with V1 structured outputs API
- llguidance 0.7.11-0.8.0 for grammar-constrained generation
- Modal for serverless scale-to-zero deployment
- A100-80GB GPU with 60s idle timeout
- NVIDIA CUDA 12.8.0 base image with Python 3.12

Based on working maze example at /Users/rand/src/maze/deployment/modal/modal_app.py
"""

import json
import time
import os
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import modal

# Force V0 architecture for full llguidance support
# V1 architecture is 1.7x faster but currently only supports xgrammar backend
# Will switch to V1 once llguidance backend is fully supported
os.environ["VLLM_USE_V1"] = "0"

# Modal app definition
app = modal.App("ananke-inference")

# GPU configuration (use string format per Modal 1.0 API)
GPU_CONFIG = "A100-80GB"  # 80GB for 32B model, use "A100-40GB" for smaller models

# vLLM image with llguidance support - using NVIDIA CUDA base for production
vllm_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.8.0-devel-ubuntu22.04",
        add_python="3.12"
    )
    .pip_install(
        # Core vLLM (let it pull its own dependencies: torch, xformers, transformers, etc.)
        "vllm==0.11.0",

        # llguidance for constraint enforcement
        "llguidance>=0.7.11,<0.8.0",  # CRITICAL: vLLM 0.11.0 requires <0.8.0

        # FastAPI and serving
        "fastapi[standard]>=0.115.0",
        "huggingface-hub>=0.20.0",
        "hf-transfer",
    )
    .env({
        "HF_HUB_ENABLE_HF_TRANSFER": "1",  # Faster model downloads
        "VLLM_USE_V1": "0",  # Force V0 architecture
    })
)


@dataclass
class ConstraintSpec:
    """Constraint specification in llguidance format"""
    json_schema: Optional[Dict[str, Any]] = None
    grammar: Optional[str] = None
    regex_patterns: Optional[List[str]] = None
    token_mask: Optional[Dict[str, List[int]]] = None

    def to_llguidance(self) -> Optional[Dict[str, Any]]:
        """Convert to llguidance constraint format"""
        if self.json_schema:
            return {"type": "json", "schema": self.json_schema}
        elif self.grammar:
            return {"type": "grammar", "grammar": self.grammar}
        elif self.regex_patterns:
            return {"type": "regex", "patterns": self.regex_patterns}
        elif self.token_mask:
            return {"type": "token_mask", **self.token_mask}
        return None


@dataclass
class GenerationRequest:
    """Request for constrained generation"""
    prompt: str
    constraints: Optional[Dict[str, Any]] = None
    max_tokens: int = 2048
    temperature: float = 0.7
    top_p: float = 0.95
    top_k: int = 50
    stop_sequences: Optional[List[str]] = None
    context: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "GenerationRequest":
        return cls(**{k: v for k, v in data.items() if k in cls.__annotations__})


@dataclass
class GenerationResponse:
    """Response from constrained generation"""
    generated_text: str
    tokens_generated: int
    generation_time_ms: int
    constraint_satisfied: bool
    model_name: str
    finish_reason: str
    metadata: Optional[Dict[str, Any]] = None


@app.cls(
    image=vllm_image,
    gpu=GPU_CONFIG,
    timeout=600,  # 10 minute timeout for long generations
    scaledown_window=60,  # Scale to zero after 60s idle
    allow_concurrent_inputs=10,  # Handle multiple requests per container
    volumes={
        # Cache HuggingFace model weights for faster cold starts
        "/root/.cache/huggingface": modal.Volume.from_name(
            "huggingface-cache", create_if_missing=True
        ),
        # Cache vLLM compilation artifacts
        "/root/.cache/vllm": modal.Volume.from_name(
            "vllm-cache", create_if_missing=True
        ),
    },
)
class AnankeLLM:
    """
    Ananke LLM inference service with constrained generation.

    Uses vLLM for fast GPU inference and llguidance for constraint enforcement.
    Scales to zero when idle, cold start ~3-5 seconds.
    """

    model_name: str = "Qwen/Qwen2.5-Coder-32B-Instruct"  # Better code model than Llama

    @modal.enter()
    def initialize_model(self):
        """Initialize vLLM engine with llguidance support on container start"""
        import logging
        from vllm import LLM, SamplingParams
        from vllm.guided_decoding import GuidedDecodingMode

        logger = logging.getLogger(__name__)
        logger.setLevel(logging.INFO)

        start_time = time.time()

        try:
            # Version validation
            import vllm
            import llguidance
            vllm_version = vllm.__version__
            llguidance_version = llguidance.__version__

            logger.info(f"Initializing vLLM {vllm_version} with llguidance {llguidance_version}")
            logger.info(f"Model: {self.model_name}")

            # Check version compatibility (vLLM 0.11.0 requires llguidance <0.8.0)
            if vllm_version != "0.11.0":
                logger.warning(f"vLLM {vllm_version} may have compatibility issues, 0.11.0 recommended")
            if not ("0.7.11" <= llguidance_version < "0.8.0"):
                raise ValueError(f"llguidance {llguidance_version} incompatible with vLLM {vllm_version}, need >=0.7.11,<0.8.0")

            # Initialize vLLM with V1 structured outputs API
            self.llm = LLM(
                model=self.model_name,
                tensor_parallel_size=1,
                gpu_memory_utilization=0.90,
                max_model_len=8192,
                dtype="bfloat16",
                trust_remote_code=True,
                # V1 structured outputs backend - use guidance for llguidance support
                structured_outputs_config={"backend": "guidance"},
            )

            self.tokenizer = self.llm.get_tokenizer()

            init_duration = time.time() - start_time

            logger.info(f"✓ Model loaded in {init_duration:.1f}s")
            logger.info(f"✓ Vocabulary size: {len(self.tokenizer)}")
            logger.info(f"✓ Max model length: 8192 tokens")
            logger.info(f"✓ Backend: llguidance via structured_outputs_config")

        except Exception as e:
            logger.error(f"✗ Model initialization failed: {e}", exc_info=True)
            logger.error(f"vLLM version: {vllm.__version__ if 'vllm' in locals() else 'unknown'}")
            logger.error(f"llguidance version: {llguidance.__version__ if 'llguidance' in locals() else 'unknown'}")
            raise RuntimeError(f"Failed to initialize vLLM: {e}") from e

    @modal.method()
    def generate(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate code with constraints.

        Args:
            request_data: Dictionary containing GenerationRequest fields

        Returns:
            Dictionary containing GenerationResponse fields
        """
        import logging
        import traceback
        import uuid
        from vllm import SamplingParams
        from vllm.sampling_params import StructuredOutputsParams

        logger = logging.getLogger(__name__)
        request_id = request_data.get('request_id', str(uuid.uuid4())[:8])
        start_time = time.time()

        try:
            # Parse and validate request
            try:
                request = GenerationRequest.from_dict(request_data)
            except Exception as e:
                logger.error(f"[{request_id}] Invalid request format: {e}")
                raise ValueError(f"Invalid request format: {e}") from e

            # Build prompt with context if provided
            full_prompt = request.prompt
            if request.context:
                full_prompt = f"{request.context}\n\n{request.prompt}"

            prompt_length = len(self.tokenizer.encode(full_prompt))
            logger.info(f"[{request_id}] Starting generation: prompt_tokens={prompt_length}, max_tokens={request.max_tokens}")

            # Apply constraints if provided (using V1 StructuredOutputsParams API)
            constraint_satisfied = True
            constraint_type_used = None

            if request.constraints:
                try:
                    constraint_spec = ConstraintSpec(**request.constraints)
                    llguidance_constraint = constraint_spec.to_llguidance()

                    if llguidance_constraint:
                        constraint_type = llguidance_constraint["type"]
                        constraint_type_used = constraint_type

                        # Use V1 StructuredOutputsParams API
                        if constraint_type == "json":
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                                structured_outputs=StructuredOutputsParams(
                                    json_schema=llguidance_constraint["schema"]
                                ),
                            )
                            logger.info(f"[{request_id}] Applied JSON schema constraint")
                        elif constraint_type == "grammar":
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                                structured_outputs=StructuredOutputsParams(
                                    grammar=llguidance_constraint["grammar"]
                                ),
                            )
                            logger.info(f"[{request_id}] Applied grammar constraint")
                        elif constraint_type == "regex":
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                                structured_outputs=StructuredOutputsParams(
                                    regex=llguidance_constraint["patterns"][0]
                                ),
                            )
                            logger.info(f"[{request_id}] Applied regex constraint")
                        else:
                            # No constraint support for this type
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                            )
                            logger.warning(f"[{request_id}] Constraint type {constraint_type} not supported")
                    else:
                        # No constraints
                        sampling_params = SamplingParams(
                            max_tokens=request.max_tokens,
                            temperature=request.temperature,
                            top_p=request.top_p,
                            top_k=request.top_k,
                            stop=request.stop_sequences or [],
                        )
                except Exception as e:
                    logger.error(f"[{request_id}] Constraint compilation failed: {e}")
                    # Continue without constraints rather than failing
                    constraint_satisfied = False
                    sampling_params = SamplingParams(
                        max_tokens=request.max_tokens,
                        temperature=request.temperature,
                        top_p=request.top_p,
                        top_k=request.top_k,
                        stop=request.stop_sequences or [],
                    )
            else:
                # No constraints requested
                sampling_params = SamplingParams(
                    max_tokens=request.max_tokens,
                    temperature=request.temperature,
                    top_p=request.top_p,
                    top_k=request.top_k,
                    stop=request.stop_sequences or [],
                )

            # Generate with vLLM
            try:
                outputs = self.llm.generate([full_prompt], sampling_params)
                output = outputs[0]

                generated_text = output.outputs[0].text
                tokens_generated = len(output.outputs[0].token_ids)
                finish_reason = output.outputs[0].finish_reason

                generation_time_ms = int((time.time() - start_time) * 1000)
                tokens_per_sec = (tokens_generated / generation_time_ms) * 1000 if generation_time_ms > 0 else 0

                logger.info(
                    f"[{request_id}] Generation complete: "
                    f"tokens={tokens_generated}, time={generation_time_ms}ms, "
                    f"speed={tokens_per_sec:.1f} tok/s, reason={finish_reason}"
                )

            except Exception as e:
                logger.error(f"[{request_id}] Generation failed: {e}")
                logger.error(f"[{request_id}] Traceback: {traceback.format_exc()}")
                return asdict(GenerationResponse(
                    generated_text="",
                    tokens_generated=0,
                    generation_time_ms=int((time.time() - start_time) * 1000),
                    constraint_satisfied=False,
                    model_name=self.model_name,
                    finish_reason="error",
                    metadata={
                        "error": str(e),
                        "error_type": type(e).__name__,
                        "request_id": request_id,
                    },
                ))

            generation_time_ms = int((time.time() - start_time) * 1000)

            # Build response
            response = GenerationResponse(
                generated_text=generated_text,
                tokens_generated=tokens_generated,
                generation_time_ms=generation_time_ms,
                constraint_satisfied=constraint_satisfied,
                model_name=self.model_name,
                finish_reason=finish_reason,
                metadata={
                    "request_id": request_id,
                    "prompt_tokens": prompt_length,
                    "temperature": request.temperature,
                    "top_p": request.top_p,
                    "constraint_type": constraint_type_used,
                    "tokens_per_sec": (tokens_generated / generation_time_ms) * 1000 if generation_time_ms > 0 else 0,
                },
            )

            return asdict(response)

        except Exception as e:
            logger.error(f"[{request_id}] Unexpected error: {e}")
            logger.error(f"[{request_id}] Traceback: {traceback.format_exc()}")
            return asdict(GenerationResponse(
                generated_text="",
                tokens_generated=0,
                generation_time_ms=int((time.time() - start_time) * 1000),
                constraint_satisfied=False,
                model_name=self.model_name,
                finish_reason="error",
                metadata={
                    "error": str(e),
                    "error_type": type(e).__name__,
                    "request_id": request_id,
                },
            ))

    @modal.method()
    def health_check(self) -> Dict[str, Any]:
        """Health check endpoint"""
        return {
            "status": "healthy",
            "model": self.model_name,
            "backend": "vLLM 0.11.0 + llguidance",
            "gpu": "A100-80GB",
        }


@app.function(
    image=vllm_image,
    timeout=10,
)
@modal.fastapi_endpoint(method="GET")
def health():
    """Public health check endpoint"""
    return {
        "status": "healthy",
        "service": "ananke-inference",
        "version": "1.0.0",
    }


@app.function(
    image=vllm_image,
    timeout=600,  # 10 minute timeout for cold start + generation
)
@modal.fastapi_endpoint(method="POST")
def generate_api(request: Dict[str, Any]) -> Dict[str, Any]:
    """
    HTTP API endpoint for constrained generation.

    POST /generate_api
    {
        "prompt": "Implement secure API handler",
        "constraints": {
            "json_schema": {"type": "object", ...},  // optional
            "grammar": "...",                        // optional
            "regex_patterns": ["..."],               // optional
        },
        "max_tokens": 2048,
        "temperature": 0.7,
        ...
    }

    Returns:
    {
        "generated_text": "...",
        "tokens_generated": 123,
        "generation_time_ms": 4567,
        "constraint_satisfied": true,
        "model_name": "meta-llama/Llama-3.1-8B-Instruct",
        "finish_reason": "stop",
        "metadata": {...}
    }
    """
    # Get Modal reference to the AnankeLLM class and call its generate method
    # Modal handles the lifecycle and caching automatically
    llm = AnankeLLM()
    return llm.generate.remote(request)


# Local development helper
@app.local_entrypoint()
def main():
    """Test the service locally"""
    print("Testing Ananke Inference Service...")

    # Test health check
    print("\n1. Testing health check...")
    health_result = health.remote()
    print(f"Health: {json.dumps(health_result, indent=2)}")

    # Test simple generation
    print("\n2. Testing simple generation...")
    simple_request = {
        "prompt": "Write a Python function to add two numbers:",
        "max_tokens": 100,
        "temperature": 0.7,
    }

    llm = AnankeLLM()
    simple_result = llm.generate.remote(simple_request)
    print(f"Result: {json.dumps(simple_result, indent=2)}")

    # Test constrained generation with JSON schema
    print("\n3. Testing JSON schema constraint...")
    json_request = {
        "prompt": "Generate a user profile:",
        "constraints": {
            "json_schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "age": {"type": "integer"},
                    "email": {"type": "string"},
                },
                "required": ["name", "age"],
            }
        },
        "max_tokens": 100,
        "temperature": 0.7,
    }

    json_result = llm.generate.remote(json_request)
    print(f"Result: {json.dumps(json_result, indent=2)}")

    print("\n✓ All tests completed!")
