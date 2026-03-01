"""
Ananke Modal Inference Service - Qwen3-Coder-30B-A3B Edition

GPU-based constrained code generation using vLLM 0.11.0 with llguidance.
This is a separate endpoint for the Qwen3-Coder-30B-A3B model (MoE architecture).

Model specifications:
- Total Params: 30.5B
- Activated Params: 3.3B (MoE: 128 experts, 8 active per token)
- Context: 256K tokens (extendable to 1M)
- Memory: Much lighter than dense 30B due to sparse activation

Architecture:
- Qwen3-Coder-30B-A3B-Instruct for code generation (MoE)
- vLLM 0.11.0 with V1 structured outputs API
- llguidance 0.7.11-0.8.0 for grammar-constrained generation
- transformers >= 4.51.0 (required for qwen3_moe support)
- Modal for serverless scale-to-zero deployment
- A100-80GB GPU with environment-based idle timeout
"""

import json
import time
import os
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import modal

# Modal app definition - SEPARATE from main inference endpoint
app = modal.App("ananke-qwen3-inference")

# GPU configuration (use string format per Modal 1.0 API)
GPU_CONFIG = "A100-80GB"  # 80GB for MoE model

# Environment-based configuration for cost control
MODAL_MODE = os.getenv("MODAL_MODE", "dev").lower()

if MODAL_MODE == "demo":
    SCALEDOWN_WINDOW = 600  # 10 min for presentations
    print("🎬 DEMO MODE: 10 min scaledown, A100-80GB GPU")
elif MODAL_MODE == "prod":
    SCALEDOWN_WINDOW = 300  # 5 min balanced
    print("🚀 PROD MODE: 5 min scaledown, A100-80GB GPU")
else:
    # Dev mode: aggressive scaledown for cost savings
    SCALEDOWN_WINDOW = 120  # 2 min aggressive
    print("💻 DEV MODE: 2 min scaledown, A100-80GB GPU ($4/hr)")

print(f"Scaledown: {SCALEDOWN_WINDOW}s")
print(f"Model: Qwen3-Coder-30B-A3B (MoE: 128 experts, 8 active)")

# Pinned versions for reproducibility
VLLM_VERSION = "0.11.0"
TRANSFORMERS_VERSION = "4.55.2"  # >= 4.51.0 required for qwen3_moe
FASTAPI_VERSION = "0.115.12"

# Backtracking detection threshold
BACKTRACKING_THRESHOLD_TOKENS_PER_SEC = 5.0

# vLLM image with llguidance support
vllm_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.4.1-devel-ubuntu22.04",
        add_python="3.12"
    )
    .apt_install(
        "git",
        "wget",
        "curl",
        "build-essential",
        "pkg-config",
        "libssl-dev",
    )
    .run_commands(
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
        "echo 'source $HOME/.cargo/env' >> $HOME/.bashrc",
    )
    .uv_pip_install(
        f"vllm=={VLLM_VERSION}",
        f"transformers=={TRANSFORMERS_VERSION}",
        f"fastapi[standard]=={FASTAPI_VERSION}",
        "huggingface-hub>=0.20.0",
        "hf-transfer",
        "flashinfer-python",
    )
    .uv_pip_install(
        "llguidance>=0.7.11,<0.8.0",
    )
    .run_commands(
        'echo "export PATH=/usr/local/cuda/bin:/root/.cargo/bin:$PATH" >> /root/.bashrc',
        'echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/lib" >> /root/.bashrc',
    )
    .env({
        "CUDA_HOME": "/usr/local/cuda",
        "HF_HUB_ENABLE_HF_TRANSFER": "1",
        "PYTORCH_CUDA_ALLOC_CONF": "expandable_segments:True",
        "TOKENIZERS_PARALLELISM": "false",
        "HF_HOME": "/cache/huggingface",
        "TRANSFORMERS_CACHE": "/cache/transformers",
    })
)


@dataclass
class ConstraintSpec:
    """Constraint specification in llguidance format"""
    json_schema: Optional[Dict[str, Any]] = None
    grammar: Optional[str] = None
    regex_patterns: Optional[List[str]] = None
    token_mask: Optional[Dict[str, List[int]]] = None
    min_tokens: Optional[int] = None
    max_tokens: Optional[int] = None
    min_characters: Optional[int] = None
    max_characters: Optional[int] = None

    @classmethod
    def from_eval_format(cls, constraints: Dict[str, Any]) -> "ConstraintSpec":
        """Create ConstraintSpec from eval framework format.

        The eval framework sends constraints in this format:
        {
            "grammar": "...",
            "regex_pattern": "...",
            "llguidance": {"type": "...", "regex": "...", "json_schema": {...}},
            "constraint_type": "...",
            "constraint_count": N
        }

        We need to extract the actual constraint from the llguidance wrapper.
        """
        import json as json_module
        import logging
        logger = logging.getLogger(__name__)

        # If llguidance field exists, extract constraint from it
        if "llguidance" in constraints:
            llg = constraints.get("llguidance", {})

            # Handle string-encoded JSON
            if isinstance(llg, str):
                try:
                    llg = json_module.loads(llg)
                except json_module.JSONDecodeError:
                    llg = {}

            # Extract constraint based on type - order matters!
            # Prefer regex since it's most commonly used and reliable
            if "regex" in llg:
                regex_val = llg["regex"]
                if isinstance(regex_val, str):
                    return cls(regex_patterns=[regex_val])
                logger.warning(f"regex field is not a string: {type(regex_val)}")

            if "json_schema" in llg:
                schema_val = llg["json_schema"]
                if isinstance(schema_val, dict):
                    return cls(json_schema=schema_val)
                logger.warning(f"json_schema field is not a dict: {type(schema_val)}")

            if "grammar" in llg:
                grammar_val = llg["grammar"]
                # vLLM expects grammar as a GBNF/BNF string, not a dict
                if isinstance(grammar_val, str):
                    return cls(grammar=grammar_val)
                # If grammar is a dict (e.g., {'start': 'program'}), it's a
                # placeholder or structured grammar that vLLM can't use directly.
                # Skip grammar constraint in this case - let generation be unconstrained
                logger.warning(f"grammar field is a dict, not a string - skipping: {grammar_val}")

        # Otherwise, try direct fields (standard ConstraintSpec format)
        # Also validate types for direct fields
        grammar_direct = constraints.get("grammar")
        if grammar_direct is not None:
            if not isinstance(grammar_direct, str):
                logger.warning(f"Direct grammar field is not a string: {type(grammar_direct)}")
                grammar_direct = None  # Skip invalid grammar
            elif not cls._is_valid_gbnf_grammar(grammar_direct):
                # The "grammar" field in eval constraints often contains code signatures
                # (like "pub fn parse_config...") not actual GBNF grammar definitions.
                # GBNF grammars must have ::= rules. If it doesn't, it's not a grammar.
                logger.warning(f"Direct grammar field is not GBNF syntax (no ::= rules), skipping: {grammar_direct[:50]}...")
                grammar_direct = None

        return cls(
            json_schema=constraints.get("json_schema"),
            grammar=grammar_direct,
            regex_patterns=constraints.get("regex_patterns"),
            token_mask=constraints.get("token_mask"),
            min_tokens=constraints.get("min_tokens"),
            max_tokens=constraints.get("max_tokens"),
            min_characters=constraints.get("min_characters"),
            max_characters=constraints.get("max_characters"),
        )

    @staticmethod
    def _is_valid_gbnf_grammar(text: str) -> bool:
        """Check if text looks like a valid GBNF grammar definition.

        GBNF grammars must have production rules in the form:
            rule_name ::= expression

        If the text doesn't contain ::=, it's not a GBNF grammar.
        """
        return "::=" in text

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

    def get_length_constraints(self) -> Dict[str, int]:
        """Get length constraints as a dictionary for validation"""
        constraints = {}
        if self.min_tokens is not None:
            constraints["min_tokens"] = self.min_tokens
        if self.max_tokens is not None:
            constraints["max_tokens"] = self.max_tokens
        if self.min_characters is not None:
            constraints["min_characters"] = self.min_characters
        if self.max_characters is not None:
            constraints["max_characters"] = self.max_characters
        return constraints

    def validate_output_length(self, text: str, token_count: int) -> tuple[bool, str]:
        """Validate output meets length constraints. Returns (is_valid, reason)."""
        if self.min_tokens is not None and token_count < self.min_tokens:
            return False, f"Output has {token_count} tokens but minimum is {self.min_tokens}"
        if self.max_tokens is not None and token_count > self.max_tokens:
            return False, f"Output has {token_count} tokens but maximum is {self.max_tokens}"
        if self.min_characters is not None and len(text) < self.min_characters:
            return False, f"Output has {len(text)} characters but minimum is {self.min_characters}"
        if self.max_characters is not None and len(text) > self.max_characters:
            return False, f"Output has {len(text)} characters but maximum is {self.max_characters}"
        return True, ""

    def validate_constraint(self) -> tuple[bool, str]:
        """Pre-flight constraint validation before sending to vLLM."""
        import re

        if self.regex_patterns:
            for pattern in self.regex_patterns:
                trivial_patterns = [".*", r"\w*", ".+", r"\W*", r"\s*", r"\S*",
                                   "[a-z]*", "[A-Z]*", "[a-zA-Z]*", "[0-9]*",
                                   r"\d*", "^$", "^.*$", ".{0,}"]
                if pattern in trivial_patterns:
                    return False, f"Trivial pattern '{pattern}' matches almost anything"

                dangerous_patterns = [
                    r'\(\.\*\)\+',
                    r'\(\.+\)\+',
                    r'\(\\w\*\)\*',
                    r'\(a\|a\)\*',
                    r'\(\.\*\?\)\+',
                    r'\(\.+\?\)\+',
                    r'\(a\+\)\+',
                    r'\(x\+x\+\)\+',
                ]
                for dangerous in dangerous_patterns:
                    if re.search(dangerous, pattern):
                        return False, f"Pattern '{pattern}' may cause catastrophic backtracking"

        if self.json_schema:
            if not isinstance(self.json_schema, dict):
                return False, "json_schema must be a dictionary"
            if "type" not in self.json_schema and "properties" not in self.json_schema:
                return False, "JSON schema must have 'type' or 'properties'"

        return True, ""


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
    timeout=3600,
    scaledown_window=SCALEDOWN_WINDOW,
    allow_concurrent_inputs=8,  # Slightly reduced for MoE stability
    volumes={
        "/cache": modal.Volume.from_name(
            "ananke-qwen3-model-cache", create_if_missing=True
        ),
        "/root/.cache/vllm": modal.Volume.from_name(
            "ananke-qwen3-torch-cache", create_if_missing=True
        ),
    },
)
class Qwen3LLM:
    """
    Qwen3-Coder-30B-A3B inference service with constrained generation.

    Uses MoE architecture (128 experts, 8 active per token) for efficient inference.
    """

    model_name: str = "Qwen/Qwen3-Coder-30B-A3B-Instruct"

    @modal.enter()
    def initialize_model(self):
        """Initialize vLLM engine with llguidance support on container start"""
        import logging
        from vllm import LLM, SamplingParams

        logger = logging.getLogger(__name__)
        logger.setLevel(logging.INFO)

        start_time = time.time()

        try:
            import vllm
            import llguidance
            vllm_version = vllm.__version__

            try:
                llguidance_version = llguidance.__version__
                logger.info(f"Initializing vLLM {vllm_version} with llguidance {llguidance_version}")
            except AttributeError:
                logger.info(f"Initializing vLLM {vllm_version} with llguidance (version unavailable)")
                llguidance_version = None

            logger.info(f"Model: {self.model_name} (MoE: 128 experts, 8 active)")

            if vllm_version != "0.11.0":
                logger.warning(f"vLLM {vllm_version} may have compatibility issues, 0.11.0 recommended")

            # Initialize vLLM with MoE-optimized configuration
            self.llm = LLM(
                model=self.model_name,
                tensor_parallel_size=1,
                gpu_memory_utilization=0.90,
                max_model_len=32768,  # Larger context for MoE (can go up to 256K)
                dtype="bfloat16",
                trust_remote_code=True,
                download_dir="/cache/models",
                structured_outputs_config={"backend": "guidance"},
                enable_prefix_caching=True,  # Better for MoE
            )

            self.tokenizer = self.llm.get_tokenizer()

            init_duration = time.time() - start_time

            logger.info(f"✓ Qwen3-Coder-30B-A3B loaded in {init_duration:.1f}s")
            logger.info(f"✓ Vocabulary size: {len(self.tokenizer)}")
            logger.info(f"✓ Max model length: 32768 tokens")
            logger.info(f"✓ Architecture: MoE (128 experts, 8 active per token)")
            logger.info(f"✓ Backend: llguidance via structured_outputs_config")

        except Exception as e:
            logger.error(f"✗ Model initialization failed: {e}", exc_info=True)
            if 'vllm' in locals():
                try:
                    logger.error(f"vLLM version: {vllm.__version__}")
                except:
                    logger.error("vLLM version: unknown")
            raise RuntimeError(f"Failed to initialize vLLM: {e}") from e

    @modal.method()
    def generate(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate code with constraints."""
        import logging
        import traceback
        import uuid
        from vllm import SamplingParams
        from vllm.sampling_params import StructuredOutputsParams

        logger = logging.getLogger(__name__)
        request_id = request_data.get('request_id', str(uuid.uuid4())[:8])
        start_time = time.time()

        try:
            try:
                request = GenerationRequest.from_dict(request_data)
            except Exception as e:
                logger.error(f"[{request_id}] Invalid request format: {e}")
                raise ValueError(f"Invalid request format: {e}") from e

            full_prompt = request.prompt
            if request.context:
                full_prompt = f"{request.context}\n\n{request.prompt}"

            prompt_length = len(self.tokenizer.encode(full_prompt))
            logger.info(f"[{request_id}] Starting generation: prompt_tokens={prompt_length}, max_tokens={request.max_tokens}")

            constraint_satisfied = True
            constraint_type_used = None
            backtracking_detected = False

            if request.constraints:
                try:
                    # Use from_eval_format to handle both eval framework format
                    # (with llguidance wrapper) and direct ConstraintSpec format
                    constraint_spec = ConstraintSpec.from_eval_format(request.constraints)

                    is_valid, validation_error = constraint_spec.validate_constraint()
                    if not is_valid:
                        logger.error(f"[{request_id}] Constraint validation failed: {validation_error}")
                        return asdict(GenerationResponse(
                            generated_text="",
                            tokens_generated=0,
                            generation_time_ms=int((time.time() - start_time) * 1000),
                            constraint_satisfied=False,
                            model_name=self.model_name,
                            finish_reason="constraint_validation_error",
                            metadata={
                                "error": validation_error,
                                "error_type": "ConstraintValidationError",
                                "request_id": request_id,
                                "constraint_error": True,
                            },
                        ))

                    llguidance_constraint = constraint_spec.to_llguidance()

                    if llguidance_constraint:
                        constraint_type = llguidance_constraint["type"]
                        constraint_type_used = constraint_type

                        if constraint_type == "json":
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                                structured_outputs=StructuredOutputsParams(
                                    json=llguidance_constraint["schema"]
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
                            sampling_params = SamplingParams(
                                max_tokens=request.max_tokens,
                                temperature=request.temperature,
                                top_p=request.top_p,
                                top_k=request.top_k,
                                stop=request.stop_sequences or [],
                            )
                            logger.warning(f"[{request_id}] Constraint type {constraint_type} not supported")
                    else:
                        sampling_params = SamplingParams(
                            max_tokens=request.max_tokens,
                            temperature=request.temperature,
                            top_p=request.top_p,
                            top_k=request.top_k,
                            stop=request.stop_sequences or [],
                        )
                except Exception as e:
                    logger.error(f"[{request_id}] Constraint compilation failed: {e}")
                    logger.error(f"[{request_id}] Traceback: {traceback.format_exc()}")
                    return asdict(GenerationResponse(
                        generated_text="",
                        tokens_generated=0,
                        generation_time_ms=int((time.time() - start_time) * 1000),
                        constraint_satisfied=False,
                        model_name=self.model_name,
                        finish_reason="constraint_compilation_error",
                        metadata={
                            "error": str(e),
                            "error_type": type(e).__name__,
                            "request_id": request_id,
                            "constraint_error": True,
                        },
                    ))
            else:
                sampling_params = SamplingParams(
                    max_tokens=request.max_tokens,
                    temperature=request.temperature,
                    top_p=request.top_p,
                    top_k=request.top_k,
                    stop=request.stop_sequences or [],
                )

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

                backtracking_detected = False
                if constraint_type_used and tokens_generated > 0:
                    if tokens_per_sec < BACKTRACKING_THRESHOLD_TOKENS_PER_SEC:
                        backtracking_detected = True
                        logger.warning(
                            f"[{request_id}] Possible backtracking detected: "
                            f"{tokens_generated} tokens in {generation_time_ms}ms "
                            f"({tokens_per_sec:.1f} tok/s < {BACKTRACKING_THRESHOLD_TOKENS_PER_SEC} threshold)"
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

            length_valid = True
            length_failure_reason = ""
            if request.constraints:
                try:
                    constraint_spec = ConstraintSpec(**request.constraints)
                    length_valid, length_failure_reason = constraint_spec.validate_output_length(
                        generated_text, tokens_generated
                    )
                    if not length_valid:
                        logger.warning(f"[{request_id}] Length constraint violated: {length_failure_reason}")
                        constraint_satisfied = False
                except Exception as e:
                    logger.warning(f"[{request_id}] Failed to validate length constraints: {e}")

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
                    "length_constraint_valid": length_valid,
                    "length_failure_reason": length_failure_reason if length_failure_reason else None,
                    "backtracking_detected": backtracking_detected,
                    "model_architecture": "MoE (128 experts, 8 active)",
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
            "architecture": "MoE (128 experts, 8 active per token)",
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
        "service": "ananke-qwen3-inference",
        "model": "Qwen3-Coder-30B-A3B-Instruct",
        "architecture": "MoE",
        "version": "1.0.0",
    }


@app.function(
    image=vllm_image,
    timeout=3600,
)
@modal.fastapi_endpoint(method="POST")
def generate_api(request: Dict[str, Any]) -> Dict[str, Any]:
    """
    HTTP API endpoint for constrained generation with Qwen3-Coder-30B-A3B.

    Same API as main inference endpoint, but uses Qwen3 MoE model.
    """
    llm = Qwen3LLM()
    return llm.generate.remote(request)


# ============================================================================
# Eval Framework Endpoints
# These endpoints match the API contract expected by eval/core/modal_client.zig
# ============================================================================

@app.cls(
    image=vllm_image,
    gpu=GPU_CONFIG,
    timeout=3600,
    scaledown_window=SCALEDOWN_WINDOW,
    allow_concurrent_inputs=8,
    volumes={
        "/cache": modal.Volume.from_name(
            "ananke-qwen3-model-cache", create_if_missing=True
        ),
        "/root/.cache/vllm": modal.Volume.from_name(
            "ananke-qwen3-torch-cache", create_if_missing=True
        ),
    },
)
class Svc:
    """
    Eval-compatible inference service with /generate/constrained and /generate/unconstrained endpoints.
    Uses the same Qwen3-Coder-30B-A3B model as Qwen3LLM.
    """

    model_name: str = "Qwen/Qwen3-Coder-30B-A3B-Instruct"

    @modal.enter()
    def initialize_model(self):
        """Initialize vLLM engine with llguidance support on container start"""
        import logging
        from vllm import LLM, SamplingParams

        logger = logging.getLogger(__name__)
        logger.setLevel(logging.INFO)

        start_time = time.time()

        try:
            import vllm
            vllm_version = vllm.__version__
            logger.info(f"Initializing vLLM {vllm_version} for eval service")
            logger.info(f"Model: {self.model_name} (MoE: 128 experts, 8 active)")

            self.llm = LLM(
                model=self.model_name,
                tensor_parallel_size=1,
                gpu_memory_utilization=0.90,
                max_model_len=32768,
                dtype="bfloat16",
                trust_remote_code=True,
                download_dir="/cache/models",
                structured_outputs_config={"backend": "guidance"},
                enable_prefix_caching=True,
            )

            self.tokenizer = self.llm.get_tokenizer()

            init_duration = time.time() - start_time
            logger.info(f"✓ Qwen3-Coder-30B-A3B loaded in {init_duration:.1f}s")

            # Default sampling params
            self.default_params = SamplingParams(
                temperature=0.2,
                top_p=0.95,
                max_tokens=2048,
                stop=["```\n", "\n\n\n"],
            )

        except Exception as e:
            logger.error(f"✗ Model initialization failed: {e}", exc_info=True)
            raise RuntimeError(f"Failed to initialize vLLM: {e}") from e

    def _build_constrained_prompt(self, task_description: str, constraints: Dict[str, Any]) -> str:
        """Build prompt for constrained generation."""
        prompt = f"""You are an expert programmer. Implement the following:

{task_description}
"""
        grammar = constraints.get("grammar")
        if grammar and isinstance(grammar, str):
            try:
                json.loads(grammar)
            except (ValueError, json.JSONDecodeError):
                prompt += f"""
REQUIRED SIGNATURE:
{grammar}

You MUST use this exact signature in your implementation.
"""

        prompt += """
Generate ONLY the code implementation. Do not include explanations or markdown code blocks.
"""
        return prompt

    def _build_unconstrained_prompt(self, task_description: str, few_shot_examples: List[Dict[str, str]]) -> str:
        """Build prompt for unconstrained baseline generation."""
        prompt = """You are an expert programmer. Study the following examples, then implement the requested function.

EXAMPLES:
"""
        for i, example in enumerate(few_shot_examples, 1):
            prompt += f"\nExample {i}:\nTask: {example['prompt']}\n\n{example['code']}\n"

        prompt += f"""
NOW IMPLEMENT:
{task_description}

Generate ONLY the code implementation. Do not include explanations or markdown code blocks.
Output the code directly without any wrapper.
"""
        return prompt

    def _extract_code(self, response: str) -> str:
        """Extract code from model response."""
        import re

        response = response.strip()

        # Strategy 1: Look for markdown code blocks
        code_block_pattern = r"```(?:typescript|ts|javascript|js|python|rust|go|zig|c|cpp|java)?\s*\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()

        # Strategy 2: If response starts with ```, extract until closing
        if response.startswith("```"):
            lines = response.split("\n")
            lines = lines[1:]
            for i, line in enumerate(lines):
                if line.strip() == "```":
                    return "\n".join(lines[:i]).strip()
            return "\n".join(lines).strip()

        # Strategy 3: Look for code start patterns
        code_start_patterns = [
            r'^(export\s+)', r'^(function\s+)', r'^(class\s+)',
            r'^(const\s+)', r'^(interface\s+)', r'^(type\s+)',
            r'^(def\s+)', r'^(fn\s+)', r'^(pub\s+)', r'^(impl\s+)',
        ]
        for pattern in code_start_patterns:
            match = re.search(pattern, response, re.MULTILINE)
            if match:
                code_start = match.start()
                code = response[code_start:]
                if "```" in code:
                    code = code[:code.index("```")]
                return code.strip()

        # Strategy 4: Return as-is
        if response.endswith("```"):
            response = response[:-3].strip()
        return response.strip()

    def _generate_constrained_internal(
        self, prompt: str, constraints: Dict[str, Any], model: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate code with constraints."""
        from vllm import SamplingParams
        from vllm.sampling_params import StructuredOutputsParams

        start_time = time.time()

        # Handle nested constraints structure
        if "constraints" in constraints and isinstance(constraints.get("constraints"), dict):
            constraints = constraints["constraints"]

        full_prompt = self._build_constrained_prompt(prompt, constraints)

        structured_outputs = None
        constraint_type_used = None

        if "llguidance" in constraints:
            llguidance = constraints.get("llguidance", {})
            constraint_type_used = constraints.get("constraint_type", "unknown")

            if isinstance(llguidance, str):
                try:
                    llguidance = json.loads(llguidance)
                except (ValueError, json.JSONDecodeError):
                    llguidance = {}

            if "regex" in llguidance:
                structured_outputs = StructuredOutputsParams(regex=llguidance["regex"])
                constraint_type_used = "regex"
            elif "json_schema" in llguidance:
                structured_outputs = StructuredOutputsParams(json=llguidance["json_schema"])
                constraint_type_used = "json_schema"
        else:
            grammar = constraints.get("grammar")
            regex_pattern = constraints.get("regex_pattern")

            if regex_pattern:
                structured_outputs = StructuredOutputsParams(regex=regex_pattern)
                constraint_type_used = "regex"
            elif grammar:
                if isinstance(grammar, dict):
                    structured_outputs = StructuredOutputsParams(json=grammar)
                    constraint_type_used = "json_schema"
                elif isinstance(grammar, str):
                    try:
                        parsed = json.loads(grammar)
                        structured_outputs = StructuredOutputsParams(json=parsed)
                        constraint_type_used = "json_schema"
                    except (ValueError, json.JSONDecodeError):
                        constraint_type_used = "prompt_enforced"

        sampling_params = SamplingParams(
            temperature=self.default_params.temperature,
            top_p=self.default_params.top_p,
            max_tokens=self.default_params.max_tokens,
            stop=self.default_params.stop,
            structured_outputs=structured_outputs,
        )

        try:
            outputs = self.llm.generate([full_prompt], sampling_params)
            generated_text = outputs[0].outputs[0].text
            code = self._extract_code(generated_text)

            generation_time_ms = int((time.time() - start_time) * 1000)
            tokens_generated = len(outputs[0].outputs[0].token_ids)

            return {
                "code": code,
                "metadata": {
                    "tokens_generated": tokens_generated,
                    "generation_time_ms": generation_time_ms,
                    "model": model or self.model_name,
                    "constrained": True,
                    "constraint_type": constraint_type_used,
                },
            }
        except Exception as e:
            return {
                "code": f"// Error: {str(e)}",
                "metadata": {
                    "error": str(e),
                    "generation_time_ms": int((time.time() - start_time) * 1000),
                },
            }

    def _generate_unconstrained_internal(
        self,
        prompt: str,
        few_shot_examples: List[Dict[str, str]],
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Generate code with few-shot examples (baseline)."""
        start_time = time.time()
        full_prompt = self._build_unconstrained_prompt(prompt, few_shot_examples)

        try:
            outputs = self.llm.generate([full_prompt], self.default_params)
            generated_text = outputs[0].outputs[0].text
            code = self._extract_code(generated_text)

            generation_time_ms = int((time.time() - start_time) * 1000)
            tokens_generated = len(outputs[0].outputs[0].token_ids)

            return {
                "code": code,
                "metadata": {
                    "tokens_generated": tokens_generated,
                    "generation_time_ms": generation_time_ms,
                    "model": model or self.model_name,
                },
            }
        except Exception as e:
            return {
                "code": f"// Error: {str(e)}",
                "metadata": {
                    "error": str(e),
                    "generation_time_ms": int((time.time() - start_time) * 1000),
                },
            }

    @modal.asgi_app()
    def fastapi_app(self):
        """FastAPI app with eval-compatible endpoints."""
        from fastapi import FastAPI

        web_app = FastAPI(
            title="Ananke Qwen3 Eval Inference API",
            description="Constrained vs unconstrained code generation with Qwen3-Coder-30B-A3B",
            version="1.0.0",
        )

        @web_app.get("/")
        def root():
            return {
                "service": "Ananke Qwen3 Eval Inference",
                "model": self.model_name,
                "backend": f"vLLM {VLLM_VERSION} + llguidance",
                "endpoints": {
                    "health": "GET /health",
                    "constrained": "POST /generate/constrained",
                    "unconstrained": "POST /generate/unconstrained",
                }
            }

        @web_app.get("/health")
        def health():
            return {
                "status": "healthy",
                "model": self.model_name,
                "backend": f"vLLM {VLLM_VERSION} + llguidance",
                "gpu": GPU_CONFIG,
            }

        @web_app.post("/generate/constrained")
        def generate_constrained_handler(request: dict):
            """Generate code with constraints."""
            return self._generate_constrained_internal(
                prompt=request.get("prompt", ""),
                constraints=request.get("constraints", {}),
                model=request.get("model"),
            )

        @web_app.post("/generate/unconstrained")
        def generate_unconstrained_handler(request: dict):
            """Generate code with few-shot examples."""
            return self._generate_unconstrained_internal(
                prompt=request.get("prompt", ""),
                few_shot_examples=request.get("few_shot_examples", []),
                model=request.get("model"),
            )

        return web_app


@app.local_entrypoint()
def main():
    """Test the Qwen3 service locally"""
    print("Testing Ananke Qwen3-Coder-30B-A3B Inference Service...")
    print("Model: Qwen3-Coder-30B-A3B (MoE: 128 experts, 8 active)")

    print("\n1. Testing health check...")
    health_result = health.remote()
    print(f"Health: {json.dumps(health_result, indent=2)}")

    print("\n2. Testing simple generation...")
    simple_request = {
        "prompt": "Write a Python function to add two numbers:",
        "max_tokens": 100,
        "temperature": 0.7,
    }

    llm = Qwen3LLM()
    simple_result = llm.generate.remote(simple_request)
    print(f"Result: {json.dumps(simple_result, indent=2)}")

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

    print("\n✓ All Qwen3 tests completed!")
