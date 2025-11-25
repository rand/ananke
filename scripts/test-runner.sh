#!/usr/bin/env bash
# Test Runner Wrapper - Solves --listen=- pipe deadlock issue
#
# Problem: zig build test with --listen=- flag hangs when output is piped
# Solution: Redirect stdin to /dev/null to prevent blocking
#
# Usage: ./scripts/test-runner.sh [filter-pattern]

set -euo pipefail

# Configuration
TEST_LOG_DIR="${TEST_LOG_DIR:-.test-logs}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${TEST_LOG_DIR}/test_${TIMESTAMP}.log"
TIMEOUT_SECONDS="${TEST_TIMEOUT:-300}"  # 5 minute default
FILTER_PATTERN="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$TEST_LOG_DIR"

# Create symlink to latest log
LATEST_LINK="${TEST_LOG_DIR}/test_latest.log"

echo "========================================="
echo "Ananke Test Runner"
echo "========================================="
echo "Timeout: ${TIMEOUT_SECONDS}s"
echo "Log file: $LOG_FILE"
if [ -n "$FILTER_PATTERN" ]; then
    echo "Filter: $FILTER_PATTERN"
fi
echo ""

# Function to run tests with timeout using background process
run_with_timeout() {
    local cmd="$1"
    local timeout=$2
    local logfile="$3"

    # Run command in background, redirecting stdin to /dev/null
    # This is the CRITICAL fix for --listen=- hang
    eval "$cmd < /dev/null" > "$logfile" 2>&1 &
    local pid=$!

    # Wait for process with timeout
    local count=0
    while kill -0 $pid 2>/dev/null; do
        if [ $count -ge $timeout ]; then
            echo -e "${RED}✗ Test timeout after ${timeout}s${NC}"
            kill -9 $pid 2>/dev/null || true
            return 124  # Standard timeout exit code
        fi
        sleep 1
        ((count++))

        # Show progress every 30 seconds
        if [ $((count % 30)) -eq 0 ]; then
            echo "  ... still running (${count}s elapsed)"
        fi
    done

    # Get exit code
    wait $pid
    return $?
}

# Run tests
echo "Running: zig build test --summary all"
echo ""

if run_with_timeout "zig build test --summary all" "$TIMEOUT_SECONDS" "$LOG_FILE"; then
    EXIT_CODE=0
else
    EXIT_CODE=$?
fi

# Create/update symlink to latest log
ln -sf "$(basename "$LOG_FILE")" "$LATEST_LINK"

# Display output
echo ""
echo "========================================="
echo "Test Output"
echo "========================================="
if [ -n "$FILTER_PATTERN" ]; then
    grep -E "$FILTER_PATTERN" "$LOG_FILE" || echo "No matches for pattern: $FILTER_PATTERN"
else
    # Show full output with intelligent truncation
    if [ $(wc -l < "$LOG_FILE") -gt 100 ]; then
        echo "(Showing last 100 lines, see $LOG_FILE for full output)"
        echo ""
        tail -100 "$LOG_FILE"
    else
        cat "$LOG_FILE"
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="

# Extract summary from log
if grep -q "Build Summary" "$LOG_FILE"; then
    grep -A 20 "Build Summary" "$LOG_FILE" | head -25
else
    # Try to extract pass/fail counts
    PASSED=$(grep -c "passed" "$LOG_FILE" 2>/dev/null || echo "0")
    FAILED=$(grep -c "failed" "$LOG_FILE" 2>/dev/null || echo "0")
    echo "Tests passed: $PASSED"
    echo "Tests failed: $FAILED"
fi

# Show any memory leaks
if grep -q "leaked" "$LOG_FILE"; then
    echo ""
    echo -e "${YELLOW}⚠ Memory leaks detected:${NC}"
    grep "leaked" "$LOG_FILE" | head -5
fi

# Show exit status
echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Tests passed${NC}"
elif [ $EXIT_CODE -eq 124 ]; then
    echo -e "${RED}✗ Tests timed out after ${TIMEOUT_SECONDS}s${NC}"
else
    echo -e "${RED}✗ Tests failed (exit code: $EXIT_CODE)${NC}"

    # Show first few failures
    echo ""
    echo "First failures:"
    grep -E "^error:" "$LOG_FILE" | head -5 || echo "(No error details available)"
fi

# Cleanup old logs (keep last 10)
LOG_COUNT=$(ls -1 "$TEST_LOG_DIR"/test_*.log 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -gt 10 ]; then
    ls -1t "$TEST_LOG_DIR"/test_*.log | tail -n +11 | xargs rm -f
    echo ""
    echo "Cleaned up old log files (keeping last 10)"
fi

exit $EXIT_CODE
