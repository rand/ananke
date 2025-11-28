#!/bin/bash
# Database Migration Generator - 4-Phase Execution Script
#
# This script orchestrates the complete migration generation pipeline:
# 1. Extract migration patterns from existing migrations
# 2. Compute schema diff between versions
# 3. Generate migration using Ananke
# 4. Validate generated SQL
#
# Usage: ./run.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/input"
CONSTRAINTS_DIR="$SCRIPT_DIR/constraints"
OUTPUT_DIR="$SCRIPT_DIR/output"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Files
SCHEMA_V1="$INPUT_DIR/schema_v1.sql"
SCHEMA_V2="$INPUT_DIR/schema_v2.sql"
EXISTING_MIGRATIONS="$INPUT_DIR/existing_migrations"
SCHEMA_DIFF="$CONSTRAINTS_DIR/schema_changes.json"
MIGRATION_PATTERNS="$CONSTRAINTS_DIR/migration_patterns.json"
OUTPUT_MIGRATION="$OUTPUT_DIR/migration_003_add_user_fields.sql"

# Helper functions
log_phase() {
    echo -e "\n${BLUE}=== PHASE $1: $2 ===${NC}\n"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Cleanup previous run
cleanup() {
    log_info "Cleaning up previous run..."
    rm -f "$SCHEMA_DIFF"
    rm -f "$MIGRATION_PATTERNS"
    rm -f "$OUTPUT_MIGRATION"
    mkdir -p "$CONSTRAINTS_DIR"
    mkdir -p "$OUTPUT_DIR"
}

# Phase 1: Extract patterns from existing migrations
extract_patterns() {
    log_phase 1 "Extract Migration Patterns"

    if ! command -v ananke &> /dev/null; then
        log_error "Ananke CLI not found. Please install Ananke first."
        log_info "See: https://github.com/ananke/ananke#installation"
        exit 1
    fi

    log_info "Analyzing existing migrations..."
    log_info "Input: $EXISTING_MIGRATIONS/*.sql"

    # Extract patterns from existing migrations
    ananke extract \
        "$EXISTING_MIGRATIONS"/*.sql \
        --output "$MIGRATION_PATTERNS" \
        --focus "transaction structure, UP/DOWN sections, header format, timestamp format, comment style" \
        2>&1 || {
            log_error "Pattern extraction failed"
            exit 1
        }

    if [ -f "$MIGRATION_PATTERNS" ]; then
        log_success "Migration patterns extracted"
        log_info "Output: $MIGRATION_PATTERNS"
    else
        log_error "Pattern extraction failed - no output file generated"
        exit 1
    fi
}

# Phase 2: Compute schema diff
compute_diff() {
    log_phase 2 "Compute Schema Diff"

    log_info "Comparing schema versions..."
    log_info "Old: $SCHEMA_V1"
    log_info "New: $SCHEMA_V2"

    # Run schema diff script
    python3 "$SCRIPTS_DIR/schema_diff.py" \
        "$SCHEMA_V1" \
        "$SCHEMA_V2" \
        "$SCHEMA_DIFF" || {
            log_error "Schema diff computation failed"
            exit 1
        }

    if [ -f "$SCHEMA_DIFF" ]; then
        log_success "Schema diff computed"
        log_info "Output: $SCHEMA_DIFF"

        # Show summary
        echo ""
        python3 -c "import json; d = json.load(open('$SCHEMA_DIFF')); print('Changes detected:'); print(f\"  - Columns added: {len(d['migration']['changes']['columns_added'])}\"); print(f\"  - Indexes added: {len(d['migration']['changes']['indexes_added'])}\")"
    else
        log_error "Schema diff computation failed - no output file"
        exit 1
    fi
}

# Phase 3: Generate migration with Ananke
generate_migration() {
    log_phase 3 "Generate Migration"

    log_info "Generating migration SQL..."
    log_info "Using patterns: $MIGRATION_PATTERNS"
    log_info "Using changes: $SCHEMA_DIFF"

    # Prepare prompt for Ananke
    PROMPT="Generate a PostgreSQL migration script with the following requirements:

1. Follow the patterns extracted from existing migrations
2. Implement the schema changes specified in the diff
3. Include both UP and DOWN migrations
4. Wrap each section in BEGIN/COMMIT transactions
5. Use IF EXISTS/IF NOT EXISTS for idempotency
6. Add migration header with timestamp and description
7. Provide safe defaults for NOT NULL columns

The migration should be production-ready and safe to rollback."

    # Generate migration using Ananke
    ananke generate \
        --prompt "$PROMPT" \
        --constraints "$MIGRATION_PATTERNS" \
        --constraints "$SCHEMA_DIFF" \
        --output "$OUTPUT_MIGRATION" \
        2>&1 || {
            log_error "Migration generation failed"
            exit 1
        }

    if [ -f "$OUTPUT_MIGRATION" ]; then
        log_success "Migration generated"
        log_info "Output: $OUTPUT_MIGRATION"

        # Show first few lines
        echo ""
        log_info "Preview (first 20 lines):"
        head -20 "$OUTPUT_MIGRATION" | sed 's/^/  /'
    else
        log_error "Migration generation failed - no output file"
        exit 1
    fi
}

# Phase 4: Validate generated migration
validate_migration() {
    log_phase 4 "Validate Migration"

    log_info "Running validation tests..."

    # Check file exists and is not empty
    if [ ! -s "$OUTPUT_MIGRATION" ]; then
        log_error "Migration file is empty"
        exit 1
    fi

    # Basic SQL syntax check
    log_info "Checking SQL syntax..."

    # Check for required sections
    if ! grep -q "BEGIN;" "$OUTPUT_MIGRATION"; then
        log_error "Missing transaction BEGIN statement"
        exit 1
    fi

    if ! grep -q "COMMIT;" "$OUTPUT_MIGRATION"; then
        log_error "Missing transaction COMMIT statement"
        exit 1
    fi

    if ! grep -q -i "ALTER TABLE" "$OUTPUT_MIGRATION"; then
        log_error "Missing ALTER TABLE statements"
        exit 1
    fi

    log_success "SQL syntax checks passed"

    # Check for UP/DOWN sections
    log_info "Checking migration structure..."

    if ! grep -q -i "UP" "$OUTPUT_MIGRATION"; then
        log_error "Missing UP migration section"
        exit 1
    fi

    if ! grep -q -i "DOWN" "$OUTPUT_MIGRATION"; then
        log_error "Missing DOWN migration section"
        exit 1
    fi

    log_success "Migration structure validated"

    # Check for idempotency safeguards
    log_info "Checking idempotency safeguards..."

    if grep -q "IF EXISTS" "$OUTPUT_MIGRATION" || grep -q "IF NOT EXISTS" "$OUTPUT_MIGRATION"; then
        log_success "Idempotency safeguards present"
    else
        log_error "Warning: No IF EXISTS/IF NOT EXISTS clauses found"
    fi

    # Run test suite if available
    if [ -f "$SCRIPT_DIR/tests/test_migration.sh" ]; then
        log_info "Running comprehensive test suite..."
        bash "$SCRIPT_DIR/tests/test_migration.sh" || {
            log_error "Test suite failed"
            exit 1
        }
        log_success "All tests passed"
    fi

    log_success "Validation complete"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     Database Migration Generator with Ananke          ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    cleanup
    extract_patterns
    compute_diff
    generate_migration
    validate_migration

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Migration Generated Successfully         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Generated migration: $OUTPUT_MIGRATION"
    echo ""
    log_info "Next steps:"
    echo "  1. Review the generated migration"
    echo "  2. Test on a development database"
    echo "  3. Apply with: psql -f $OUTPUT_MIGRATION"
    echo "  4. To rollback, run the DOWN section"
    echo ""
}

# Run main function
main "$@"
