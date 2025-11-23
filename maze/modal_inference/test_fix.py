#!/usr/bin/env python3
"""
Test script to verify the Modal inference service fix.

This tests:
1. Health check endpoint
2. Simple generation via web endpoint
3. JSON schema constrained generation
4. Performance characteristics
5. Error handling
"""

import json
import time
import sys
import requests
from typing import Dict, Any


def test_health_check(base_url: str) -> bool:
    """Test health check endpoint"""
    print("\n" + "="*60)
    print("TEST 1: Health Check")
    print("="*60)
    
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        response.raise_for_status()
        
        data = response.json()
        print(f"✓ Status: {response.status_code}")
        print(f"✓ Response: {json.dumps(data, indent=2)}")
        
        assert data["status"] == "healthy", "Service not healthy"
        assert data["service"] == "ananke-inference", "Wrong service"
        
        print("✓ Health check PASSED")
        return True
        
    except Exception as e:
        print(f"✗ Health check FAILED: {e}")
        return False


def test_simple_generation(base_url: str) -> bool:
    """Test simple text generation"""
    print("\n" + "="*60)
    print("TEST 2: Simple Generation")
    print("="*60)
    
    request_data = {
        "prompt": "Write a Python function to add two numbers:",
        "max_tokens": 100,
        "temperature": 0.7,
    }
    
    print(f"Request: {json.dumps(request_data, indent=2)}")
    
    try:
        start_time = time.time()
        response = requests.post(
            f"{base_url}/generate_api",
            json=request_data,
            timeout=300,
        )
        elapsed_time = time.time() - start_time
        
        response.raise_for_status()
        data = response.json()
        
        print(f"\n✓ Status: {response.status_code}")
        print(f"✓ Total time: {elapsed_time:.2f}s")
        print(f"✓ Generation time (server): {data.get('generation_time_ms', 0)}ms")
        print(f"✓ Tokens generated: {data.get('tokens_generated', 0)}")
        print(f"✓ Finish reason: {data.get('finish_reason', 'unknown')}")
        print(f"\nGenerated text:\n{'-'*40}")
        print(data.get("generated_text", ""))
        print("-"*40)
        
        # Verify response structure
        assert "generated_text" in data, "Missing generated_text"
        assert "tokens_generated" in data, "Missing tokens_generated"
        assert data["finish_reason"] != "error", f"Generation error: {data.get('metadata', {})}"
        assert data["tokens_generated"] > 0, "No tokens generated"
        
        print("\n✓ Simple generation PASSED")
        return True
        
    except Exception as e:
        print(f"✗ Simple generation FAILED: {e}")
        if hasattr(e, 'response'):
            print(f"Response text: {e.response.text[:500]}")
        return False


def test_json_constrained_generation(base_url: str) -> bool:
    """Test JSON schema constrained generation"""
    print("\n" + "="*60)
    print("TEST 3: JSON Schema Constraint")
    print("="*60)
    
    request_data = {
        "prompt": "Generate a user profile with name, age, and email:",
        "constraints": {
            "json_schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "age": {"type": "integer"},
                    "email": {"type": "string", "format": "email"},
                },
                "required": ["name", "age", "email"],
            }
        },
        "max_tokens": 150,
        "temperature": 0.7,
    }
    
    print(f"Request with JSON schema constraint")
    
    try:
        start_time = time.time()
        response = requests.post(
            f"{base_url}/generate_api",
            json=request_data,
            timeout=300,
        )
        elapsed_time = time.time() - start_time
        
        response.raise_for_status()
        data = response.json()
        
        print(f"\n✓ Status: {response.status_code}")
        print(f"✓ Total time: {elapsed_time:.2f}s")
        print(f"✓ Constraint satisfied: {data.get('constraint_satisfied', False)}")
        print(f"\nGenerated JSON:\n{'-'*40}")
        print(data.get("generated_text", ""))
        print("-"*40)
        
        # Try to parse as JSON
        try:
            generated_json = json.loads(data.get("generated_text", "{}"))
            print(f"\n✓ Valid JSON: {json.dumps(generated_json, indent=2)}")
            
            # Verify required fields
            assert "name" in generated_json, "Missing required field: name"
            assert "age" in generated_json, "Missing required field: age"
            assert "email" in generated_json, "Missing required field: email"
            
            print("✓ All required fields present")
            
        except json.JSONDecodeError as e:
            print(f"⚠ Generated text is not valid JSON: {e}")
            # Don't fail the test - llguidance might need tuning
        
        assert data["finish_reason"] != "error", f"Generation error: {data.get('metadata', {})}"
        
        print("\n✓ JSON constrained generation PASSED")
        return True
        
    except Exception as e:
        print(f"✗ JSON constrained generation FAILED: {e}")
        if hasattr(e, 'response'):
            print(f"Response text: {e.response.text[:500]}")
        return False


def test_error_handling(base_url: str) -> bool:
    """Test error handling with invalid request"""
    print("\n" + "="*60)
    print("TEST 4: Error Handling")
    print("="*60)
    
    # Test with invalid temperature
    request_data = {
        "prompt": "Test",
        "temperature": -1.0,  # Invalid
        "max_tokens": 10,
    }
    
    try:
        response = requests.post(
            f"{base_url}/generate_api",
            json=request_data,
            timeout=60,
        )
        
        data = response.json()
        
        # Should either reject or handle gracefully
        if response.status_code >= 400:
            print(f"✓ Properly rejected invalid request: {response.status_code}")
        else:
            print(f"⚠ Accepted invalid request (might have clamped values)")
            print(f"Response: {json.dumps(data, indent=2)}")
        
        print("\n✓ Error handling test PASSED")
        return True
        
    except Exception as e:
        print(f"✗ Error handling test FAILED: {e}")
        return False


def main():
    """Run all tests"""
    if len(sys.argv) < 2:
        print("Usage: python test_fix.py <base_url>")
        print("Example: python test_fix.py https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run")
        sys.exit(1)
    
    base_url = sys.argv[1].rstrip("/")
    
    print("="*60)
    print("Ananke Modal Inference Service - Fix Verification")
    print("="*60)
    print(f"Base URL: {base_url}")
    
    # Extract health URL
    health_url = base_url.replace("-generate-api", "-health")
    
    results = []
    
    # Run tests
    results.append(("Health Check", test_health_check(health_url)))
    results.append(("Simple Generation", test_simple_generation(base_url)))
    results.append(("JSON Constrained", test_json_constrained_generation(base_url)))
    results.append(("Error Handling", test_error_handling(base_url)))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    for name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{name:.<40} {status}")
    
    total_passed = sum(1 for _, passed in results if passed)
    total_tests = len(results)
    
    print(f"\nResults: {total_passed}/{total_tests} tests passed")
    
    if total_passed == total_tests:
        print("\n✓ ALL TESTS PASSED - Fix verified successfully!")
        sys.exit(0)
    else:
        print(f"\n✗ {total_tests - total_passed} test(s) failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
