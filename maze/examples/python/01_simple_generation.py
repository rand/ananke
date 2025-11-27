#!/usr/bin/env python3
"""
Example 1: Simple Unconstrained Generation

Demonstrates basic usage of Ananke for simple code generation
without constraints.
"""

import asyncio
import os
from ananke import Ananke, PyGenerationRequest, PyGenerationContext


async def main():
    # Initialize Ananke from environment variables
    ananke = Ananke.from_env()

    # Create a simple generation context
    context = PyGenerationContext(
        current_file="example.py",
        language="python",
        project_root="."
    )

    # Create a generation request
    request = PyGenerationRequest(
        prompt="def fibonacci(n):\n    '''Calculate the nth Fibonacci number'''",
        constraints_ir=[],  # No constraints
        max_tokens=200,
        temperature=0.7,
        context=context
    )

    print("Generating code...")
    print(f"Prompt: {request.prompt}")
    print()

    # Generate code
    response = await ananke.generate(request)

    # Display results
    print("=" * 80)
    print("Generated Code:")
    print("=" * 80)
    print(response.code)
    print("=" * 80)
    print()
    print(f"Tokens generated: {response.tokens_generated}")
    print(f"Finish reason: {response.finish_reason}")
    print(f"Model: {response.provenance.model}")
    print(f"Constraints satisfied: {response.validation.all_satisfied}")


if __name__ == "__main__":
    # Requires ANANKE_MODAL_ENDPOINT environment variable
    if not os.getenv("ANANKE_MODAL_ENDPOINT"):
        print("Error: ANANKE_MODAL_ENDPOINT environment variable not set")
        print("Example: export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run")
        exit(1)

    asyncio.run(main())
