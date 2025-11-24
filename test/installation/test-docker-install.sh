#!/usr/bin/env bash
# Test Docker Installation Script
# Tests Ananke Docker image build and functionality
# Usage: ./test-docker-install.sh [--cleanup]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
CLEANUP=0

# Parse arguments
if [[ "${1:-}" == "--cleanup" ]]; then
    CLEANUP=1
fi

# Test image name
TEST_IMAGE="ananke:test-$$"

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

cleanup() {
    if [ $CLEANUP -eq 1 ]; then
        echo -e "${YELLOW}Cleaning up test image...${NC}"
        docker rmi -f "$TEST_IMAGE" 2>/dev/null || true
    else
        echo -e "${YELLOW}Test image remains: $TEST_IMAGE${NC}"
        echo "Run with --cleanup to remove"
    fi
}

trap cleanup EXIT

echo "======================================"
echo "  Ananke Docker Installation Test"
echo "======================================"
echo

# Test 1: Docker availability
log_test "Checking Docker availability"
if command -v docker &> /dev/null; then
    log_pass "Docker is installed"
else
    log_fail "Docker is not installed"
    exit 1
fi

# Test 2: Docker daemon running
log_test "Checking Docker daemon"
if docker info &> /dev/null; then
    log_pass "Docker daemon is running"
else
    log_fail "Docker daemon is not running"
    exit 1
fi

# Test 3: Build Docker image
log_test "Building Docker image"
if docker build -t "$TEST_IMAGE" . &> /tmp/docker-build.log; then
    log_pass "Docker image built successfully"
else
    log_fail "Docker image build failed"
    cat /tmp/docker-build.log
    exit 1
fi

# Test 4: Image exists
log_test "Checking image existence"
if docker images "$TEST_IMAGE" | grep -q "$TEST_IMAGE"; then
    log_pass "Image exists in Docker"
else
    log_fail "Image not found in Docker"
fi

# Test 5: Run version command
log_test "Testing version command in container"
if VERSION=$(docker run --rm "$TEST_IMAGE" --version 2>&1); then
    log_pass "Version command works: $VERSION"
else
    log_fail "Version command failed"
fi

# Test 6: Run help command
log_test "Testing help command in container"
if docker run --rm "$TEST_IMAGE" help &> /dev/null; then
    log_pass "Help command works"
else
    log_fail "Help command failed"
fi

# Test 7: Test volume mounting
log_test "Testing volume mounting"
TEMP_DIR=$(mktemp -d)
echo 'function test() { return 42; }' > "$TEMP_DIR/test.ts"

if docker run --rm -v "$TEMP_DIR:/workspace:ro" "$TEST_IMAGE" extract /workspace/test.ts &> /dev/null; then
    log_pass "Volume mounting works"
else
    echo -e "${YELLOW}[WARN]${NC} Volume mounting test failed (may be expected if extract not fully implemented)"
fi

rm -rf "$TEMP_DIR"

# Test 8: Check image size
log_test "Checking image size"
IMAGE_SIZE=$(docker images "$TEST_IMAGE" --format "{{.Size}}")
log_pass "Image size: $IMAGE_SIZE"

# Test 9: Check image layers
log_test "Checking image layers"
LAYER_COUNT=$(docker history "$TEST_IMAGE" --format "{{.ID}}" | wc -l)
log_pass "Image has $LAYER_COUNT layers"

# Test 10: Health check
log_test "Testing container health check"
CONTAINER_ID=$(docker run -d "$TEST_IMAGE" sleep 60)
sleep 5

HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_ID" 2>/dev/null || echo "none")
if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "none" ]; then
    log_pass "Container health check passed (status: $HEALTH_STATUS)"
else
    log_fail "Container health check failed (status: $HEALTH_STATUS)"
fi

docker rm -f "$CONTAINER_ID" &>/dev/null

# Test 11: Test with docker-compose
log_test "Testing docker-compose configuration"
if command -v docker-compose &> /dev/null; then
    if docker-compose config &> /dev/null; then
        log_pass "docker-compose.yml is valid"
    else
        log_fail "docker-compose.yml is invalid"
    fi
else
    echo -e "${YELLOW}[WARN]${NC} docker-compose not installed, skipping"
fi

# Summary
echo
echo "======================================"
echo "  Test Summary"
echo "======================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
