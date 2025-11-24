#!/usr/bin/env bash
# Test macOS Installation Script
# Tests Ananke installation on macOS systems
# Usage: ./test-macos-install.sh [--cleanup]

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

# Test directory
TEST_PREFIX="/tmp/ananke-test-$$"

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
        echo -e "${YELLOW}Cleaning up test installation...${NC}"
        rm -rf "$TEST_PREFIX"
    else
        echo -e "${YELLOW}Test installation remains at: $TEST_PREFIX${NC}"
        echo "Run with --cleanup to remove"
    fi
}

trap cleanup EXIT

echo "======================================"
echo "  Ananke macOS Installation Test"
echo "======================================"
echo

# Test 1: Check macOS version
log_test "Checking macOS version"
MACOS_VERSION=$(sw_vers -productVersion)
log_pass "Running macOS $MACOS_VERSION"

# Test 2: Check architecture
log_test "Checking architecture"
ARCH=$(uname -m)
log_pass "Architecture: $ARCH"

# Test 3: Install script with custom prefix
log_test "Installing to custom prefix"
if PREFIX="$TEST_PREFIX" bash scripts/install.sh &> /tmp/install-test.log; then
    log_pass "Installation succeeded"
else
    log_fail "Installation failed"
    cat /tmp/install-test.log
fi

# Test 4: Binary exists
log_test "Checking binary existence"
if [ -f "$TEST_PREFIX/bin/ananke" ]; then
    log_pass "Binary exists at $TEST_PREFIX/bin/ananke"
else
    log_fail "Binary not found"
fi

# Test 5: Binary is executable
log_test "Checking binary permissions"
if [ -x "$TEST_PREFIX/bin/ananke" ]; then
    log_pass "Binary is executable"
else
    log_fail "Binary is not executable"
fi

# Test 6: Check for code signing (macOS specific)
log_test "Checking code signing"
if codesign -v "$TEST_PREFIX/bin/ananke" 2>/dev/null; then
    log_pass "Binary is signed"
else
    echo -e "${YELLOW}[WARN]${NC} Binary is not signed (expected for local builds)"
fi

# Test 7: Check for Gatekeeper approval
log_test "Checking Gatekeeper"
if spctl -a -v "$TEST_PREFIX/bin/ananke" 2>/dev/null; then
    log_pass "Binary approved by Gatekeeper"
else
    echo -e "${YELLOW}[WARN]${NC} Binary not approved by Gatekeeper (expected for local builds)"
fi

# Test 8: Libraries installed
log_test "Checking library installation"
if [ -f "$TEST_PREFIX/lib/libananke.a" ]; then
    log_pass "Zig static library installed"
else
    log_fail "Zig static library not found"
fi

# Test 9: Version command
log_test "Testing version command"
if "$TEST_PREFIX/bin/ananke" --version &> /dev/null; then
    VERSION=$("$TEST_PREFIX/bin/ananke" --version)
    log_pass "Version command works: $VERSION"
else
    log_fail "Version command failed"
fi

# Test 10: Help command
log_test "Testing help command"
if "$TEST_PREFIX/bin/ananke" help &> /dev/null; then
    log_pass "Help command works"
else
    log_fail "Help command failed"
fi

# Test 11: Check library dependencies
log_test "Checking library dependencies"
if otool -L "$TEST_PREFIX/bin/ananke" &> /dev/null; then
    log_pass "Library dependencies valid"
else
    log_fail "Failed to check library dependencies"
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
