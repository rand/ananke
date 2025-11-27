#!/usr/bin/env python3
"""
Example 5: Batch Processing

Demonstrates how to process multiple generation requests
efficiently using asyncio concurrency.
"""

import asyncio
import os
from ananke import Ananke, PyGenerationRequest, PyGenerationContext


async def generate_one(ananke: Ananke, prompt: str, index: int):
    """Generate code for a single prompt"""
    context = PyGenerationContext(
        current_file=f"example_{index}.py",
        language="python",
        project_root="."
    )

    request = PyGenerationRequest(
        prompt=prompt,
        constraints_ir=[],
        max_tokens=100,
        temperature=0.7,
        context=context
    )

    print(f"[{index}] Generating for: {prompt[:50]}...")
    response = await ananke.generate(request)
    print(f"[{index}] Complete! Generated {response.tokens_generated} tokens")

    return {
        "index": index,
        "prompt": prompt,
        "code": response.code,
        "tokens": response.tokens_generated,
        "satisfied": response.validation.all_satisfied
    }


async def main():
    # Initialize Ananke
    ananke = Ananke.from_env()

    # Define multiple prompts to process
    prompts = [
        "def add(a, b):\n    '''Add two numbers'''",
        "def multiply(a, b):\n    '''Multiply two numbers'''",
        "def factorial(n):\n    '''Calculate factorial'''",
        "class Point:\n    '''2D point class'''",
        "def quicksort(arr):\n    '''Quicksort algorithm'''"
    ]

    print("Batch Processing Example")
    print("=" * 80)
    print(f"Processing {len(prompts)} prompts concurrently...")
    print()

    # Process all prompts concurrently
    tasks = [generate_one(ananke, prompt, i) for i, prompt in enumerate(prompts)]
    results = await asyncio.gather(*tasks)

    # Display results
    print()
    print("=" * 80)
    print("Results:")
    print("=" * 80)

    for result in results:
        print(f"\n[{result['index']}] Prompt: {result['prompt'][:50]}...")
        print(f"    Tokens: {result['tokens']}")
        print(f"    Satisfied: {result['satisfied']}")
        print(f"    Code preview: {result['code'][:80]}...")

    print()
    print("=" * 80)
    print(f"Batch processing complete! Processed {len(results)} prompts.")


if __name__ == "__main__":
    if not os.getenv("ANANKE_MODAL_ENDPOINT"):
        print("Error: ANANKE_MODAL_ENDPOINT environment variable not set")
        exit(1)

    asyncio.run(main())
