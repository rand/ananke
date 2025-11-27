#!/usr/bin/env python3
"""
Example 4: Health Check

Demonstrates how to check the health of the Modal inference service
before making generation requests.
"""

import asyncio
import os
from ananke import Ananke


async def main():
    # Initialize Ananke
    ananke = Ananke.from_env()

    print("Checking Ananke inference service health...")
    print("=" * 80)

    try:
        # Perform health check
        is_healthy = await ananke.health_check()

        if is_healthy:
            print("✓ Service is HEALTHY")
            print()
            print("Service details:")
            print(f"  Endpoint: {os.getenv('ANANKE_MODAL_ENDPOINT')}")
            print(f"  Model: {os.getenv('ANANKE_MODEL', 'meta-llama/Llama-3.1-8B-Instruct')}")
            print()
            print("You can now make generation requests!")
        else:
            print("✗ Service is UNHEALTHY")
            print()
            print("Please check:")
            print("  1. Modal service is deployed and running")
            print("  2. ANANKE_MODAL_ENDPOINT is correct")
            print("  3. Network connectivity to Modal")

    except Exception as e:
        print(f"✗ Health check failed with error: {e}")
        print()
        print("Common issues:")
        print("  - Modal service not deployed")
        print("  - Incorrect endpoint URL")
        print("  - Network connectivity problems")

    print("=" * 80)


if __name__ == "__main__":
    if not os.getenv("ANANKE_MODAL_ENDPOINT"):
        print("Error: ANANKE_MODAL_ENDPOINT environment variable not set")
        print()
        print("Set it with:")
        print("  export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run")
        exit(1)

    asyncio.run(main())
