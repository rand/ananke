# Example 5: Test Generator from Specification

**Generate comprehensive pytest test suites automatically from function docstrings.**

## Overview

This example demonstrates how to use Ananke to transform function specifications embedded in docstrings into complete, production-ready pytest test suites with:

- **Comprehensive coverage** - Happy path, edge cases, error conditions, and boundaries
- **Best practices** - Parametrized tests, descriptive names, clear assertions
- **High quality** - >90% code coverage target
- **Maintainable** - Well-organized, documented test code

### What You'll Learn

1. How to write comprehensive test specifications in docstrings
2. How to extract structured test cases from natural language
3. How to generate pytest tests following best practices
4. How to validate generated tests with meta-tests
5. How to achieve high code coverage systematically

### Use Cases

- **Test-Driven Development** - Write specs first, generate tests automatically
- **Legacy Code** - Add comprehensive test coverage to existing code
- **API Development** - Ensure all edge cases and errors are tested
- **Code Review** - Verify test coverage matches specifications
- **Documentation** - Keep tests in sync with function documentation

## Quick Start

```bash
# Run the complete example
./run.sh

# Generated test suite will be in: output/test_calculate_discount.py
# Coverage report will be in: output/coverage.json
```

## What This Example Does

### Input

**Function Specification** (`input/function_spec.py`):
```python
def calculate_discount(
    original_price: Decimal,
    discount_percent: Decimal,
    member_tier: Optional[str] = None,
    quantity: int = 1,
) -> Decimal:
    """
    Calculate the final price after applying discounts.

    Test Cases:
        Happy Path:
            - Basic discount: $100, 10% = $90
            - With gold tier: $100, 10%, gold = $85
            - Bulk discount: $100, 10%, qty=5 = $85

        Error Conditions:
            - Negative price: ValueError "Price cannot be negative"
            - Invalid tier: ValueError "Invalid member tier"
    """
```

**Existing Test Patterns** (`input/existing_tests.py`):
- Class-based organization
- Parametrized tests with `@pytest.mark.parametrize`
- Error testing with `pytest.raises`
- Descriptive test names and assertions

### Process

The example runs through 4 phases:

1. **Extract test cases** from function docstring
2. **Extract pytest patterns** from existing tests
3. **Generate test suite** following patterns and specifications
4. **Validate** generated tests pass and meet coverage targets

### Output

**Generated Test Suite** (`output/test_calculate_discount.py`):
```python
class TestCalculateDiscount:
    """
    Comprehensive test suite for calculate_discount.

    Generated from docstring specifications with:
    - 5 happy path tests
    - 4 edge case tests
    - 6 error condition tests
    - 3 boundary tests

    Target coverage: >90%
    """

    def test_basic_discount(self):
        """Basic discount: $100, 10% = $90."""
        result = calculate_discount(
            original_price=Decimal('100.00'),
            discount_percent=Decimal('10')
        )
        assert result == Decimal('90.00')

    @pytest.mark.parametrize(
        "original_price,discount_percent,member_tier,expected",
        [
            (Decimal('100'), Decimal('10'), 'bronze', Decimal('88')),
            (Decimal('100'), Decimal('10'), 'gold', Decimal('85')),
            # ... more cases
        ],
        ids=["bronze_tier", "gold_tier"]
    )
    def test_member_tier_discounts(self, original_price, discount_percent,
                                   member_tier, expected):
        """Test member tier discount scenarios."""
        result = calculate_discount(original_price, discount_percent, member_tier)
        assert result == expected

    def test_error_negative_price(self):
        """Negative price: ValueError."""
        with pytest.raises(ValueError, match="Price cannot be negative"):
            calculate_discount(Decimal('-100'), Decimal('10'))
```

## Detailed Walkthrough

### Phase 1: Extract Test Case Specifications

```bash
python3 scripts/docstring_to_test_cases.py \
    input/function_spec.py \
    constraints/test_cases.json
```

Parses the docstring and extracts structured test cases:

```json
{
  "function_name": "calculate_discount",
  "test_cases": [
    {
      "category": "Happy Path",
      "description": "Basic discount",
      "inputs": {
        "original_price": "100.00",
        "discount_percent": "10"
      },
      "expected_output": "90.00",
      "expected_error": null,
      "test_id": "test_calculate_discount_happy_path_0"
    }
  ]
}
```

**Key Features**:
- Categorizes tests (Happy Path, Edge Cases, Error Conditions, etc.)
- Extracts input parameters and expected outputs
- Generates unique test IDs
- Identifies error vs. success tests

### Phase 2: Extract Pytest Patterns

```bash
ananke extract input/existing_tests.py \
    --language python \
    -o constraints/pytest_patterns.json
```

Identifies patterns to follow:
- Class-based test organization
- Parametrized test usage
- Error handling with `pytest.raises`
- Assertion message formats
- Test naming conventions

### Phase 3: Generate Test Suite

```bash
ananke generate "[prompt]" \
    --constraints constraints/test_cases.json \
    --constraints constraints/pytest_patterns.json \
    -o output/test_calculate_discount.py
```

Generates a complete pytest test file that:
- Implements all specified test cases
- Groups similar tests with `@pytest.mark.parametrize`
- Uses descriptive names and docstrings
- Includes clear assertion messages
- Follows patterns from existing tests

**Fallback Mode**: If Ananke CLI is not available, uses `scripts/generate_tests.py` for manual generation.

### Phase 4: Validate

Runs multiple validation steps:

1. **Syntax Check**: Verify generated Python is valid
2. **Test Execution**: Run generated tests against the function
3. **Coverage Analysis**: Measure code coverage (target: >90%)
4. **Meta-Validation**: Run quality checks on generated tests

```bash
# Run generated tests
pytest output/test_calculate_discount.py -v

# Check coverage
pytest output/test_calculate_discount.py \
    --cov=input.function_spec \
    --cov-report=term-missing

# Validate test quality
pytest tests/validate_generated_tests.py -v
```

## Test Generation Patterns

### Writing Effective Test Specifications

**Format** in your docstring:
```python
"""
Function description...

Test Cases:
    Category Name:
        - Description: inputs = expected_output
        - Description: inputs = expected_output

    Error Conditions:
        - Description: ErrorType "error message"
"""
```

**Supported Categories**:
- `Happy Path` - Normal successful operations
- `Edge Cases` - Boundary conditions, special values
- `Error Conditions` - Invalid inputs, error scenarios
- `Boundary Tests` - Min/max values, thresholds
- `Type Tests` - Type checking, conversions

**Input Formats**:
```python
# Positional: $100, 10%, 'gold', qty=5
# Named: original_price=$100, discount=10%, tier='gold'
# Mixed: $100, 10%, tier='gold'
```

**Output Formats**:
```python
# Values: = $90, = True, = None
# Errors: ValueError "message", TypeError
```

### Generated Test Patterns

**Individual Tests** (unique test cases):
```python
def test_specific_scenario(self):
    """Descriptive docstring."""
    result = function(args)
    assert result == expected, "Clear error message"
```

**Parametrized Tests** (similar test cases):
```python
@pytest.mark.parametrize(
    "param1,param2,expected",
    [
        (val1, val2, exp1),
        (val3, val4, exp2),
    ],
    ids=["case1", "case2"]
)
def test_category(self, param1, param2, expected):
    """Category description."""
    result = function(param1, param2)
    assert result == expected
```

**Error Tests**:
```python
def test_error_scenario(self):
    """Error scenario description."""
    with pytest.raises(ErrorType, match="error message"):
        function(invalid_args)
```

## Coverage Guide

### Understanding Coverage Metrics

The example targets >90% code coverage:

- **Line Coverage**: Percentage of code lines executed
- **Branch Coverage**: Percentage of conditional branches taken
- **Path Coverage**: Unique execution paths tested

### Achieving High Coverage

**1. Comprehensive Test Specifications**

Include all code paths in your docstring:
```python
Test Cases:
    Happy Path:
        - All main features
        - Default parameter values
        - Optional parameters used

    Edge Cases:
        - Minimum valid values
        - Maximum valid values
        - Boundary conditions
        - Special values (0, None, empty)

    Error Conditions:
        - Each validation check
        - Each error branch
        - Invalid combinations
```

**2. Coverage Analysis**

```bash
# Run with coverage report
pytest output/test_calculate_discount.py \
    --cov=input.function_spec \
    --cov-report=term-missing \
    --cov-report=html:output/htmlcov

# View detailed HTML report
open output/htmlcov/index.html
```

**3. Identify Missing Coverage**

```bash
# Show lines not covered
pytest --cov=input.function_spec --cov-report=term-missing

# Output:
# Name                    Stmts   Miss  Cover   Missing
# -----------------------------------------------------
# function_spec.py           45      3    93%   67-69
```

Add tests for missing lines:
- Line 67-69: Add test case for that branch

**4. Coverage Thresholds**

```bash
# Fail if coverage below target
pytest --cov=input.function_spec --cov-fail-under=90
```

## Customization

### Adapt for Your Use Case

**1. Different Function Types**

For async functions:
```python
async def fetch_data(...):
    """
    Test Cases:
        Happy Path:
            - Success case: url='http://api.com' = {'data': 'value'}
    """

# Generated tests will use pytest-asyncio
@pytest.mark.asyncio
async def test_success_case(self):
    result = await fetch_data(url='http://api.com')
    assert result == {'data': 'value'}
```

For generators:
```python
def generate_items(...):
    """
    Test Cases:
        Happy Path:
            - Basic generation: n=3 = [1, 2, 3]
    """

# Generated tests will consume generator
def test_basic_generation(self):
    result = list(generate_items(n=3))
    assert result == [1, 2, 3]
```

**2. Custom Test Categories**

Add your own categories:
```python
"""
Test Cases:
    Performance Tests:
        - Large input: n=10000 = completes in <1s

    Integration Tests:
        - With database: db=mock_db = saves correctly
"""
```

Update `scripts/docstring_to_test_cases.py` to handle custom categories.

**3. Different Assertion Styles**

Modify `scripts/generate_tests.py` to use:
- `pytest-check` for soft assertions
- Custom assertion helpers
- Fuzzy matching for floats
- Deep equality for complex objects

**4. Test Fixtures**

Add fixture generation:
```python
"""
Fixtures:
    - mock_database: Returns in-memory SQLite database
    - sample_user: Returns User(id=1, name='Test')

Test Cases:
    Happy Path:
        - Create user: user=sample_user, db=mock_database = success
"""
```

## Troubleshooting

### Issue: Generated tests fail syntax check

**Symptoms**: `SyntaxError` when running generated tests

**Cause**: Invalid Python generated due to complex input format

**Solution**:
1. Simplify test case format in docstring
2. Use explicit parameter names: `param=value` instead of positional
3. Check for special characters in strings (quotes, commas)
4. Validate `constraints/test_cases.json` manually

### Issue: Tests pass but coverage is low

**Symptoms**: Coverage <90% despite all tests passing

**Cause**: Missing test cases for some code branches

**Solution**:
1. Run coverage with `--cov-report=term-missing`
2. Identify uncovered lines
3. Add test cases for those branches to docstring
4. Re-generate tests

### Issue: Error tests don't match actual errors

**Symptoms**: `pytest.raises` fails with unexpected error

**Cause**: Error message or type doesn't match specification

**Solution**:
1. Run function manually to see actual error
2. Update docstring with exact error type and message
3. Use regex in error message: `match="Price.*negative"`
4. Re-generate tests

### Issue: Parametrized tests not grouping correctly

**Symptoms**: Individual tests instead of parametrized test

**Cause**: Test cases have different input parameters

**Solution**:
1. Ensure related test cases use same parameters
2. Use `None` or default values for optional parameters
3. Group manually in `scripts/generate_tests.py`

## Meta-Validation Tests

The example includes tests that validate the generated tests:

```bash
pytest tests/validate_generated_tests.py -v
```

**Checks**:
- Valid Python syntax
- Proper imports
- Test class follows conventions
- Test methods have docstrings
- Uses assertions correctly
- Error tests use `pytest.raises`
- All specifications covered
- Tests are discoverable by pytest
- Generated tests pass when run
- Coverage meets target

These ensure the generator produces high-quality output.

## Next Steps

1. **Try the example**:
   ```bash
   ./run.sh
   ```

2. **Customize for your code**:
   - Replace `input/function_spec.py` with your function
   - Update docstring with your test specifications
   - Run the generator

3. **Extend the generator**:
   - Add support for fixtures
   - Handle async functions
   - Generate property-based tests
   - Add performance tests

4. **Integrate into workflow**:
   - Add to pre-commit hooks
   - Run in CI/CD pipeline
   - Generate tests on spec changes
   - Track coverage over time

## Learn More

- [Ananke Documentation](../../docs/README.md)
- [Pytest Best Practices](https://docs.pytest.org/en/stable/goodpractices.html)
- [Example 01: OpenAPI Route Generation](../01-openapi-route-generation/)
- [Example 04: CLI Tool Generator](../04-cli-tool-generator/)

---

**Related Examples**:
- Example 01: OpenAPI Route Generation
- Example 02: Database Migration Generator
- Example 03: React Component Generator
- Example 04: CLI Tool Generator

**Key Concepts**:
- Constraint extraction
- Pattern-based generation
- Test coverage
- Meta-validation
