"""
Python client for Ananke Modal Inference Service

Provides a simple interface for making requests to the deployed Modal service.
Handles retries, timeouts, and error handling.
"""

import json
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


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

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "GenerationResponse":
        return cls(**{k: v for k, v in data.items() if k in cls.__annotations__})


class AnankeClient:
    """
    Client for Ananke Modal Inference Service.

    Features:
    - Automatic retries with exponential backoff
    - Request/response validation
    - Timeout handling
    - Error context

    Example:
        client = AnankeClient("https://your-app.modal.run")

        response = client.generate(
            prompt="Implement secure API handler",
            constraints={"json_schema": {...}},
            max_tokens=2048,
        )

        print(f"Generated: {response.generated_text}")
    """

    def __init__(
        self,
        base_url: str,
        api_key: Optional[str] = None,
        timeout: int = 300,
        max_retries: int = 3,
    ):
        """
        Initialize Ananke client.

        Args:
            base_url: Modal service URL (e.g., https://your-app.modal.run)
            api_key: Optional API key for authentication
            timeout: Request timeout in seconds (default: 300)
            max_retries: Maximum number of retries (default: 3)
        """
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout

        # Configure session with retries
        self.session = requests.Session()

        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=2,  # 2s, 4s, 8s delays
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["POST", "GET"],
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)

        # Set headers
        self.session.headers.update({
            "Content-Type": "application/json",
            "User-Agent": "ananke-client/1.0.0",
        })

        if api_key:
            self.session.headers.update({
                "Authorization": f"Bearer {api_key}",
            })

    def health_check(self) -> Dict[str, Any]:
        """
        Check service health.

        Returns:
            Health status dictionary

        Raises:
            requests.RequestException: If health check fails
        """
        response = self.session.get(
            f"{self.base_url}/health",
            timeout=10,
        )
        response.raise_for_status()
        return response.json()

    def generate(
        self,
        prompt: str,
        constraints: Optional[Dict[str, Any]] = None,
        max_tokens: int = 2048,
        temperature: float = 0.7,
        top_p: float = 0.95,
        top_k: int = 50,
        stop_sequences: Optional[List[str]] = None,
        context: Optional[str] = None,
    ) -> GenerationResponse:
        """
        Generate code with constraints.

        Args:
            prompt: The generation prompt
            constraints: Optional constraint specification
            max_tokens: Maximum tokens to generate (default: 2048)
            temperature: Sampling temperature (default: 0.7)
            top_p: Nucleus sampling threshold (default: 0.95)
            top_k: Top-k sampling parameter (default: 50)
            stop_sequences: Optional stop sequences
            context: Optional context to prepend to prompt

        Returns:
            GenerationResponse with generated text and metadata

        Raises:
            requests.RequestException: If generation fails
            ValueError: If response is invalid
        """
        request = GenerationRequest(
            prompt=prompt,
            constraints=constraints,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            stop_sequences=stop_sequences,
            context=context,
        )

        start_time = time.time()

        try:
            response = self.session.post(
                f"{self.base_url}/generate_api",
                json=asdict(request),
                timeout=self.timeout,
            )
            response.raise_for_status()

        except requests.exceptions.Timeout:
            raise TimeoutError(
                f"Generation timed out after {self.timeout}s. "
                "Try reducing max_tokens or increasing timeout."
            )

        except requests.exceptions.RequestException as e:
            raise RuntimeError(
                f"Generation request failed: {e}\n"
                f"URL: {self.base_url}\n"
                f"Status: {getattr(e.response, 'status_code', 'N/A')}"
            ) from e

        total_time = int((time.time() - start_time) * 1000)

        try:
            result_data = response.json()
            result = GenerationResponse.from_dict(result_data)

        except (json.JSONDecodeError, KeyError, TypeError) as e:
            raise ValueError(
                f"Invalid response format: {e}\n"
                f"Response: {response.text[:500]}"
            ) from e

        return result

    def generate_batch(
        self,
        prompts: List[str],
        constraints: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> List[GenerationResponse]:
        """
        Generate multiple prompts in parallel.

        Args:
            prompts: List of prompts to generate
            constraints: Shared constraints for all prompts
            **kwargs: Additional generation parameters

        Returns:
            List of GenerationResponse objects
        """
        # Note: Modal handles concurrent requests automatically
        # This is a simple sequential implementation
        # For true parallelism, use asyncio or threading
        results = []

        for prompt in prompts:
            try:
                result = self.generate(
                    prompt=prompt,
                    constraints=constraints,
                    **kwargs,
                )
                results.append(result)

            except Exception as e:
                print(f"Error generating prompt '{prompt[:50]}...': {e}")
                # Add empty result to maintain order
                results.append(GenerationResponse(
                    generated_text="",
                    tokens_generated=0,
                    generation_time_ms=0,
                    constraint_satisfied=False,
                    model_name="unknown",
                    finish_reason="error",
                    metadata={"error": str(e)},
                ))

        return results

    def close(self):
        """Close the session"""
        self.session.close()

    def __enter__(self):
        """Context manager entry"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


# Example usage and testing
def main():
    """Example client usage"""
    import os
    import sys

    # Get service URL from environment or command line
    service_url = os.environ.get("MODAL_ENDPOINT")
    if not service_url and len(sys.argv) > 1:
        service_url = sys.argv[1]

    if not service_url:
        print("Error: MODAL_ENDPOINT not set")
        print("Usage: python client.py <service_url>")
        print("   or: MODAL_ENDPOINT=<url> python client.py")
        sys.exit(1)

    print(f"Connecting to: {service_url}")

    # Create client
    with AnankeClient(service_url) as client:
        # Test health check
        print("\n1. Testing health check...")
        try:
            health = client.health_check()
            print(f"✓ Service healthy: {json.dumps(health, indent=2)}")
        except Exception as e:
            print(f"✗ Health check failed: {e}")
            sys.exit(1)

        # Test simple generation
        print("\n2. Testing simple generation...")
        try:
            response = client.generate(
                prompt="Write a Python function to add two numbers:",
                max_tokens=100,
                temperature=0.7,
            )
            print(f"✓ Generated {response.tokens_generated} tokens in {response.generation_time_ms}ms")
            print(f"Result:\n{response.generated_text}\n")
        except Exception as e:
            print(f"✗ Simple generation failed: {e}")

        # Test constrained generation
        print("\n3. Testing JSON schema constraint...")
        try:
            response = client.generate(
                prompt="Generate a user profile:",
                constraints={
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
                max_tokens=100,
                temperature=0.7,
            )
            print(f"✓ Generated {response.tokens_generated} tokens in {response.generation_time_ms}ms")
            print(f"Constraint satisfied: {response.constraint_satisfied}")
            print(f"Result:\n{response.generated_text}\n")
        except Exception as e:
            print(f"✗ Constrained generation failed: {e}")

        print("\n✓ All tests completed!")


if __name__ == "__main__":
    main()
