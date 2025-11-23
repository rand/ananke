"""
Test suite for Ananke Modal Inference Service

Run with: pytest modal_inference/test_inference.py
Or with Modal: modal run modal_inference/test_inference.py
"""

import json
import time
from typing import Dict, Any

import modal


def get_service():
    """Get inference service instance."""
    return modal.Cls.lookup("ananke-inference", "InferenceService")()


class TestHealthAndValidation:
    """Test health checks and validation endpoints."""

    def test_health_check(self):
        """Test service health check."""
        service = get_service()
        health = service.health_check.remote()

        assert health["status"] == "healthy"
        assert "model" in health
        assert "timestamp" in health
        print(f"✓ Health check passed: {health['model']}")

    def test_validate_json_schema(self):
        """Test JSON schema constraint validation."""
        service = get_service()

        valid_constraint = {
            "type": "json",
            "schema": {
                "type": "object",
                "properties": {"name": {"type": "string"}}
            }
        }

        result = service.validate_constraints.remote(valid_constraint)
        assert result["valid"] is True
        print("✓ Valid JSON schema accepted")

    def test_validate_invalid_constraint(self):
        """Test that invalid constraints are rejected."""
        service = get_service()

        invalid_constraint = {
            "type": "unknown_type",
            "schema": {}
        }

        result = service.validate_constraints.remote(invalid_constraint)
        assert result["valid"] is False
        assert "error" in result
        print(f"✓ Invalid constraint rejected: {result['error']}")


class TestConstrainedGeneration:
    """Test constrained code generation."""

    def test_json_schema_generation(self):
        """Test generation with JSON schema constraint."""
        service = get_service()

        request = {
            "prompt": "Generate a Python function that adds two numbers:",
            "constraints": {
                "type": "json",
                "schema": {
                    "type": "object",
                    "properties": {
                        "function_name": {"type": "string"},
                        "parameters": {"type": "array"},
                        "body": {"type": "string"}
                    },
                    "required": ["function_name", "parameters", "body"]
                }
            },
            "max_tokens": 256,
            "temperature": 0.5,
            "metadata": {"test_id": "json_schema_001"}
        }

        result = service.generate.remote(request)

        assert "error" not in result
        assert result["tokens_generated"] > 0
        assert result["constraint_violations"] == 0
        assert "generated_code" in result
        assert "provenance" in result

        print(f"✓ JSON schema generation successful")
        print(f"  Tokens: {result['tokens_generated']}")
        print(f"  Time: {result['generation_time_ms']:.2f}ms")
        print(f"  Violations: {result['constraint_violations']}")

    def test_regex_generation(self):
        """Test generation with regex constraint."""
        service = get_service()

        request = {
            "prompt": "Write a Python function:",
            "constraints": {
                "type": "regex",
                "pattern": r"def \w+\(.*\):.*"
            },
            "max_tokens": 128,
            "temperature": 0.5,
            "metadata": {"test_id": "regex_001"}
        }

        result = service.generate.remote(request)

        assert "error" not in result
        assert result["tokens_generated"] > 0
        assert result["constraint_violations"] == 0

        # Verify output matches pattern
        import re
        assert re.search(r"def \w+\(", result["generated_code"])

        print(f"✓ Regex constraint generation successful")

    def test_minimal_constraint(self):
        """Test generation with minimal constraint (baseline)."""
        service = get_service()

        request = {
            "prompt": "Generate a hello world function in Python:",
            "constraints": {
                "type": "regex",
                "pattern": ".*"  # Match anything
            },
            "max_tokens": 100,
            "temperature": 0.5,
            "metadata": {"test_id": "minimal_001"}
        }

        result = service.generate.remote(request)

        assert "error" not in result
        assert result["tokens_generated"] > 0
        assert "def" in result["generated_code"].lower() or "print" in result["generated_code"].lower()

        print(f"✓ Minimal constraint generation successful")


class TestPerformance:
    """Test performance characteristics."""

    def test_generation_speed(self):
        """Test that generation meets speed targets."""
        service = get_service()

        request = {
            "prompt": "Create a function to validate an email address:",
            "constraints": {
                "type": "regex",
                "pattern": ".*"
            },
            "max_tokens": 512,
            "temperature": 0.7,
            "metadata": {"test_id": "perf_001"}
        }

        start = time.time()
        result = service.generate.remote(request)
        total_time = (time.time() - start) * 1000

        assert "error" not in result

        tokens = result["tokens_generated"]
        gen_time = result["generation_time_ms"]
        tok_per_sec = result["provenance"]["tokens_per_second"]

        # Performance assertions (adjust based on model)
        assert tok_per_sec > 10, f"Too slow: {tok_per_sec} tok/s"
        assert gen_time < 30000, f"Generation took too long: {gen_time}ms"

        print(f"✓ Performance test passed")
        print(f"  Tokens: {tokens}")
        print(f"  Generation time: {gen_time:.2f}ms")
        print(f"  Total time: {total_time:.2f}ms")
        print(f"  Speed: {tok_per_sec:.1f} tok/s")

    def test_cold_start_time(self):
        """Test cold start performance (if container was idle)."""
        service = get_service()

        start = time.time()
        health = service.health_check.remote()
        cold_start_time = (time.time() - start) * 1000

        assert health["status"] == "healthy"

        print(f"✓ Cold start time: {cold_start_time:.2f}ms")
        # Note: First call after idle will be slower due to model loading


class TestErrorHandling:
    """Test error handling and edge cases."""

    def test_empty_prompt(self):
        """Test handling of empty prompt."""
        service = get_service()

        request = {
            "prompt": "",
            "constraints": {"type": "regex", "pattern": ".*"},
            "max_tokens": 100,
            "temperature": 0.7,
        }

        result = service.generate.remote(request)
        # Should either generate or return error, but not crash
        assert "generated_code" in result or "error" in result
        print("✓ Empty prompt handled")

    def test_invalid_constraint_structure(self):
        """Test handling of malformed constraints."""
        service = get_service()

        request = {
            "prompt": "Generate code",
            "constraints": {"type": "json"},  # Missing schema
            "max_tokens": 100,
            "temperature": 0.7,
        }

        result = service.generate.remote(request)
        assert "error" in result
        print(f"✓ Invalid constraint caught: {result.get('error_type')}")

    def test_excessive_max_tokens(self):
        """Test handling of unreasonable max_tokens."""
        service = get_service()

        request = {
            "prompt": "Generate code",
            "constraints": {"type": "regex", "pattern": ".*"},
            "max_tokens": 100000,  # Way too large
            "temperature": 0.7,
        }

        result = service.generate.remote(request)
        # Should either cap the value or return error
        assert "generated_code" in result or "error" in result
        print("✓ Excessive max_tokens handled")

    def test_temperature_bounds(self):
        """Test temperature parameter validation."""
        service = get_service()

        # Test with temperature = 0
        request = {
            "prompt": "Generate a function",
            "constraints": {"type": "regex", "pattern": ".*"},
            "max_tokens": 100,
            "temperature": 0.0,
        }

        result = service.generate.remote(request)
        assert "error" not in result
        print("✓ Temperature=0 handled")

        # Test with temperature = 2.0
        request["temperature"] = 2.0
        result = service.generate.remote(request)
        assert "generated_code" in result or "error" in result
        print("✓ Temperature=2.0 handled")


class TestProvenance:
    """Test provenance tracking."""

    def test_provenance_completeness(self):
        """Test that provenance includes all required fields."""
        service = get_service()

        request = {
            "prompt": "Generate code",
            "constraints": {"type": "regex", "pattern": ".*"},
            "max_tokens": 100,
            "temperature": 0.7,
            "metadata": {
                "request_id": "test-provenance-001",
                "user": "test_suite",
            }
        }

        result = service.generate.remote(request)

        assert "error" not in result
        assert "provenance" in result

        prov = result["provenance"]
        required_fields = [
            "model",
            "timestamp",
            "tokens_per_second",
            "total_latency_ms",
        ]

        for field in required_fields:
            assert field in prov, f"Missing provenance field: {field}"

        print(f"✓ Provenance complete: {list(prov.keys())}")

    def test_metadata_passthrough(self):
        """Test that metadata is passed through to response."""
        service = get_service()

        test_metadata = {
            "request_id": "test-metadata-001",
            "source": "test_suite",
            "experiment": "metadata_test",
        }

        request = {
            "prompt": "Generate code",
            "constraints": {"type": "regex", "pattern": ".*"},
            "max_tokens": 100,
            "temperature": 0.7,
            "metadata": test_metadata,
        }

        result = service.generate.remote(request)

        assert "error" not in result
        assert result["metadata"] == test_metadata

        print(f"✓ Metadata passed through correctly")


def run_all_tests():
    """Run all test suites."""
    print("\n" + "="*80)
    print("ANANKE MODAL INFERENCE SERVICE - TEST SUITE")
    print("="*80 + "\n")

    test_suites = [
        ("Health and Validation", TestHealthAndValidation()),
        ("Constrained Generation", TestConstrainedGeneration()),
        ("Performance", TestPerformance()),
        ("Error Handling", TestErrorHandling()),
        ("Provenance", TestProvenance()),
    ]

    results = {"passed": 0, "failed": 0, "errors": []}

    for suite_name, suite in test_suites:
        print(f"\n--- {suite_name} ---\n")

        test_methods = [m for m in dir(suite) if m.startswith("test_")]

        for method_name in test_methods:
            try:
                method = getattr(suite, method_name)
                method()
                results["passed"] += 1
            except AssertionError as e:
                print(f"✗ {method_name} FAILED: {e}")
                results["failed"] += 1
                results["errors"].append((method_name, str(e)))
            except Exception as e:
                print(f"✗ {method_name} ERROR: {e}")
                results["failed"] += 1
                results["errors"].append((method_name, str(e)))

    # Print summary
    print("\n" + "="*80)
    print("TEST SUMMARY")
    print("="*80)
    print(f"Passed: {results['passed']}")
    print(f"Failed: {results['failed']}")
    print(f"Total:  {results['passed'] + results['failed']}")

    if results["errors"]:
        print("\nFailures:")
        for test_name, error in results["errors"]:
            print(f"  - {test_name}: {error}")

    print("="*80 + "\n")

    return results["failed"] == 0


@modal.App()
app = modal.App("ananke-inference-tests")


@app.local_entrypoint()
def main():
    """Modal entrypoint for running tests."""
    success = run_all_tests()
    exit(0 if success else 1)


if __name__ == "__main__":
    # For running with pytest
    run_all_tests()
