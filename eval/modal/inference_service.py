"""
Modal inference service for Ananke evaluation framework.

Based on working patterns from:
- maze/deployment/modal/modal_app.py (structured_outputs_config + @modal.asgi_app)
- lift-sys/lift_sys/inference/modal_qwen_vllm.py (GuidedDecodingParams pattern)

Provides two endpoints for A/B comparison:
- /generate/constrained: Code generation with Ananke constraints (JSON schema)
- /generate/unconstrained: Baseline code generation with few-shot examples
"""

import modal
import os
import time
import json
from typing import Optional, Dict, Any, List

# Modal app definition
app = modal.App("ananke-eval-inference")

# Model configuration
MODEL_NAME = "Qwen/Qwen2.5-Coder-32B-Instruct"
MODEL_REVISION = "main"
GPU_CONFIG = "H100"  # H100 80GB for 32B model

# Environment-based configuration for cost control
MODAL_MODE = os.getenv("MODAL_MODE", "dev").lower()
if MODAL_MODE == "prod":
    SCALEDOWN_WINDOW = 180  # 3 min for production
elif MODAL_MODE == "demo":
    SCALEDOWN_WINDOW = 300  # 5 min for demos
else:
    SCALEDOWN_WINDOW = 60  # 1 min for dev (aggressive cost savings)

# Pinned versions (from working maze config)
VLLM_VERSION = "0.11.0"
TRANSFORMERS_VERSION = "4.55.2"
FASTAPI_VERSION = "0.115.12"

# vLLM image with llguidance support (from maze pattern)
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


@app.cls(
    image=vllm_image,
    gpu=GPU_CONFIG,
    timeout=3600,
    scaledown_window=SCALEDOWN_WINDOW,
    volumes={
        "/cache": modal.Volume.from_name("ananke-model-cache", create_if_missing=True),
        "/root/.cache/vllm": modal.Volume.from_name("ananke-torch-cache", create_if_missing=True),
    },
)
class InferenceService:
    """vLLM inference service with llguidance for JSON schema-constrained generation."""

    @modal.enter()
    def load_model(self):
        """Load the model on container startup."""
        from vllm import LLM, SamplingParams
        import torch
        import logging

        logger = logging.getLogger(__name__)
        logger.setLevel(logging.INFO)
        start_time = time.time()

        print("=" * 60)
        print(f"Loading {MODEL_NAME} with llguidance...")
        print("=" * 60)

        if torch.cuda.is_available():
            print(f"GPU: {torch.cuda.get_device_name(0)}")
            print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

        # Initialize vLLM with V1 structured outputs API (maze pattern)
        self.llm = LLM(
            model=MODEL_NAME,
            revision=MODEL_REVISION,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.90,
            max_model_len=8192,
            dtype="bfloat16",
            trust_remote_code=True,
            download_dir="/cache/models",
            # V1 structured outputs backend - use guidance for llguidance
            structured_outputs_config={"backend": "guidance"},
        )

        self.tokenizer = self.llm.get_tokenizer()

        init_duration = time.time() - start_time
        print(f"Model loaded in {init_duration:.1f}s")

        # Memory stats
        allocated = torch.cuda.memory_allocated() / 1e9
        reserved = torch.cuda.memory_reserved() / 1e9
        print(f"Memory allocated: {allocated:.2f} GB")
        print(f"Memory reserved: {reserved:.2f} GB")
        print("=" * 60)

        # Default sampling params
        self.default_params = SamplingParams(
            temperature=0.2,
            top_p=0.95,
            max_tokens=2048,
            stop=["```\n", "\n\n\n"],
        )

    def _build_constrained_prompt(
        self, task_description: str, constraints: Dict[str, Any]
    ) -> str:
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

    def _build_unconstrained_prompt(
        self, task_description: str, few_shot_examples: List[Dict[str, str]]
    ) -> str:
        """Build prompt for unconstrained baseline generation.

        IMPORTANT: This prompt must be equivalent to the constrained prompt
        to ensure a fair comparison. Both should request bare code without
        markdown wrapping.
        """
        prompt = """You are an expert programmer. Study the following examples, then implement the requested function.

EXAMPLES:
"""
        # Show examples as bare code (no markdown) to match expected output format
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
        """Extract code from model response.

        Handles multiple formats:
        1. Bare code (preferred)
        2. Single markdown code block
        3. Multiple code blocks (takes the first complete one)
        4. Code with explanatory text before/after
        """
        import re

        response = response.strip()

        # Strategy 1: Look for markdown code blocks and extract the FIRST one
        # This prevents concatenation of multiple implementations
        code_block_pattern = r"```(?:typescript|ts|javascript|js)?\s*\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            # Return only the FIRST code block to avoid duplicates
            return matches[0].strip()

        # Strategy 2: If response starts with ```, extract until closing
        if response.startswith("```"):
            lines = response.split("\n")
            # Skip first line (```typescript or ```)
            lines = lines[1:]
            # Find the closing ```
            for i, line in enumerate(lines):
                if line.strip() == "```":
                    return "\n".join(lines[:i]).strip()
            # No closing found, return everything after first line
            return "\n".join(lines).strip()

        # Strategy 3: Look for code that starts with common patterns
        # (export, function, class, const, etc.) and extract from there
        code_start_patterns = [
            r'^(export\s+)',
            r'^(function\s+)',
            r'^(class\s+)',
            r'^(const\s+)',
            r'^(interface\s+)',
            r'^(type\s+)',
        ]
        for pattern in code_start_patterns:
            match = re.search(pattern, response, re.MULTILINE)
            if match:
                # Extract from the start of code to end, removing trailing markdown
                code_start = match.start()
                code = response[code_start:]
                # Remove any trailing ``` or explanatory text
                if "```" in code:
                    code = code[:code.index("```")]
                return code.strip()

        # Strategy 4: Return as-is, stripping obvious markdown artifacts
        response = response.strip()
        if response.endswith("```"):
            response = response[:-3].strip()
        if response.startswith("```typescript"):
            response = response[13:].strip()
        elif response.startswith("```ts"):
            response = response[5:].strip()
        elif response.startswith("```"):
            response = response[3:].strip()

        return response.strip()

    def _generate_constrained_internal(
        self, prompt: str, constraints: Dict[str, Any], model: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate code with constraints using StructuredOutputsParams API.

        Supports two constraint formats:
        1. Compiled (from Ananke evaluator): {"llguidance": {...}, "constraint_type": "...", ...}
        2. Raw (legacy): {"grammar": "...", "regex_pattern": "...", ...}
        """
        from vllm import SamplingParams
        from vllm.sampling_params import StructuredOutputsParams

        start_time = time.time()

        # Handle nested constraints structure from eval framework
        # Input may be: {"task_id": "...", "constraints": {...}} or just {...}
        if "constraints" in constraints and isinstance(constraints.get("constraints"), dict):
            constraints = constraints["constraints"]

        full_prompt = self._build_constrained_prompt(prompt, constraints)

        # Check if constraints are pre-compiled (from Ananke constraint compiler)
        structured_outputs = None
        constraint_type_used = None
        grammar = constraints.get("grammar")  # May be set in llguidance or legacy format

        if "llguidance" in constraints:
            # Pre-compiled constraints from Ananke evaluator
            llguidance = constraints.get("llguidance", {})
            constraint_type_used = constraints.get("constraint_type", "unknown")

            if isinstance(llguidance, str):
                try:
                    llguidance = json.loads(llguidance)
                except (ValueError, json.JSONDecodeError):
                    llguidance = {}

            # Extract constraint from llguidance format
            if "regex" in llguidance:
                structured_outputs = StructuredOutputsParams(regex=llguidance["regex"])
                constraint_type_used = "regex"
            elif "json_schema" in llguidance:
                structured_outputs = StructuredOutputsParams(json=llguidance["json_schema"])
                constraint_type_used = "json_schema"
            # prompt_only mode: no structured outputs, just prompt engineering
        else:
            # Legacy raw constraint format
            # Priority order: regex_pattern > json_schema > grammar string
            grammar = constraints.get("grammar")
            regex_pattern = constraints.get("regex_pattern")

            if regex_pattern:
                # Use regex pattern for token-level enforcement (most reliable for code)
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
                        # TypeScript signature - fall back to prompt enforcement
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
                    "model": model or MODEL_NAME,
                    "constrained": bool(grammar),
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
                    "model": model or MODEL_NAME,
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

    @modal.method()
    def generate_constrained(
        self, prompt: str, constraints: Dict[str, Any], model: Optional[str] = None
    ) -> Dict[str, Any]:
        """Modal method for constrained generation."""
        return self._generate_constrained_internal(prompt, constraints, model)

    @modal.method()
    def generate_unconstrained(
        self,
        prompt: str,
        few_shot_examples: List[Dict[str, str]],
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Modal method for unconstrained generation."""
        return self._generate_unconstrained_internal(prompt, few_shot_examples, model)

    @modal.method()
    def health_check(self) -> Dict[str, Any]:
        """Health check with model info."""
        return {
            "status": "healthy",
            "model": MODEL_NAME,
            "backend": f"vLLM {VLLM_VERSION} + llguidance",
            "gpu": GPU_CONFIG,
        }

    @modal.asgi_app()
    def fastapi_app(self):
        """FastAPI app with all endpoints (maze pattern)."""
        from fastapi import FastAPI

        web_app = FastAPI(
            title="Ananke Eval Inference API",
            description="Constrained vs unconstrained code generation for efficacy study",
            version="2.0.0",
        )

        @web_app.get("/")
        def root():
            return {
                "service": "Ananke Eval Inference",
                "model": MODEL_NAME,
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
                "model": MODEL_NAME,
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


# Local testing
@app.local_entrypoint()
def main():
    """Test the service locally."""
    print("Testing Ananke Eval Inference Service...")

    service = InferenceService()

    # Test constrained generation
    print("\n1. Testing constrained generation...")
    result = service.generate_constrained.remote(
        prompt="Write a TypeScript function to add two numbers",
        constraints={"grammar": "function add(a: number, b: number): number"},
    )
    print(f"Result: {json.dumps(result, indent=2)}")

    # Test unconstrained generation
    print("\n2. Testing unconstrained generation...")
    result = service.generate_unconstrained.remote(
        prompt="Write a TypeScript function to add two numbers",
        few_shot_examples=[
            {"prompt": "multiply two numbers", "code": "function multiply(a: number, b: number): number { return a * b; }"}
        ],
    )
    print(f"Result: {json.dumps(result, indent=2)}")

    print("\nAll tests completed!")
