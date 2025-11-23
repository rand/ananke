#!/usr/bin/env python3
import requests
import json

url = "https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run"
payload = {"prompt": "def add(a, b):"}

print(f"POST {url}")
print(f"Payload: {json.dumps(payload, indent=2)}")

try:
    resp = requests.post(url, json=payload, timeout=30)
    print(f"\nStatus: {resp.status_code}")
    print(f"Response: {resp.text}")

    if resp.status_code == 500:
        print("\n=== 500 ERROR DETAILS ===")
        print(f"Function Call ID: {resp.headers.get('Modal-Function-Call-Id', 'N/A')}")
        print("This means the function was called but threw an exception")
        print("Likely causes:")
        print("  - vLLM import failure")
        print("  - Model loading failure")
        print("  - Missing dependencies in Modal image")
        print("  - Constraint parsing error")
except Exception as e:
    print(f"ERROR: {e}")
