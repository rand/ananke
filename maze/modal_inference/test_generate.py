#!/usr/bin/env python3
"""Direct test of generate endpoint"""
import json
import requests

url = "https://rand--ananke-inference-generate-api.modal.run"

print(f"Testing {url}")
print("\nTest 1: Simple prompt")

payload = {
    "prompt": "def hello():"
}

try:
    response = requests.post(url, json=payload, timeout=30)
    print(f"Status: {response.status_code}")
    print(f"Headers: {dict(response.headers)}")
    print(f"Body: {response.text[:1000]}")

    if response.status_code != 200:
        print(f"\nERROR: Got status {response.status_code}")
except Exception as e:
    print(f"Exception: {e}")
    import traceback
    traceback.print_exc()
