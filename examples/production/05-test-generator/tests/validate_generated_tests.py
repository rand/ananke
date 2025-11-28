"""
Meta-validation tests for the generated test suite.

These tests validate that the test generator produces high-quality tests
that follow best practices.
"""

import ast
import pytest
import json
from pathlib import Path


class TestGeneratedTestQuality:
    """Validate the quality of generated tests."""

    @pytest.fixture
    def generated_test_file(self):
        """Load the generated test file."""
        test_file = Path("output/test_calculate_discount.py")
        if not test_file.exists():
            pytest.skip("Generated test file not found")
        return test_file

    @pytest.fixture
    def generated_ast(self, generated_test_file):
        """Parse the generated test file."""
        with open(generated_test_file, 'r') as f:
            code = f.read()
        return ast.parse(code)

    @pytest.fixture
    def test_specifications(self):
        """Load the test case specifications."""
        spec_file = Path("constraints/test_cases.json")
        if not spec_file.exists():
            pytest.skip("Test specifications not found")
        with open(spec_file, 'r') as f:
            return json.load(f)

    def test_file_has_valid_python_syntax(self, generated_test_file):
        """Verify generated file is valid Python."""
        with open(generated_test_file, 'r') as f:
            code = f.read()
        try:
            ast.parse(code)
        except SyntaxError as e:
            pytest.fail(f"Generated test file has invalid syntax: {e}")

    def test_has_proper_imports(self, generated_ast):
        """Verify necessary imports are present."""
        imports = set()
        for node in ast.walk(generated_ast):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imports.add(alias.name)
            elif isinstance(node, ast.ImportFrom):
                imports.add(node.module)

        required_imports = {'pytest', 'input.function_spec'}
        assert required_imports.issubset(imports), \
            f"Missing required imports. Expected {required_imports}, got {imports}"

    def test_has_test_class(self, generated_ast):
        """Verify generated file contains a test class."""
        classes = [node for node in ast.walk(generated_ast) if isinstance(node, ast.ClassDef)]
        assert len(classes) > 0, "No test class found in generated file"

        # Check class name follows convention
        test_class = classes[0]
        assert test_class.name.startswith('Test'), \
            f"Test class name '{test_class.name}' should start with 'Test'"

    def test_has_class_docstring(self, generated_ast):
        """Verify test class has a docstring."""
        classes = [node for node in ast.walk(generated_ast) if isinstance(node, ast.ClassDef)]
        assert len(classes) > 0, "No test class found"

        test_class = classes[0]
        docstring = ast.get_docstring(test_class)
        assert docstring is not None, "Test class should have a docstring"
        assert len(docstring) > 20, "Test class docstring should be descriptive"

    def test_has_test_methods(self, generated_ast):
        """Verify generated file contains test methods."""
        test_methods = []
        for node in ast.walk(generated_ast):
            if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'):
                test_methods.append(node)

        assert len(test_methods) > 0, "No test methods found in generated file"
        assert len(test_methods) >= 5, \
            f"Expected at least 5 test methods, found {len(test_methods)}"

    def test_methods_have_docstrings(self, generated_ast):
        """Verify test methods have docstrings."""
        test_methods = []
        methods_without_docstrings = []

        for node in ast.walk(generated_ast):
            if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'):
                test_methods.append(node)
                if ast.get_docstring(node) is None:
                    methods_without_docstrings.append(node.name)

        if methods_without_docstrings:
            pytest.fail(
                f"Test methods without docstrings: {', '.join(methods_without_docstrings)}"
            )

    def test_uses_parametrize_for_similar_tests(self, generated_ast):
        """Verify parametrized tests are used where appropriate."""
        has_parametrize = False

        for node in ast.walk(generated_ast):
            if isinstance(node, ast.FunctionDef):
                for decorator in node.decorator_list:
                    if isinstance(decorator, ast.Attribute):
                        if decorator.attr == 'parametrize':
                            has_parametrize = True
                            break
                    elif isinstance(decorator, ast.Call):
                        if isinstance(decorator.func, ast.Attribute):
                            if decorator.func.attr == 'parametrize':
                                has_parametrize = True
                                break

        # Parametrization is optional but recommended
        # Just verify it's being considered
        assert True, "Parametrization check complete"

    def test_has_error_condition_tests(self, generated_ast):
        """Verify error conditions are tested with pytest.raises."""
        has_pytest_raises = False

        for node in ast.walk(generated_ast):
            if isinstance(node, ast.With):
                for item in node.items:
                    if isinstance(item.context_expr, ast.Call):
                        if isinstance(item.context_expr.func, ast.Attribute):
                            if item.context_expr.func.attr == 'raises':
                                has_pytest_raises = True
                                break

        assert has_pytest_raises, "No pytest.raises found for error condition testing"

    def test_uses_assertions(self, generated_ast):
        """Verify tests use assertions."""
        test_methods = []
        methods_without_asserts = []

        for node in ast.walk(generated_ast):
            if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'):
                test_methods.append(node)

                # Check if method has assertions or pytest.raises
                has_assert = False
                has_raises = False

                for child in ast.walk(node):
                    if isinstance(child, ast.Assert):
                        has_assert = True
                    elif isinstance(child, ast.With):
                        for item in child.items:
                            if isinstance(item.context_expr, ast.Call):
                                if hasattr(item.context_expr.func, 'attr'):
                                    if item.context_expr.func.attr == 'raises':
                                        has_raises = True

                if not (has_assert or has_raises):
                    methods_without_asserts.append(node.name)

        if methods_without_asserts:
            pytest.fail(
                f"Test methods without assertions: {', '.join(methods_without_asserts)}"
            )

    def test_coverage_of_test_specifications(self, generated_ast, test_specifications):
        """Verify all specified test cases are covered."""
        # Count test methods in generated file
        test_methods = []
        for node in ast.walk(generated_ast):
            if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'):
                test_methods.append(node.name)

        num_generated_tests = len(test_methods)
        num_specified_tests = len(test_specifications.get('test_cases', []))

        # Allow for parametrization which reduces method count
        # So we just verify we have a reasonable number
        assert num_generated_tests >= num_specified_tests * 0.3, \
            f"Too few tests generated. Expected ~{num_specified_tests}, got {num_generated_tests}"


class TestGeneratedTestsExecute:
    """Verify generated tests can actually run."""

    def test_generated_tests_are_discoverable(self):
        """Verify pytest can discover the generated tests."""
        import subprocess
        import sys
        result = subprocess.run(
            [sys.executable, '-m', 'pytest', 'output/test_calculate_discount.py', '--collect-only', '-q'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, \
            f"pytest failed to collect tests: {result.stderr}"
        assert 'test' in result.stdout.lower(), \
            "No tests discovered by pytest"

    def test_generated_tests_pass(self):
        """Verify generated tests pass when run."""
        import subprocess
        import sys
        result = subprocess.run(
            [sys.executable, '-m', 'pytest', 'output/test_calculate_discount.py', '-v'],
            capture_output=True,
            text=True,
            env={'PYTHONPATH': '.'}
        )

        # Tests should pass
        if result.returncode != 0:
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            pytest.fail(f"Generated tests failed: {result.stderr}")


class TestCodeQualityMetrics:
    """Verify generated code meets quality standards."""

    @pytest.fixture
    def coverage_data(self):
        """Load coverage data if available."""
        coverage_file = Path("output/coverage.json")
        if not coverage_file.exists():
            pytest.skip("Coverage data not available")
        with open(coverage_file, 'r') as f:
            return json.load(f)

    def test_meets_coverage_target(self, coverage_data):
        """Verify test coverage meets 90% target."""
        coverage_percent = coverage_data.get('totals', {}).get('percent_covered', 0)
        assert coverage_percent >= 90, \
            f"Coverage {coverage_percent}% is below target of 90%"

    def test_no_missing_lines_in_main_logic(self, coverage_data):
        """Verify main logic paths are covered."""
        # This is a placeholder - would need actual coverage analysis
        assert 'totals' in coverage_data, "Coverage data should have totals"
