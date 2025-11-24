#!/usr/bin/env bash
# Ananke Health Check Script
# Verifies Ananke installation and system health
# Usage: ./scripts/health-check.sh [--verbose] [--modal-endpoint URL]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=0
MODAL_ENDPOINT="${MODAL_ENDPOINT:-}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --modal-endpoint)
                MODAL_ENDPOINT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Ananke Health Check Script"
                echo
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --verbose, -v           Show detailed output"
                echo "  --modal-endpoint URL    Check Modal endpoint connectivity"
                echo "  --help, -h              Show this help message"
                echo
                echo "Environment variables:"
                echo "  MODAL_ENDPOINT         Modal inference endpoint URL"
                echo "  ANTHROPIC_API_KEY      Claude API key for semantic analysis"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done
}

# Logging functions
log_info() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_section() {
    echo
    echo -e "${BLUE}═══ $1 ═══${NC}"
}

# Test: Check if binary exists
test_binary_exists() {
    log_info "Checking if ananke binary exists..."

    if command -v ananke &> /dev/null; then
        ANANKE_PATH=$(command -v ananke)
        log_success "Binary found at: $ANANKE_PATH"
        return 0
    else
        log_failure "Binary not found in PATH"
        return 1
    fi
}

# Test: Binary is executable
test_binary_executable() {
    log_info "Checking if binary is executable..."

    if command -v ananke &> /dev/null; then
        ANANKE_PATH=$(command -v ananke)
        if [ -x "$ANANKE_PATH" ]; then
            log_success "Binary is executable"
            return 0
        else
            log_failure "Binary exists but is not executable"
            return 1
        fi
    else
        log_failure "Binary not found"
        return 1
    fi
}

# Test: Version command
test_version_command() {
    log_info "Testing version command..."

    if command -v ananke &> /dev/null; then
        VERSION_OUTPUT=$(ananke --version 2>&1 || echo "")
        if [ -n "$VERSION_OUTPUT" ]; then
            log_success "Version: $VERSION_OUTPUT"
            return 0
        else
            log_failure "Version command failed"
            return 1
        fi
    else
        log_failure "Binary not found"
        return 1
    fi
}

# Test: Help command
test_help_command() {
    log_info "Testing help command..."

    if command -v ananke &> /dev/null; then
        HELP_OUTPUT=$(ananke help 2>&1 || echo "")
        if [ -n "$HELP_OUTPUT" ]; then
            log_success "Help command works"
            [ $VERBOSE -eq 1 ] && echo "$HELP_OUTPUT" | head -n 5
            return 0
        else
            log_failure "Help command failed"
            return 1
        fi
    else
        log_failure "Binary not found"
        return 1
    fi
}

# Test: Extract command with sample file
test_extract_command() {
    log_info "Testing extract command with sample..."

    if ! command -v ananke &> /dev/null; then
        log_failure "Binary not found"
        return 1
    fi

    # Create temporary test file
    TEMP_FILE=$(mktemp --suffix=.ts)
    cat > "$TEMP_FILE" <<'EOF'
// Sample TypeScript code for testing
interface User {
    id: number;
    name: string;
    email: string;
}

function validateUser(user: User): boolean {
    return user.id > 0 && user.name.length > 0;
}
EOF

    # Try to extract constraints
    if OUTPUT=$(ananke extract "$TEMP_FILE" 2>&1); then
        log_success "Extract command works"
        [ $VERBOSE -eq 1 ] && echo "$OUTPUT" | head -n 10
        rm -f "$TEMP_FILE"
        return 0
    else
        log_warning "Extract command failed (may need additional setup)"
        [ $VERBOSE -eq 1 ] && echo "$OUTPUT"
        rm -f "$TEMP_FILE"
        return 1
    fi
}

# Test: Compile command
test_compile_command() {
    log_info "Testing compile command..."

    if ! command -v ananke &> /dev/null; then
        log_failure "Binary not found"
        return 1
    fi

    # Create temporary constraints file
    TEMP_CONSTRAINTS=$(mktemp --suffix=.json)
    cat > "$TEMP_CONSTRAINTS" <<'EOF'
{
    "constraints": [
        {
            "type": "type_safety",
            "rule": "no_any_type",
            "severity": "error"
        }
    ]
}
EOF

    # Try to compile constraints
    if OUTPUT=$(ananke compile "$TEMP_CONSTRAINTS" 2>&1); then
        log_success "Compile command works"
        rm -f "$TEMP_CONSTRAINTS"
        return 0
    else
        log_warning "Compile command failed (may need additional setup)"
        [ $VERBOSE -eq 1 ] && echo "$OUTPUT"
        rm -f "$TEMP_CONSTRAINTS"
        return 1
    fi
}

# Test: Check system dependencies
test_system_dependencies() {
    log_info "Checking system dependencies..."

    local deps_ok=1

    # Check for required libraries (if applicable)
    if [ "$(uname -s)" = "Linux" ]; then
        if command -v ldd &> /dev/null; then
            ANANKE_PATH=$(command -v ananke 2>/dev/null)
            if [ -n "$ANANKE_PATH" ]; then
                if ldd "$ANANKE_PATH" &> /dev/null; then
                    log_success "All system libraries found"
                else
                    log_warning "Some system libraries may be missing"
                    [ $VERBOSE -eq 1 ] && ldd "$ANANKE_PATH"
                    deps_ok=0
                fi
            fi
        fi
    fi

    if [ $deps_ok -eq 1 ]; then
        ((PASSED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Test: Claude API connectivity
test_claude_connectivity() {
    log_info "Testing Claude API connectivity..."

    if [ -z "$ANTHROPIC_API_KEY" ]; then
        log_warning "ANTHROPIC_API_KEY not set, skipping Claude connectivity test"
        return 0
    fi

    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            "https://api.anthropic.com/v1/models" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ]; then
            log_success "Claude API accessible"
            return 0
        elif [ "$HTTP_CODE" = "401" ]; then
            log_failure "Claude API key is invalid"
            return 1
        else
            log_warning "Claude API returned HTTP $HTTP_CODE"
            return 0
        fi
    else
        log_warning "curl not found, skipping Claude connectivity test"
        return 0
    fi
}

# Test: Modal endpoint connectivity
test_modal_connectivity() {
    log_info "Testing Modal endpoint connectivity..."

    if [ -z "$MODAL_ENDPOINT" ]; then
        log_warning "MODAL_ENDPOINT not set, skipping Modal connectivity test"
        return 0
    fi

    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            "${MODAL_ENDPOINT}/health" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ]; then
            log_success "Modal endpoint accessible"
            return 0
        else
            log_warning "Modal endpoint returned HTTP $HTTP_CODE"
            return 0
        fi
    else
        log_warning "curl not found, skipping Modal connectivity test"
        return 0
    fi
}

# Test: File permissions
test_file_permissions() {
    log_info "Checking file permissions..."

    ANANKE_PATH=$(command -v ananke 2>/dev/null || echo "")

    if [ -z "$ANANKE_PATH" ]; then
        log_failure "Binary not found"
        return 1
    fi

    # Check if we can read the binary
    if [ -r "$ANANKE_PATH" ]; then
        log_success "Binary is readable"
        return 0
    else
        log_failure "Binary is not readable"
        return 1
    fi
}

# Print summary
print_summary() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Health Check Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
        echo

        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}Note: Some optional features may need configuration${NC}"
            echo
        fi

        echo "Ananke is ready to use!"
        return 0
    else
        echo -e "${RED}✗ Some critical tests failed${NC}"
        echo
        echo "Troubleshooting:"
        echo "  1. Ensure Ananke is properly installed"
        echo "  2. Check that the binary is in your PATH"
        echo "  3. Verify system dependencies are installed"
        echo "  4. Run with --verbose flag for more details"
        echo
        echo "For help, visit: https://github.com/ananke-ai/ananke/issues"
        return 1
    fi
}

# Main health check flow
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Ananke Health Check${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

    parse_args "$@"

    # Core functionality tests
    log_section "Core Functionality"
    test_binary_exists
    test_binary_executable
    test_version_command
    test_help_command

    # Command tests
    log_section "Command Tests"
    test_extract_command
    test_compile_command

    # System tests
    log_section "System Health"
    test_file_permissions
    test_system_dependencies

    # Optional service tests
    log_section "Optional Services"
    test_claude_connectivity
    test_modal_connectivity

    # Print summary and exit
    print_summary
}

# Run main function
main "$@"
