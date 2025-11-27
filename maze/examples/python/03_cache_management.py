#!/usr/bin/env python3
"""
Example 3: Cache Management

Demonstrates how to use the constraint compilation cache
for improved performance.
"""

import asyncio
import json
import os
from ananke import Ananke, PyConstraintIR


async def main():
    # Initialize Ananke with caching enabled
    ananke = Ananke(
        modal_endpoint=os.getenv("ANANKE_MODAL_ENDPOINT"),
        modal_api_key=os.getenv("ANANKE_MODAL_API_KEY"),
        enable_cache=True,
        cache_size=100
    )

    print("Cache Management Example")
    print("=" * 80)

    # Check initial cache stats
    stats = await ananke.cache_stats()
    print(f"Initial cache size: {stats['size']}/{stats['limit']}")
    print()

    # Create a constraint
    constraint = PyConstraintIR(
        name="simple_object",
        json_schema=json.dumps({
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "name": {"type": "string"}
            }
        }),
        grammar=None,
        regex_patterns=[]
    )

    # Compile constraint (first time - will be cached)
    print("Compiling constraint (first time)...")
    result1 = await ananke.compile_constraints([constraint])
    print(f"Compiled hash: {result1['hash'][:16]}...")
    print()

    # Check cache stats after compilation
    stats = await ananke.cache_stats()
    print(f"Cache size after compilation: {stats['size']}/{stats['limit']}")
    print()

    # Compile same constraint again (should use cache)
    print("Compiling same constraint again (cache hit expected)...")
    result2 = await ananke.compile_constraints([constraint])
    print(f"Compiled hash: {result2['hash'][:16]}...")
    print(f"Hashes match: {result1['hash'] == result2['hash']}")
    print()

    # Cache stats should be the same
    stats = await ananke.cache_stats()
    print(f"Cache size after second compilation: {stats['size']}/{stats['limit']}")
    print()

    # Clear the cache
    print("Clearing cache...")
    await ananke.clear_cache()

    stats = await ananke.cache_stats()
    print(f"Cache size after clear: {stats['size']}/{stats['limit']}")
    print()

    print("=" * 80)
    print("Cache management complete!")


if __name__ == "__main__":
    if not os.getenv("ANANKE_MODAL_ENDPOINT"):
        print("Error: ANANKE_MODAL_ENDPOINT environment variable not set")
        exit(1)

    asyncio.run(main())
