#!/usr/bin/env python3
"""Quick script to test Modal endpoint and see actual errors"""
import sys
import subprocess
import time

# Test the endpoint
print("Testing Modal endpoint...")
result = subprocess.run([
    "curl", "-X", "POST",
    "https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run",
    "-H", "Content-Type: application/json",
    "-d", '{"prompt": "def hello():"}',
    "--max-time", "20",
    "-v"
], capture_output=True, text=True)

print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)

# Now get logs
print("\n\nFetching Modal logs...")
time.sleep(2)
logs = subprocess.run([
    "modal", "app", "logs", "ananke-inference"
], capture_output=True, text=True, timeout=10)

print("Logs:", logs.stdout)
if logs.stderr:
    print("Log errors:", logs.stderr)
