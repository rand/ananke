#!/bin/bash
# Example 5: Test Generator from Specification
# Demonstrates: Automated pytest test suite generation from docstring specifications

set -e  # Exit on error

# Color output helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================="
echo "Example 5: Test Generator"
echo "========================================="
echo ""
echo "Generates comprehensive pytest test suite from function docstrings"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    exit 1
fi

if ! command -v ananke &> /dev/null; then
    echo -e "${YELLOW}Warning: ananke CLI not found${NC}"
    echo "Install with: cd ../../ && zig build"
    echo "Continuing with manual generation for demonstration..."
    ANANKE_AVAILABLE=false
else
    ANANKE_AVAILABLE=true
fi

# Setup Python virtual environment if needed
if [ ! -d "venv" ]; then
    echo -e "${BLUE}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
pip install -q -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Phase 1: Extract test case specifications from docstring
echo ""
echo -e "${BLUE}[1/4] Extracting test cases from function docstring...${NC}"
python3 scripts/docstring_to_test_cases.py \
    input/function_spec.py \
    constraints/test_cases.json
echo -e "${GREEN}✓ Extracted test case specifications${NC}"
echo "  Found: $(python3 -c "import json; print(len(json.load(open('constraints/test_cases.json'))['test_cases']))" 2>/dev/null || echo "N") test cases"

# Phase 2: Extract pytest patterns from existing tests
echo ""
echo -e "${BLUE}[2/4] Extracting pytest patterns from existing tests...${NC}"
if [ "$ANANKE_AVAILABLE" = true ]; then
    ananke extract input/existing_tests.py \
        --language python \
        --format json \
        -o constraints/pytest_patterns.json
    echo -e "${GREEN}✓ Extracted pytest patterns${NC}"
else
    echo -e "${YELLOW}⚠ Skipping pattern extraction (ananke not available)${NC}"
    # Create minimal pattern file for demo
    echo '{"patterns": ["class-based", "parametrized", "descriptive-names"]}' > constraints/pytest_patterns.json
fi

# Phase 3: Generate test file
echo ""
echo -e "${BLUE}[3/4] Generating pytest test suite...${NC}"

# Create generation prompt
GENERATION_PROMPT="Generate a comprehensive pytest test suite for the calculate_discount function.

Requirements:
1. Use class-based organization (TestCalculateDiscount)
2. Create test methods for all test cases in constraints/test_cases.json
3. Use @pytest.mark.parametrize for similar test cases
4. Use pytest.raises for error condition tests
5. Include clear docstrings and assertions with helpful messages
6. Follow patterns from input/existing_tests.py
7. Import the function from input.function_spec
8. Use descriptive test method names like test_basic_discount, test_error_negative_price
9. Group tests by category (happy path, edge cases, errors, boundaries)
10. Target >90% code coverage

Output a complete, runnable pytest test file."

if [ "$ANANKE_AVAILABLE" = true ]; then
    ananke generate "$GENERATION_PROMPT" \
        --constraints constraints/test_cases.json \
        --constraints constraints/pytest_patterns.json \
        --max-tokens 4000 \
        -o output/test_calculate_discount.py
    echo -e "${GREEN}✓ Generated test suite${NC}"
else
    echo -e "${YELLOW}⚠ Generating tests manually (ananke not available)${NC}"
    # Generate tests using the Python script as fallback
    python3 scripts/generate_tests.py \
        constraints/test_cases.json \
        input/existing_tests.py \
        output/test_calculate_discount.py
    echo -e "${GREEN}✓ Generated test suite (manual mode)${NC}"
fi

# Phase 4: Validate generated tests
echo ""
echo -e "${BLUE}[4/4] Validating generated tests...${NC}"

# First, check if generated test file exists and is valid Python
if [ ! -f "output/test_calculate_discount.py" ]; then
    echo -e "${RED}✗ Generated test file not found${NC}"
    exit 1
fi

python3 -m py_compile output/test_calculate_discount.py
echo -e "${GREEN}✓ Generated tests are valid Python${NC}"

# Run the generated tests against the function
echo ""
echo -e "${BLUE}Running generated tests...${NC}"
PYTHONPATH="${PYTHONPATH}:." pytest output/test_calculate_discount.py -v --tb=short

# Check coverage
echo ""
echo -e "${BLUE}Checking test coverage...${NC}"
PYTHONPATH="${PYTHONPATH}:." pytest output/test_calculate_discount.py \
    --cov=input.function_spec \
    --cov-report=term-missing \
    --cov-report=json:output/coverage.json \
    -v

# Extract coverage percentage
COVERAGE=$(python3 -c "import json; data=json.load(open('output/coverage.json')); print(f\"{data['totals']['percent_covered']:.1f}\")" 2>/dev/null || echo "unknown")

if [ "$COVERAGE" != "unknown" ]; then
    if (( $(echo "$COVERAGE >= 90" | bc -l) )); then
        echo -e "${GREEN}✓ Coverage: ${COVERAGE}% (target: >90%)${NC}"
    else
        echo -e "${YELLOW}⚠ Coverage: ${COVERAGE}% (target: >90%)${NC}"
    fi
fi

# Run meta-validation tests
echo ""
echo -e "${BLUE}Running meta-validation tests...${NC}"
pytest tests/validate_generated_tests.py -v
echo -e "${GREEN}✓ Meta-validation passed${NC}"

# Success message
echo ""
echo "========================================="
echo -e "${GREEN}✓ Example complete!${NC}"
echo "========================================="
echo ""
echo "Generated test suite: output/test_calculate_discount.py"
echo "Test specifications: constraints/test_cases.json"
echo "Coverage report: output/coverage.json"
echo ""
echo "Summary:"
echo "  - Test cases generated: $(grep -c 'def test_' output/test_calculate_discount.py 2>/dev/null || echo '?')"
echo "  - Code coverage: ${COVERAGE}%"
echo ""
echo "Next steps:"
echo "  - Review generated tests in output/test_calculate_discount.py"
echo "  - Try modifying the docstring in input/function_spec.py"
echo "  - Run tests individually: pytest output/test_calculate_discount.py::TestCalculateDiscount::test_basic_discount -v"
echo "  - Read the full README.md for customization guide"
echo ""
