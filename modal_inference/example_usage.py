"""
Example usage scripts for Ananke Modal Inference Service

Demonstrates various constraint types and usage patterns.
"""

import json
from typing import Any, Dict

import modal


def get_inference_service():
    """Get reference to deployed inference service."""
    return modal.Cls.lookup("ananke-inference", "InferenceService")


# Example 1: JSON Schema Constraint for API Handler
def example_json_schema_constraint():
    """Generate API handler with JSON schema constraint."""
    print("\n" + "="*80)
    print("EXAMPLE 1: JSON Schema Constraint")
    print("="*80 + "\n")

    service = get_inference_service()

    request = {
        "prompt": """Generate a Python FastAPI endpoint that handles user registration.
It should accept a JSON request with username, email, and password fields,
validate the input, and return a structured response.""",
        "constraints": {
            "type": "json",
            "schema": {
                "type": "object",
                "properties": {
                    "function_name": {"type": "string"},
                    "decorator": {"type": "string", "pattern": "@app\\.(get|post|put|delete)"},
                    "parameters": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "return_type": {"type": "string"},
                    "docstring": {"type": "string"},
                    "body": {"type": "string"}
                },
                "required": ["function_name", "decorator", "parameters", "body"]
            }
        },
        "max_tokens": 1024,
        "temperature": 0.7,
        "metadata": {
            "request_id": "example-json-001",
            "example_type": "json_schema"
        }
    }

    result = service.generate.remote(request)
    print_result(result)


# Example 2: Regex Constraint for Class Definition
def example_regex_constraint():
    """Generate class with regex pattern constraint."""
    print("\n" + "="*80)
    print("EXAMPLE 2: Regex Pattern Constraint")
    print("="*80 + "\n")

    service = get_inference_service()

    request = {
        "prompt": "Generate a Python dataclass for a User with name, email, and age fields:",
        "constraints": {
            "type": "regex",
            "pattern": r"@dataclass\s+class\s+\w+:\s+(name|email|age):\s*\w+"
        },
        "max_tokens": 512,
        "temperature": 0.5,
        "metadata": {
            "request_id": "example-regex-001",
            "example_type": "regex_pattern"
        }
    }

    result = service.generate.remote(request)
    print_result(result)


# Example 3: Grammar Constraint for Custom DSL
def example_grammar_constraint():
    """Generate code following custom grammar."""
    print("\n" + "="*80)
    print("EXAMPLE 3: Grammar Constraint (EBNF)")
    print("="*80 + "\n")

    service = get_inference_service()

    # Simple grammar for function definitions
    grammar = """
        function ::= decorator? "def" ws identifier "(" params? ")" ":" ws body
        decorator ::= "@" identifier ws
        identifier ::= [a-z_][a-z0-9_]*
        params ::= identifier (ws? "," ws? identifier)*
        body ::= statement+
        statement ::= ws+ [^\\n]+ "\\n"
        ws ::= [ \\t]+
    """

    request = {
        "prompt": "Create a Python function decorated with @app.route that handles login:",
        "constraints": {
            "type": "grammar",
            "grammar": grammar
        },
        "max_tokens": 768,
        "temperature": 0.6,
        "metadata": {
            "request_id": "example-grammar-001",
            "example_type": "custom_grammar"
        }
    }

    result = service.generate.remote(request)
    print_result(result)


# Example 4: Composite Constraint (Multiple Rules)
def example_composite_constraint():
    """Generate code satisfying multiple constraints."""
    print("\n" + "="*80)
    print("EXAMPLE 4: Composite Constraint (Multiple Rules)")
    print("="*80 + "\n")

    service = get_inference_service()

    request = {
        "prompt": "Generate a validated configuration handler class:",
        "constraints": {
            "type": "composite",
            "constraints": [
                {
                    "type": "regex",
                    "pattern": r"class\s+\w+Config:"
                },
                {
                    "type": "json",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "has_init_method": {"type": "boolean", "const": True},
                            "has_validate_method": {"type": "boolean", "const": True}
                        }
                    }
                }
            ]
        },
        "max_tokens": 1024,
        "temperature": 0.7,
        "metadata": {
            "request_id": "example-composite-001",
            "example_type": "composite_constraints"
        }
    }

    result = service.generate.remote(request)
    print_result(result)


# Example 5: Integration with Ananke Pipeline
def example_full_pipeline():
    """Simulate full Ananke pipeline: Clew → Braid → Maze → Modal."""
    print("\n" + "="*80)
    print("EXAMPLE 5: Full Ananke Pipeline Simulation")
    print("="*80 + "\n")

    # Simulate ConstraintIR from Braid compilation
    constraint_ir = {
        "type": "json",
        "schema": {
            "type": "object",
            "properties": {
                "imports": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Required imports"
                },
                "function_signature": {
                    "type": "string",
                    "pattern": "^def \\w+\\(",
                    "description": "Function definition"
                },
                "error_handling": {
                    "type": "boolean",
                    "const": True,
                    "description": "Must include try/except"
                },
                "type_hints": {
                    "type": "boolean",
                    "const": True,
                    "description": "Must use type annotations"
                },
                "max_lines": {
                    "type": "number",
                    "maximum": 50,
                    "description": "Maximum function length"
                },
                "forbidden_keywords": {
                    "type": "array",
                    "items": {"enum": ["eval", "exec"]},
                    "maxItems": 0,
                    "description": "Disallowed keywords"
                }
            },
            "required": ["imports", "function_signature", "error_handling", "type_hints"]
        }
    }

    service = get_inference_service()

    request = {
        "prompt": """Generate a secure function to fetch and parse user data from an API endpoint.
Include proper error handling, type hints, and input validation.
The function should:
- Accept a user_id parameter
- Make an HTTP request
- Parse JSON response
- Handle errors gracefully
- Return typed result""",
        "constraints": constraint_ir,
        "max_tokens": 2048,
        "temperature": 0.7,
        "metadata": {
            "request_id": "pipeline-example-001",
            "source": "ananke_cli",
            "maze_version": "0.1.0",
            "constraint_source": "braid_compiled",
            "intent_source": "user_prompt"
        }
    }

    result = service.generate.remote(request)
    print_result(result)

    # Simulate validation by Maze
    print("\n--- Maze Validation ---")
    if result.get("constraint_violations", 0) == 0:
        print("✓ All constraints satisfied")
        print("✓ Code ready for integration")
    else:
        print("✗ Constraint violations detected")
        print("✗ Regeneration required")


# Example 6: Health Check and Service Validation
def example_health_check():
    """Check service health and validate constraints."""
    print("\n" + "="*80)
    print("EXAMPLE 6: Health Check and Constraint Validation")
    print("="*80 + "\n")

    service = get_inference_service()

    # Health check
    print("--- Health Check ---")
    health = service.health_check.remote()
    print(json.dumps(health, indent=2))

    # Validate constraints before generation
    print("\n--- Constraint Validation ---")
    test_constraint = {
        "type": "json",
        "schema": {
            "type": "object",
            "properties": {
                "code": {"type": "string"}
            }
        }
    }

    validation = service.validate_constraints.remote(test_constraint)
    print(json.dumps(validation, indent=2))

    if validation["valid"]:
        print("\n✓ Constraints are valid and ready for use")
    else:
        print(f"\n✗ Constraint error: {validation['error']}")


# Example 7: Performance Benchmarking
def example_benchmark():
    """Benchmark generation performance."""
    print("\n" + "="*80)
    print("EXAMPLE 7: Performance Benchmark")
    print("="*80 + "\n")

    import time

    service = get_inference_service()

    # Test different token lengths
    test_cases = [
        (128, "Generate a simple function"),
        (512, "Generate a class with multiple methods"),
        (1024, "Generate a complete module with documentation"),
    ]

    results = []

    for max_tokens, prompt in test_cases:
        print(f"\nTesting {max_tokens} token generation...")

        start = time.time()
        result = service.generate.remote({
            "prompt": prompt,
            "constraints": {
                "type": "regex",
                "pattern": ".*"  # Minimal constraint
            },
            "max_tokens": max_tokens,
            "temperature": 0.7,
        })
        total_time = (time.time() - start) * 1000

        if "error" not in result:
            results.append({
                "max_tokens": max_tokens,
                "actual_tokens": result["tokens_generated"],
                "generation_time_ms": result["generation_time_ms"],
                "total_time_ms": total_time,
                "tokens_per_second": result["provenance"]["tokens_per_second"]
            })

    # Print benchmark results
    print("\n--- Benchmark Results ---")
    print(f"{'Max Tokens':<12} {'Actual':<8} {'Gen Time':<12} {'Total Time':<12} {'Tok/Sec':<10}")
    print("-" * 60)
    for r in results:
        print(f"{r['max_tokens']:<12} {r['actual_tokens']:<8} "
              f"{r['generation_time_ms']:<12.2f} {r['total_time_ms']:<12.2f} "
              f"{r['tokens_per_second']:<10.1f}")


# Utility function to print results
def print_result(result: Dict[str, Any]) -> None:
    """Pretty print generation result."""
    if "error" in result:
        print(f"✗ Error: {result['error']}")
        print(f"  Type: {result.get('error_type', 'Unknown')}")
        return

    print("--- Generated Code ---")
    print(result["generated_code"])
    print("\n--- Metadata ---")
    print(f"Tokens: {result['tokens_generated']}")
    print(f"Generation time: {result['generation_time_ms']:.2f}ms")
    print(f"Tokens/sec: {result['provenance']['tokens_per_second']:.1f}")
    print(f"Constraint violations: {result['constraint_violations']}")

    if result["constraint_violations"] > 0:
        print("⚠ WARNING: Output violated constraints!")
    else:
        print("✓ All constraints satisfied")

    print("\n--- Provenance ---")
    print(json.dumps(result["provenance"], indent=2))


# Main runner
def main():
    """Run all examples."""
    print("\n" + "="*80)
    print("ANANKE MODAL INFERENCE SERVICE - EXAMPLE USAGE")
    print("="*80)

    examples = [
        ("JSON Schema Constraint", example_json_schema_constraint),
        ("Regex Pattern Constraint", example_regex_constraint),
        ("Grammar Constraint", example_grammar_constraint),
        ("Composite Constraint", example_composite_constraint),
        ("Full Pipeline", example_full_pipeline),
        ("Health Check", example_health_check),
        ("Performance Benchmark", example_benchmark),
    ]

    print("\nAvailable examples:")
    for i, (name, _) in enumerate(examples, 1):
        print(f"  {i}. {name}")

    print("\nRunning all examples...\n")

    for name, func in examples:
        try:
            func()
        except Exception as e:
            print(f"\n✗ Example '{name}' failed: {e}")
            import traceback
            traceback.print_exc()

    print("\n" + "="*80)
    print("EXAMPLES COMPLETE")
    print("="*80 + "\n")


if __name__ == "__main__":
    main()
