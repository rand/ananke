#!/usr/bin/env python3
"""
Generate pytest test suite from test case specifications.

Fallback generator when ananke CLI is not available. Reads test case
specifications and generates a complete pytest test file.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any


def generate_test_class(spec: Dict[str, Any]) -> str:
    """Generate a complete pytest test class from specification."""
    function_name = spec['function_name']
    class_name = f"Test{function_name[0].upper()}{function_name[1:]}"
    test_cases = spec['test_cases']

    # Group test cases by category
    categories = {}
    for tc in test_cases:
        cat = tc['category']
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(tc)

    # Generate imports
    imports = f'''"""
Generated test suite for {function_name}.

Auto-generated from function docstring specification.
"""

import pytest
from decimal import Decimal
from input.function_spec import {function_name}


'''

    # Generate test class
    class_doc = f'''class {class_name}:
    """
    Comprehensive test suite for {function_name}.

    Generated from docstring specifications with:
    - {len([tc for tc in test_cases if tc['category'] == 'Happy Path'])} happy path tests
    - {len([tc for tc in test_cases if tc['category'] == 'Edge Cases'])} edge case tests
    - {len([tc for tc in test_cases if tc['category'] == 'Error Conditions'])} error condition tests
    - {len([tc for tc in test_cases if tc['category'] == 'Boundary Tests'])} boundary tests

    Target coverage: >90%
    """

'''

    test_methods = []

    # Generate tests for each category
    for category, cases in categories.items():
        test_methods.append(f"    # {category}\n")

        if category == "Error Conditions":
            # Generate error tests
            for tc in cases:
                method = _generate_error_test(tc, function_name)
                test_methods.append(method)
        else:
            # Generate regular tests - check if parametrization is beneficial
            if len(cases) >= 3 and _can_parametrize(cases):
                method = _generate_parametrized_test(cases, function_name, category)
                test_methods.append(method)
            else:
                for tc in cases:
                    method = _generate_regular_test(tc, function_name)
                    test_methods.append(method)

    return imports + class_doc + "\n".join(test_methods)


def _can_parametrize(test_cases: List[Dict]) -> bool:
    """Check if test cases are suitable for parametrization."""
    # All should have same input parameters
    if not test_cases:
        return False

    first_inputs = set(test_cases[0]['inputs'].keys())
    return all(set(tc['inputs'].keys()) == first_inputs for tc in test_cases)


def _generate_parametrized_test(
    test_cases: List[Dict], function_name: str, category: str
) -> str:
    """Generate a parametrized test for similar test cases."""
    # Extract parameter names
    param_names = sorted(test_cases[0]['inputs'].keys())
    param_names.append('expected')

    # Build parameter list
    param_str = ', '.join(param_names)

    # Build test data
    test_data = []
    test_ids = []

    for tc in test_cases:
        inputs = tc['inputs']
        values = [_format_value(inputs.get(p, 'None')) for p in param_names[:-1]]
        values.append(_format_value(tc['expected_output']))
        test_data.append(f"        ({', '.join(values)})")
        test_ids.append(tc['description'].lower().replace(' ', '_')[:30])

    test_data_str = ',\n'.join(test_data)
    test_ids_str = ', '.join(f'"{tid}"' for tid in test_ids)

    method_name = f"test_{category.lower().replace(' ', '_')}_parametrized"

    return f'''    @pytest.mark.parametrize(
        "{param_str}",
        [
{test_data_str}
        ],
        ids=[{test_ids_str}]
    )
    def {method_name}(self, {param_str}):
        """Test {category.lower()} scenarios."""
        result = {function_name}({', '.join(f'{p}={p}' for p in param_names[:-1])})
        assert result == expected, f"Expected {{expected}}, got {{result}}"

'''


def _generate_regular_test(test_case: Dict, function_name: str) -> str:
    """Generate a single test method."""
    desc = test_case['description']
    test_id = test_case['test_id']
    inputs = test_case['inputs']
    expected = test_case['expected_output']

    # Build function call
    args = ', '.join(f"{k}={_format_value(v)}" for k, v in inputs.items())
    expected_formatted = _format_value(expected)

    return f'''    def {test_id}(self):
        """{desc}."""
        result = {function_name}({args})
        assert result == {expected_formatted}, f"Expected {{{expected_formatted}}}, got {{result}}"

'''


def _generate_error_test(test_case: Dict, function_name: str) -> str:
    """Generate a test for error conditions."""
    desc = test_case['description']
    test_id = test_case['test_id']
    inputs = test_case['inputs']
    error_spec = test_case['expected_error']

    # Parse error specification
    if ':' in error_spec:
        error_type, error_msg = error_spec.split(':', 1)
        error_type = error_type.strip()
        error_msg = error_msg.strip()
    else:
        error_type = error_spec
        error_msg = ""

    # Build function call
    args = ', '.join(f"{k}={_format_value(v)}" for k, v in inputs.items())

    match_clause = f', match="{error_msg}"' if error_msg else ''

    return f'''    def {test_id}(self):
        """{desc}."""
        with pytest.raises({error_type}{match_clause}):
            {function_name}({args})

'''


def _format_value(value: Any) -> str:
    """Format a value for Python code."""
    if value is None:
        return "None"

    if isinstance(value, bool):
        return str(value)

    if isinstance(value, (int, float)):
        return str(value)

    # String value - check if it's a number that should be Decimal
    value_str = str(value)

    # Check if it looks like a price/decimal number
    if value_str.replace('.', '').replace('-', '').isdigit():
        return f"Decimal('{value_str}')"

    # Regular string
    return f'"{value_str}"'


def main():
    """Main entry point."""
    if len(sys.argv) < 4:
        print("Usage: generate_tests.py <test_cases.json> <patterns.py> <output.py>")
        sys.exit(1)

    test_cases_file = sys.argv[1]
    output_file = sys.argv[3]

    # Load test case specifications
    with open(test_cases_file, 'r') as f:
        spec = json.load(f)

    # Generate test code
    test_code = generate_test_class(spec)

    # Write output
    with open(output_file, 'w') as f:
        f.write(test_code)

    print(f"Generated {len(spec['test_cases'])} tests to {output_file}")


if __name__ == "__main__":
    main()
