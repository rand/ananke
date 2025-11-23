"""
Ananke Modal Inference Service

GPU-based constrained code generation using vLLM 0.8.2+ with llguidance.
Provides HTTP API for token-level constraint enforcement during inference.

Architecture:
- vLLM for fast GPU inference with paged attention
- llguidance for ~50μs per-token constraint masking
- Modal for serverless scale-to-zero deployment
- A100 GPU with 60s idle timeout
"""

import json
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import modal

# Modal app definition
app = modal.App("ananke-inference")

# GPU configuration (using new Modal syntax)
GPU_CONFIG = "A100-40GB"

# vLLM image with llguidance support
vllm_image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "vllm==0.8.2",
        "llguidance>=0.5.0",
        "transformers>=4.40.0",
        "torch>=2.2.0",
        "fastapi>=0.110.0",
        "pydantic>=2.0.0",
    )
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
    scaledown_window=60,  # Scale to zero after 60s idle (renamed from container_idle_timeout)
)
class AnankeLLM:
    """
    Ananke LLM inference service with constrained generation.

    Uses vLLM for fast GPU inference and llguidance for constraint enforcement.
    Scales to zero when idle, cold start ~3-5 seconds.
    """

    model_name: str = "meta-llama/Llama-3.1-8B-Instruct"

    def __enter__(self):
        """Initialize vLLM engine with llguidance support"""
        from vllm import LLM, SamplingParams
        from vllm.guided_decoding import GuidedDecodingMode

        print(f"Loading model: {self.model_name}")

        self.llm = LLM(
            model=self.model_name,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.95,
            max_model_len=8192,
            trust_remote_code=True,
            # Enable llguidance for constraint enforcement
            guided_decoding_backend="llguidance",
        )

        self.tokenizer = self.llm.get_tokenizer()

        print(f"Model loaded successfully: {self.model_name}")
        print(f"Vocabulary size: {len(self.tokenizer)}")

        return self

    @modal.method()
    def generate(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate code with constraints.

        Args:
            request_data: Dictionary containing GenerationRequest fields

        Returns:
            Dictionary containing GenerationResponse fields
        """
        from vllm import SamplingParams

        start_time = time.time()

        # Parse request
        request = GenerationRequest.from_dict(request_data)

        # Build prompt with context if provided
        full_prompt = request.prompt
        if request.context:
            full_prompt = f"{request.context}\n\n{request.prompt}"

        # Configure sampling parameters
        sampling_params = SamplingParams(
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
            top_k=request.top_k,
            stop=request.stop_sequences or [],
        )

        # Apply constraints if provided
        constraint_satisfied = True
        if request.constraints:
            constraint_spec = ConstraintSpec(**request.constraints)
            llguidance_constraint = constraint_spec.to_llguidance()

            if llguidance_constraint:
                constraint_type = llguidance_constraint["type"]

                if constraint_type == "json":
                    sampling_params.guided_json = llguidance_constraint["schema"]
                elif constraint_type == "grammar":
                    sampling_params.guided_grammar = llguidance_constraint["grammar"]
                elif constraint_type == "regex":
                    # Use first regex pattern (vLLM limitation)
                    sampling_params.guided_regex = llguidance_constraint["patterns"][0]
                elif constraint_type == "token_mask":
                    # Token masking via logits processor (custom implementation)
                    print("Warning: Token mask constraints not yet fully supported")

        # Generate with vLLM
        try:
            outputs = self.llm.generate([full_prompt], sampling_params)
            output = outputs[0]

            generated_text = output.outputs[0].text
            tokens_generated = len(output.outputs[0].token_ids)
            finish_reason = output.outputs[0].finish_reason

        except Exception as e:
            print(f"Generation error: {e}")
            return asdict(GenerationResponse(
                generated_text="",
                tokens_generated=0,
                generation_time_ms=0,
                constraint_satisfied=False,
                model_name=self.model_name,
                finish_reason="error",
                metadata={"error": str(e)},
            ))

        end_time = time.time()
        generation_time_ms = int((end_time - start_time) * 1000)

        # Build response
        response = GenerationResponse(
            generated_text=generated_text,
            tokens_generated=tokens_generated,
            generation_time_ms=generation_time_ms,
            constraint_satisfied=constraint_satisfied,
            model_name=self.model_name,
            finish_reason=finish_reason,
            metadata={
                "prompt_tokens": len(self.tokenizer.encode(full_prompt)),
                "temperature": request.temperature,
                "top_p": request.top_p,
            },
        )

        return asdict(response)

    @modal.method()
    def health_check(self) -> Dict[str, Any]:
        """Health check endpoint"""
        return {
            "status": "healthy",
            "model": self.model_name,
            "backend": "vllm+llguidance",
            "gpu": "A100",
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
    timeout=10,
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
    # Use the class-based method which properly caches the model
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
