#!/usr/bin/env python3
"""
Simple test script for Ananke Modal inference endpoint
"""
import requests
import json
import time

ENDPOINT = "https://rand--ananke-inference-generate-api.modal.run"

def test_simple_generation():
    """Test basic code generation without constraints"""
    print("Testing simple generation...")
    print(f"Endpoint: {ENDPOINT}")

    payload = {
        "prompt": "def add(a, b):",
        "max_tokens": 50,
        "temperature": 0.7
    }

    print(f"\nRequest: {json.dumps(payload, indent=2)}")
    print("\nSending request (may take 3-5 minutes for cold start)...")

    start = time.time()
    try:
        response = requests.post(ENDPOINT, json=payload, timeout=300)
        duration = time.time() - start

        print(f"\nStatus: {response.status_code}")
        print(f"Duration: {duration:.1f}s")

        if response.status_code == 200:
            result = response.json()
            print(f"\nResponse: {json.dumps(result, indent=2)}")

            if result.get("finish_reason") == "stop":
                print("\n✓ SUCCESS: Generation completed")
                print(f"✓ Generated {result['tokens_generated']} tokens in {result['generation_time_ms']}ms")
                print(f"✓ Speed: {result['metadata']['tokens_per_sec']:.1f} tokens/sec")
            else:
                print(f"\n✗ FAILED: {result.get('finish_reason')}")
                if result.get('metadata', {}).get('error'):
                    print(f"✗ Error: {result['metadata']['error']}")
        else:
            print(f"\n✗ FAILED: HTTP {response.status_code}")
            print(f"Response: {response.text[:500]}")

    except requests.Timeout:
        print(f"\n✗ TIMEOUT after {time.time() - start:.1f}s")
    except Exception as e:
        print(f"\n✗ ERROR: {e}")

def test_json_constraint():
    """Test JSON schema constrained generation"""
    print("\n" + "="*60)
    print("Testing JSON schema constraint...")

    payload = {
        "prompt": "Generate a user profile:",
        "constraints": {
            "json_schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "age": {"type": "integer"},
                    "email": {"type": "string"}
                },
                "required": ["name", "age"]
            }
        },
        "max_tokens": 100,
        "temperature": 0.7
    }

    print(f"\nRequest: {json.dumps(payload, indent=2)}")

    start = time.time()
    try:
        response = requests.post(ENDPOINT, json=payload, timeout=300)
        duration = time.time() - start

        print(f"\nStatus: {response.status_code}")
        print(f"Duration: {duration:.1f}s")

        if response.status_code == 200:
            result = response.json()
            print(f"\nResponse: {json.dumps(result, indent=2)}")

            if result.get("constraint_satisfied") and result.get("finish_reason") == "stop":
                print("\n✓ SUCCESS: Constrained generation completed")
                print(f"✓ Output is valid JSON: {result['generated_text']}")
            else:
                print(f"\n✗ FAILED: constraint_satisfied={result.get('constraint_satisfied')}, finish_reason={result.get('finish_reason')}")
        else:
            print(f"\n✗ FAILED: HTTP {response.status_code}")
            print(f"Response: {response.text[:500]}")

    except requests.Timeout:
        print(f"\n✗ TIMEOUT after {time.time() - start:.1f}s")
    except Exception as e:
        print(f"\n✗ ERROR: {e}")

if __name__ == "__main__":
    test_simple_generation()
    test_json_constraint()
