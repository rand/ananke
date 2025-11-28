#!/usr/bin/env python3
"""
Extract test case specifications from function docstrings.

Parses structured docstrings to extract test cases organized by category
(Happy Path, Edge Cases, Error Conditions, etc.) and outputs them in a
format suitable for constraint-based test generation.
"""

import ast
import json
import sys
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Optional
from pathlib import Path


@dataclass
class TestCase:
    """Represents a single test case extracted from docstring."""

    category: str  # "Happy Path", "Edge Cases", "Error Conditions", etc.
    description: str  # Human-readable description
    inputs: Dict[str, Any]  # Function parameters
    expected_output: Optional[Any]  # Expected return value (if not error)
    expected_error: Optional[str]  # Expected error type/message (if error test)
    test_id: str  # Unique identifier for this test


@dataclass
class FunctionSpec:
    """Complete specification for a function including all test cases."""

    function_name: str
    module_path: str
    parameters: List[Dict[str, str]]  # [{"name": "x", "type": "int", ...}]
    return_type: str
    test_cases: List[TestCase]


def extract_function_info(tree: ast.AST, source_file: str) -> Optional[FunctionSpec]:
    """Extract function signature and docstring from AST."""
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            # Find function with comprehensive docstring
            docstring = ast.get_docstring(node)
            if not docstring or "Test Cases:" not in docstring:
                continue

            # Extract function signature
            params = []
            for arg in node.args.args:
                param_info = {
                    "name": arg.arg,
                    "type": _get_type_annotation(arg.annotation),
                }
                params.append(param_info)

            return_type = _get_type_annotation(node.returns)

            # Parse test cases from docstring
            test_cases = _parse_test_cases(docstring, node.name)

            return FunctionSpec(
                function_name=node.name,
                module_path=source_file,
                parameters=params,
                return_type=return_type,
                test_cases=test_cases,
            )

    return None


def _get_type_annotation(annotation: Optional[ast.AST]) -> str:
    """Convert AST type annotation to string."""
    if annotation is None:
        return "Any"

    if isinstance(annotation, ast.Name):
        return annotation.id
    elif isinstance(annotation, ast.Subscript):
        # Handle Optional[T], List[T], etc.
        value = _get_type_annotation(annotation.value)
        slice_val = _get_type_annotation(annotation.slice)
        return f"{value}[{slice_val}]"
    elif isinstance(annotation, ast.Constant):
        return str(annotation.value)
    else:
        return "Any"


def _parse_test_cases(docstring: str, function_name: str) -> List[TestCase]:
    """Parse test cases from docstring 'Test Cases:' section."""
    test_cases = []
    lines = docstring.split('\n')

    # Find "Test Cases:" section
    in_test_section = False
    current_category = None
    test_counter = 0

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("Test Cases:"):
            in_test_section = True
            continue

        if not in_test_section:
            continue

        # Stop at next major section
        if stripped and not stripped.startswith(('-', ' ')) and stripped.endswith(':'):
            # Check if it's a test category or end of test section
            if stripped in ["Examples:", "Note:", "Returns:", "See Also:"]:
                break
            current_category = stripped.rstrip(':')
            continue

        # Parse individual test case
        if stripped.startswith('-') and current_category:
            test_case = _parse_test_case_line(
                stripped[1:].strip(), current_category, function_name, test_counter
            )
            if test_case:
                test_cases.append(test_case)
                test_counter += 1

    return test_cases


def _parse_test_case_line(
    line: str, category: str, function_name: str, counter: int
) -> Optional[TestCase]:
    """Parse a single test case line like 'Basic discount: $100, 10% = $90'."""
    if ':' not in line:
        return None

    description, spec = line.split(':', 1)
    description = description.strip()
    spec = spec.strip()

    # Create test ID
    test_id = f"test_{function_name}_{category.lower().replace(' ', '_')}_{counter}"

    # Parse based on category
    if category == "Error Conditions":
        # Format: "Negative price: ValueError \"Price cannot be negative\""
        if "ValueError" in spec or "TypeError" in spec or "KeyError" in spec:
            error_type = "ValueError"  # Default
            for err in ["ValueError", "TypeError", "KeyError", "AttributeError"]:
                if err in spec:
                    error_type = err
                    break

            # Extract error message
            error_msg = ""
            if '"' in spec:
                start = spec.index('"') + 1
                end = spec.rindex('"')
                error_msg = spec[start:end]

            # Try to infer inputs from description
            inputs = _infer_inputs_from_description(description, function_name)

            return TestCase(
                category=category,
                description=description,
                inputs=inputs,
                expected_output=None,
                expected_error=f"{error_type}: {error_msg}",
                test_id=test_id,
            )
    else:
        # Format: "Basic discount: $100, 10% = $90"
        # Parse inputs and expected output
        if '=' in spec:
            inputs_str, output_str = spec.split('=', 1)
            inputs = _parse_inputs(inputs_str.strip(), function_name)
            expected = _parse_output(output_str.strip())

            return TestCase(
                category=category,
                description=description,
                inputs=inputs,
                expected_output=expected,
                expected_error=None,
                test_id=test_id,
            )

    return None


def _infer_inputs_from_description(description: str, function_name: str) -> Dict[str, Any]:
    """Infer function inputs from test case description."""
    inputs = {}

    # Common patterns for calculate_discount
    if "negative price" in description.lower():
        inputs["original_price"] = "-100.00"
    elif "negative discount" in description.lower():
        inputs["original_price"] = "100.00"
        inputs["discount_percent"] = "-10"
    elif "discount > 100" in description.lower() or "over 100" in description.lower():
        inputs["original_price"] = "100.00"
        inputs["discount_percent"] = "150"
    elif "invalid tier" in description.lower():
        inputs["original_price"] = "100.00"
        inputs["discount_percent"] = "10"
        inputs["member_tier"] = "invalid_tier"
    elif "zero quantity" in description.lower():
        inputs["original_price"] = "100.00"
        inputs["discount_percent"] = "10"
        inputs["quantity"] = "0"
    elif "negative quantity" in description.lower():
        inputs["original_price"] = "100.00"
        inputs["discount_percent"] = "10"
        inputs["quantity"] = "-1"

    return inputs


def _parse_inputs(inputs_str: str, function_name: str) -> Dict[str, Any]:
    """Parse input specification like '$100, 10%, gold, qty=5'."""
    inputs = {}
    parts = [p.strip() for p in inputs_str.split(',')]

    positional_index = 0
    for part in parts:
        # Handle key=value format
        if '=' in part:
            key, value = part.split('=', 1)
            key = key.strip()
            value = value.strip()

            # Parse value
            if value.startswith('$'):
                value = value[1:]
            elif value.startswith("'") or value.startswith('"'):
                value = value.strip("'\"")

            inputs[key] = value
        else:
            # Positional arguments - map to function parameters
            # For calculate_discount: original_price, discount_percent, member_tier, quantity
            if positional_index == 0:  # First positional: original_price
                value = part.strip('$')
                inputs["original_price"] = value
            elif positional_index == 1:  # Second positional: discount_percent
                value = part.strip('%')
                inputs["discount_percent"] = value
            elif positional_index == 2:  # Third positional: member_tier
                value = part.strip("'\"")
                if value and not value.isdigit():
                    inputs["member_tier"] = value

            positional_index += 1

    return inputs


def _parse_output(output_str: str) -> Any:
    """Parse expected output like '$90' or 'True'."""
    output = output_str.strip()

    # Handle currency - extract just the number before any parenthetical
    if output.startswith('$'):
        output = output[1:]
        # Remove parenthetical explanations like "(extra 5%)"
        if '(' in output:
            output = output.split('(')[0].strip()
        # Remove text like "per item"
        if ' ' in output:
            output = output.split()[0]
        return output

    # Handle boolean
    if output.lower() in ['true', 'false']:
        return output.lower() == 'true'

    # Handle None
    if output.lower() == 'none':
        return None

    # Return as string, will be converted appropriately
    return output


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: docstring_to_test_cases.py <function_spec.py> [output.json]")
        sys.exit(1)

    source_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    # Parse source file
    with open(source_file, 'r') as f:
        source_code = f.read()

    tree = ast.parse(source_code)
    spec = extract_function_info(tree, source_file)

    if not spec:
        print("Error: No function with test cases found in source file", file=sys.stderr)
        sys.exit(1)

    # Convert to JSON
    output = {
        "function_name": spec.function_name,
        "module_path": spec.module_path,
        "parameters": spec.parameters,
        "return_type": spec.return_type,
        "test_cases": [asdict(tc) for tc in spec.test_cases],
    }

    # Output
    json_str = json.dumps(output, indent=2)
    if output_file:
        with open(output_file, 'w') as f:
            f.write(json_str)
        print(f"Extracted {len(spec.test_cases)} test cases to {output_file}")
    else:
        print(json_str)


if __name__ == "__main__":
    main()
