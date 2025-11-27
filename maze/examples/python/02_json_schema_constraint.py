#!/usr/bin/env python3
"""
Example 2: JSON Schema Constraint

Demonstrates using JSON Schema constraints to generate structured data
that conforms to a specific schema.
"""

import asyncio
import json
import os
from ananke import Ananke, PyConstraintIR, PyGenerationRequest, PyGenerationContext


async def main():
    # Initialize Ananke
    ananke = Ananke.from_env()

    # Define a JSON Schema for a user profile
    user_schema = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer", "minimum": 0, "maximum": 120},
            "email": {"type": "string", "format": "email"},
            "active": {"type": "boolean"}
        },
        "required": ["name", "age", "email"]
    }

    # Create a constraint with the JSON Schema
    constraint = PyConstraintIR(
        name="user_profile_schema",
        json_schema=json.dumps(user_schema),
        grammar=None,
        regex_patterns=[]
    )

    # Create generation context
    context = PyGenerationContext(
        current_file="user_api.py",
        language="python",
        project_root="."
    )

    # Create generation request
    request = PyGenerationRequest(
        prompt="Generate a user profile with name 'Alice', age 30, and email:",
        constraints_ir=[constraint],
        max_tokens=150,
        temperature=0.7,
        context=context
    )

    print("Generating structured data with JSON Schema constraint...")
    print(f"Schema: {json.dumps(user_schema, indent=2)}")
    print()

    # Generate
    response = await ananke.generate(request)

    # Display results
    print("=" * 80)
    print("Generated JSON:")
    print("=" * 80)
    print(response.code)
    print("=" * 80)
    print()
    print(f"Constraint satisfied: {response.validation.all_satisfied}")
    print(f"Tokens: {response.tokens_generated}")

    # Try to parse as JSON to verify
    try:
        data = json.loads(response.code)
        print()
        print("Parsed JSON successfully:")
        print(json.dumps(data, indent=2))
    except json.JSONDecodeError as e:
        print(f"Warning: Generated code is not valid JSON: {e}")


if __name__ == "__main__":
    if not os.getenv("ANANKE_MODAL_ENDPOINT"):
        print("Error: ANANKE_MODAL_ENDPOINT environment variable not set")
        exit(1)

    asyncio.run(main())
