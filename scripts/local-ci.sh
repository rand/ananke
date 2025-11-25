#!/usr/bin/env bash
# Local CI/CD validation script for Ananke
# Runs all tests and checks locally to validate changes before committing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
FAILED=0

print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    FAILED=1
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v zig &> /dev/null; then
        print_error "Zig not found. Please install Zig 0.15.2+"
        return 1
    fi
    print_success "Zig $(zig version) found"

    if ! command -v cargo &> /dev/null; then
        print_error "Cargo not found. Please install Rust"
        return 1
    fi
    print_success "Cargo $(cargo --version | cut -d' ' -f2) found"

    echo
}

# Zig tests
run_zig_tests() {
    print_header "Running Zig Tests"

    print_info "Building Zig project..."
    if zig build -Doptimize=Debug 2>&1 | tail -10; then
        print_success "Zig build successful"
    else
        print_error "Zig build failed"
        return 1
    fi

    print_info "Running Zig tests..."
    if ./scripts/test-runner.sh; then
        print_success "All Zig tests passed"
    else
        print_error "Zig tests failed"
        return 1
    fi

    echo
}

# Rust tests
run_rust_tests() {
    print_header "Running Rust Tests (Maze)"

    cd maze

    print_info "Checking Rust formatting..."
    if cargo fmt --all -- --check 2>&1; then
        print_success "Rust formatting check passed"
    else
        print_warning "Rust formatting issues found (run 'cargo fmt')"
    fi

    print_info "Running Clippy..."
    if cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tail -20; then
        print_success "Clippy checks passed"
    else
        print_warning "Clippy warnings found"
    fi

    print_info "Building Rust project..."
    if cargo build --verbose 2>&1 | tail -10; then
        print_success "Rust build successful"
    else
        print_error "Rust build failed"
        cd ..
        return 1
    fi

    print_info "Running Rust tests..."
    if cargo test --all --verbose 2>&1 | tail -30; then
        print_success "All Rust tests passed"
    else
        print_error "Rust tests failed"
        cd ..
        return 1
    fi

    cd ..
    echo
}

# Performance benchmarks (optional)
run_benchmarks() {
    print_header "Running Performance Benchmarks (Optional)"

    print_info "Zig benchmarks..."
    if zig build bench 2>&1 | tail -20; then
        print_success "Zig benchmarks completed"
    else
        print_warning "Zig benchmarks skipped or failed"
    fi

    print_info "Rust benchmarks..."
    cd maze
    if cargo bench --no-run 2>&1 | tail -10; then
        print_success "Rust benchmark build completed"
    else
        print_warning "Rust benchmarks skipped or failed"
    fi
    cd ..

    echo
}

# Security checks
run_security_checks() {
    print_header "Running Security Checks (Optional)"

    print_info "Checking for common security issues..."

    # Check for hardcoded secrets (basic check)
    if grep -r -i "api_key\s*=\s*\"" --include="*.zig" --include="*.rs" src/ maze/src/ 2>/dev/null; then
        print_warning "Potential hardcoded API keys found"
    else
        print_success "No obvious hardcoded secrets found"
    fi

    # Rust security audit
    print_info "Running Rust cargo audit (if installed)..."
    cd maze
    if command -v cargo-audit &> /dev/null; then
        if cargo audit 2>&1 | tail -20; then
            print_success "Cargo audit passed"
        else
            print_warning "Cargo audit found issues"
        fi
    else
        print_warning "cargo-audit not installed (run 'cargo install cargo-audit')"
    fi
    cd ..

    echo
}

# Summary
print_summary() {
    print_header "CI Summary"

    if [ $FAILED -eq 0 ]; then
        print_success "All checks passed! ✓"
        echo
        print_info "Safe to commit and push your changes."
        echo
        print_info "Next steps:"
        echo "  git add ."
        echo "  git commit -m \"your message\""
        echo "  git push"
        return 0
    else
        print_error "Some checks failed ✗"
        echo
        print_info "Please fix the failures before committing."
        return 1
    fi
}

# Main execution
main() {
    print_header "Ananke Local CI/CD Validation"
    echo "Running all tests and checks..."
    echo

    check_prerequisites || exit 1
    run_zig_tests || true
    run_rust_tests || true

    # Optional checks (don't fail CI)
    if [ "${SKIP_OPTIONAL:-0}" != "1" ]; then
        run_benchmarks || true
        run_security_checks || true
    fi

    print_summary
    exit $FAILED
}

# Run main
main
