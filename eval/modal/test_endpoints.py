"""
Test script for Modal inference endpoints.

Usage:
    python test_endpoints.py <endpoint-url>

Example:
    python test_endpoints.py https://yourorg--ananke-eval-inference-generate-constrained-endpoint.modal.run
"""

import sys
import json
import requests
from typing import Dict, Any


def test_constrained_endpoint(base_url: str) -> bool:
    """Test the constrained generation endpoint."""
    print("Testing /generate/constrained endpoint...")

    request_data = {
        "prompt": "Implement a function that checks if a number is prime",
        "constraints": {
            "grammar": "function isPrime(n: number): boolean",
            "type_constraints": {
                "parameters": [{"name": "n", "type": "number"}],
                "return_type": "boolean",
            },
            "naming_constraints": {"function_name": "isPrime"},
            "structural_constraints": {
                "must_use": ["for loop or while loop"],
                "must_not_use": ["external libraries"],
            },
            "complexity_constraints": {
                "time_complexity": "O(sqrt(n))",
                "space_complexity": "O(1)",
            },
        },
    }

    try:
        response = requests.post(
            f"{base_url}/generate/constrained",
            json=request_data,
            headers={"Content-Type": "application/json"},
            timeout=60,
        )

        if response.status_code != 200:
            print(f"  ✗ Failed with status {response.status_code}")
            print(f"  Response: {response.text}")
            return False

        result = response.json()

        # Validate response structure
        if "code" not in result or "metadata" not in result:
            print("  ✗ Invalid response structure")
            print(f"  Response: {json.dumps(result, indent=2)}")
            return False

        metadata = result["metadata"]
        if not all(
            key in metadata
            for key in ["tokens_used", "generation_time_ms", "model"]
        ):
            print("  ✗ Missing metadata fields")
            print(f"  Metadata: {json.dumps(metadata, indent=2)}")
            return False

        print("  ✓ Endpoint working correctly")
        print(f"  Generated {len(result['code'])} characters of code")
        print(f"  Tokens used: {metadata['tokens_used']}")
        print(f"  Generation time: {metadata['generation_time_ms']}ms")
        print(f"  Model: {metadata['model']}")
        print(f"\n  Generated code preview:\n{result['code'][:200]}...")

        return True

    except requests.exceptions.Timeout:
        print("  ✗ Request timed out")
        return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


def test_unconstrained_endpoint(base_url: str) -> bool:
    """Test the unconstrained generation endpoint."""
    print("\nTesting /generate/unconstrained endpoint...")

    request_data = {
        "prompt": "Implement a function to calculate factorial of a number",
        "few_shot_examples": [
            {
                "prompt": "Implement a function to check if a number is even",
                "code": "function isEven(n: number): boolean {\n  return n % 2 === 0;\n}",
            },
            {
                "prompt": "Implement a function to find the maximum of two numbers",
                "code": "function max(a: number, b: number): number {\n  return a > b ? a : b;\n}",
            },
        ],
    }

    try:
        response = requests.post(
            f"{base_url}/generate/unconstrained",
            json=request_data,
            headers={"Content-Type": "application/json"},
            timeout=60,
        )

        if response.status_code != 200:
            print(f"  ✗ Failed with status {response.status_code}")
            print(f"  Response: {response.text}")
            return False

        result = response.json()

        # Validate response structure
        if "code" not in result or "metadata" not in result:
            print("  ✗ Invalid response structure")
            print(f"  Response: {json.dumps(result, indent=2)}")
            return False

        metadata = result["metadata"]
        if not all(
            key in metadata
            for key in ["tokens_used", "generation_time_ms", "model"]
        ):
            print("  ✗ Missing metadata fields")
            print(f"  Metadata: {json.dumps(metadata, indent=2)}")
            return False

        print("  ✓ Endpoint working correctly")
        print(f"  Generated {len(result['code'])} characters of code")
        print(f"  Tokens used: {metadata['tokens_used']}")
        print(f"  Generation time: {metadata['generation_time_ms']}ms")
        print(f"  Model: {metadata['model']}")
        print(f"\n  Generated code preview:\n{result['code'][:200]}...")

        return True

    except requests.exceptions.Timeout:
        print("  ✗ Request timed out")
        return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python test_endpoints.py <base-url>")
        print(
            "\nExample: python test_endpoints.py https://yourorg--ananke-eval-inference.modal.run"
        )
        sys.exit(1)

    base_url = sys.argv[1].rstrip("/")

    print("=" * 70)
    print("Ananke Evaluation Inference Service - Endpoint Tests")
    print("=" * 70)
    print(f"\nBase URL: {base_url}\n")

    # Run tests
    constrained_ok = test_constrained_endpoint(base_url)
    unconstrained_ok = test_unconstrained_endpoint(base_url)

    # Summary
    print("\n" + "=" * 70)
    print("Test Summary")
    print("=" * 70)
    print(f"Constrained endpoint:   {'✓ PASS' if constrained_ok else '✗ FAIL'}")
    print(
        f"Unconstrained endpoint: {'✓ PASS' if unconstrained_ok else '✗ FAIL'}"
    )

    if constrained_ok and unconstrained_ok:
        print("\n✓ All tests passed! Endpoints are ready for evaluation runs.")
        sys.exit(0)
    else:
        print(
            "\n✗ Some tests failed. Check the output above for details."
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
