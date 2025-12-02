#!/bin/bash
#
# Unified test runner for Ananke evaluation framework
# Supports Jest (TypeScript) and pytest (Python) test execution
#
# Usage:
#   ./run_tests.sh <language> <test_file> <implementation_file> <output_json>
#
# Args:
#   language: "typescript" or "python"
#   test_file: Path to test file
#   implementation_file: Path to implementation file
#   output_json: Path to output JSON results file
#

set -euo pipefail

LANGUAGE="$1"
TEST_FILE="$2"
IMPL_FILE="$3"
OUTPUT_JSON="$4"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_JSON")"

# Function to run Jest tests
run_jest() {
    local test_file="$1"
    local impl_file="$2"
    local output_json="$3"

    # Create temporary directory for test execution
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Extract the expected module name from the test file path
    # e.g., binary_search.test.ts -> binary_search.ts
    local test_basename=$(basename "$test_file")
    local module_name="${test_basename%.test.ts}.ts"

    # Copy test file as-is
    cp "$test_file" "$temp_dir/"

    # Copy implementation with the correct module name so imports work
    cp "$impl_file" "$temp_dir/$module_name"

    # Create minimal package.json
    cat > "$temp_dir/package.json" <<EOF
{
  "name": "ananke-test",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "jest --json --outputFile=results.json"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "jest": "^29.5.0",
    "ts-jest": "^29.1.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.0.0"
  }
}
EOF

    # Create Jest config
    cat > "$temp_dir/jest.config.js" <<EOF
export default {
  preset: 'ts-jest',
  testEnvironment: 'node',
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx'],
  testMatch: ['**/*.test.ts', '**/*.test.tsx'],
  collectCoverage: true,
  coverageReporters: ['json', 'text'],
  coverageDirectory: 'coverage',
  verbose: true
};
EOF

    # Create tsconfig.json
    cat > "$temp_dir/tsconfig.json" <<EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "esModuleInterop": true,
    "skipLibCheck": true,
    "strict": true,
    "resolveJsonModule": true
  }
}
EOF

    # Install dependencies
    cd "$temp_dir"

    # Debug: Check if npm is available
    if ! command -v npm &> /dev/null; then
        cat > "$output_json" <<EOF
{
  "success": false,
  "language": "typescript",
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "duration_ms": 1000,
  "coverage_percent": 0,
  "error": "npm not found in PATH"
}
EOF
        return 1
    fi

    npm install --silent > /tmp/npm_install.log 2>&1 || {
        cat > "$output_json" <<EOF
{
  "success": false,
  "language": "typescript",
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "duration_ms": 1000,
  "coverage_percent": 0,
  "error": "Failed to install dependencies"
}
EOF
        return 1
    }

    # Run tests
    # Use gdate (GNU date) if available, otherwise use date with seconds precision
    if command -v gdate &> /dev/null; then
        local start_time=$(gdate +%s%3N)
    else
        local start_time=$(($(date +%s) * 1000))
    fi

    # Debug: Log temp dir contents before running tests
    echo "=== DEBUG: Temp dir contents before test ===" >> /tmp/jest_debug.log
    ls -la "$temp_dir" >> /tmp/jest_debug.log 2>&1

    if npm test -- --no-coverage > test_output.txt 2>&1; then
        local success=true
    else
        local success=false
    fi

    # Debug: Log test output
    echo "=== DEBUG: Test output ===" >> /tmp/jest_debug.log
    cat test_output.txt >> /tmp/jest_debug.log 2>&1

    if command -v gdate &> /dev/null; then
        local end_time=$(gdate +%s%3N)
    else
        local end_time=$(($(date +%s) * 1000))
    fi
    local duration_ms=$((end_time - start_time))

    # Parse Jest JSON output
    if [ -f results.json ]; then
        local total_tests=$(jq '.numTotalTests' results.json)
        local passed_tests=$(jq '.numPassedTests' results.json)
        local failed_tests=$(jq '.numFailedTests' results.json)

        # Extract coverage if available
        local coverage=0
        if [ -f coverage/coverage-summary.json ]; then
            coverage=$(jq '.total.lines.pct' coverage/coverage-summary.json)
        fi

        # Create output JSON
        cat > "$output_json" <<EOF
{
  "success": $success,
  "language": "typescript",
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "failed_tests": $failed_tests,
  "duration_ms": $duration_ms,
  "coverage_percent": $coverage
}
EOF
    else
        cat > "$output_json" <<EOF
{
  "success": false,
  "language": "typescript",
  "error": "No test results generated"
}
EOF
    fi
}

# Function to run pytest tests
run_pytest() {
    local test_file="$1"
    local impl_file="$2"
    local output_json="$3"

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Extract the expected module name from the test file path
    # e.g., test_binary_search.py -> binary_search.py
    local test_basename=$(basename "$test_file")
    local module_name="${test_basename#test_}"

    # Copy test file as-is
    cp "$test_file" "$temp_dir/"

    # Copy implementation with the correct module name so imports work
    cp "$impl_file" "$temp_dir/$module_name"

    cd "$temp_dir"

    # Use gdate (GNU date) if available, otherwise use date with seconds precision
    if command -v gdate &> /dev/null; then
        local start_time=$(gdate +%s%3N)
    else
        local start_time=$(($(date +%s) * 1000))
    fi

    # Try pytest with JSON report first, fall back to parsing text output
    local use_json_report=false
    if python3 -c "import pytest_json_report" 2>/dev/null; then
        use_json_report=true
    fi

    if [ "$use_json_report" = true ]; then
        # Use JSON report plugin
        if pytest --json-report --json-report-file=results.json --cov --cov-report=json > /dev/null 2>&1; then
            local success=true
        else
            local success=false
        fi
    else
        # Fallback: parse pytest text output
        pytest -v > test_output.txt 2>&1
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            local success=true
        else
            local success=false
        fi
    fi

    if command -v gdate &> /dev/null; then
        local end_time=$(gdate +%s%3N)
    else
        local end_time=$(($(date +%s) * 1000))
    fi
    local duration_ms=$((end_time - start_time))

    # Parse results based on method used
    if [ "$use_json_report" = true ] && [ -f results.json ]; then
        local total_tests=$(jq '.summary.total' results.json)
        local passed_tests=$(jq '.summary.passed // 0' results.json)
        local failed_tests=$(jq '.summary.failed // 0' results.json)

        # Extract coverage
        local coverage=0
        if [ -f coverage.json ]; then
            coverage=$(jq '.totals.percent_covered' coverage.json)
        fi

        cat > "$output_json" <<EOF
{
  "success": $success,
  "language": "python",
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "failed_tests": $failed_tests,
  "duration_ms": $duration_ms,
  "coverage_percent": $coverage
}
EOF
    elif [ -f test_output.txt ]; then
        # Parse pytest text output
        # Look for summary line like: "16 passed in 0.03s" or "10 passed, 2 failed in 0.05s"
        local summary_line=$(grep -E "passed|failed" test_output.txt | tail -1)

        local passed_tests=0
        local failed_tests=0

        # Extract passed count
        if echo "$summary_line" | grep -qE "[0-9]+ passed"; then
            passed_tests=$(echo "$summary_line" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
        fi

        # Extract failed count
        if echo "$summary_line" | grep -qE "[0-9]+ failed"; then
            failed_tests=$(echo "$summary_line" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+")
        fi

        local total_tests=$((passed_tests + failed_tests))

        cat > "$output_json" <<EOF
{
  "success": $success,
  "language": "python",
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "failed_tests": $failed_tests,
  "duration_ms": $duration_ms,
  "coverage_percent": 0
}
EOF
    else
        cat > "$output_json" <<EOF
{
  "success": false,
  "language": "python",
  "error": "No test results generated"
}
EOF
    fi
}

# Main execution
case "$LANGUAGE" in
    typescript)
        run_jest "$TEST_FILE" "$IMPL_FILE" "$OUTPUT_JSON"
        ;;
    python)
        run_pytest "$TEST_FILE" "$IMPL_FILE" "$OUTPUT_JSON"
        ;;
    *)
        echo "Error: Unsupported language: $LANGUAGE"
        echo "Supported languages: typescript, python"
        exit 1
        ;;
esac
