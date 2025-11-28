#!/bin/bash
# Migration Validation Test Suite
#
# Tests the generated migration for:
# - SQL syntax validity
# - UP migration correctness
# - DOWN migration rollback
# - Idempotency
# - Transaction safety

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MIGRATION_FILE="$PROJECT_DIR/output/migration_003_add_user_fields.sql"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $1 ... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
    if [ -n "${1:-}" ]; then
        echo "  Error: $1"
    fi
}

# Test 1: Migration file exists
test_migration_exists() {
    test_start "Migration file exists"

    if [ -f "$MIGRATION_FILE" ]; then
        test_pass
    else
        test_fail "File not found: $MIGRATION_FILE"
        exit 1
    fi
}

# Test 2: File is not empty
test_migration_not_empty() {
    test_start "Migration file is not empty"

    if [ -s "$MIGRATION_FILE" ]; then
        test_pass
    else
        test_fail "File is empty"
        exit 1
    fi
}

# Test 3: Contains required header
test_migration_header() {
    test_start "Contains migration header"

    if grep -q "Migration:" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing migration header"
    fi
}

# Test 4: Contains timestamp
test_migration_timestamp() {
    test_start "Contains timestamp"

    if grep -q "Created:" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing timestamp"
    fi
}

# Test 5: Contains BEGIN transaction
test_transaction_begin() {
    test_start "Contains BEGIN transaction"

    if grep -q "BEGIN;" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing BEGIN statement"
    fi
}

# Test 6: Contains COMMIT transaction
test_transaction_commit() {
    test_start "Contains COMMIT transaction"

    if grep -q "COMMIT;" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing COMMIT statement"
    fi
}

# Test 7: Contains UP section
test_up_section() {
    test_start "Contains UP migration section"

    if grep -qi "UP" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing UP section"
    fi
}

# Test 8: Contains DOWN section
test_down_section() {
    test_start "Contains DOWN migration section"

    if grep -qi "DOWN" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing DOWN section"
    fi
}

# Test 9: Contains ALTER TABLE for adding columns
test_alter_table_add() {
    test_start "Contains ALTER TABLE for adding columns"

    if grep -q "ALTER TABLE" "$MIGRATION_FILE" && grep -q "ADD COLUMN" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing ALTER TABLE ADD COLUMN"
    fi
}

# Test 10: Contains column 'name'
test_column_name() {
    test_start "Adds 'name' column"

    if grep -i "name" "$MIGRATION_FILE" | grep -qi "VARCHAR"; then
        test_pass
    else
        test_fail "Missing 'name' column definition"
    fi
}

# Test 11: Contains column 'updated_at'
test_column_updated_at() {
    test_start "Adds 'updated_at' column"

    if grep -i "updated_at" "$MIGRATION_FILE" | grep -qi "TIMESTAMP"; then
        test_pass
    else
        test_fail "Missing 'updated_at' column definition"
    fi
}

# Test 12: Contains index creation
test_index_creation() {
    test_start "Creates index on email"

    if grep -qi "CREATE.*INDEX" "$MIGRATION_FILE" && grep -qi "email" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing index creation"
    fi
}

# Test 13: Uses IF NOT EXISTS for index
test_index_idempotent() {
    test_start "Index creation uses IF NOT EXISTS"

    if grep -i "CREATE.*INDEX" "$MIGRATION_FILE" | grep -qi "IF NOT EXISTS"; then
        test_pass
    else
        test_fail "Index creation not idempotent"
    fi
}

# Test 14: DOWN migration drops columns
test_down_drop_columns() {
    test_start "DOWN migration drops added columns"

    if grep -i "DROP COLUMN" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "DOWN migration doesn't drop columns"
    fi
}

# Test 15: DOWN migration drops index
test_down_drop_index() {
    test_start "DOWN migration drops created index"

    if grep -i "DROP INDEX" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "DOWN migration doesn't drop index"
    fi
}

# Test 16: Uses IF EXISTS for DROP operations
test_drop_if_exists() {
    test_start "DROP operations use IF EXISTS"

    if grep -i "DROP" "$MIGRATION_FILE" | grep -qi "IF EXISTS"; then
        test_pass
    else
        test_fail "DROP operations not idempotent"
    fi
}

# Test 17: Safe defaults for NOT NULL columns
test_safe_defaults() {
    test_start "NOT NULL columns have defaults"

    # If name column is NOT NULL, it should have a DEFAULT
    if grep -i "name.*NOT NULL" "$MIGRATION_FILE"; then
        if grep -i "name" "$MIGRATION_FILE" | grep -qi "DEFAULT"; then
            test_pass
        else
            test_fail "NOT NULL column 'name' missing DEFAULT"
        fi
    else
        # Column is nullable, which is also safe
        test_pass
    fi
}

# Test 18: No syntax errors (basic check)
test_basic_syntax() {
    test_start "Basic SQL syntax check"

    # Check for common syntax errors
    errors=0

    # Unclosed parentheses
    open_parens=$(grep -o "(" "$MIGRATION_FILE" | wc -l)
    close_parens=$(grep -o ")" "$MIGRATION_FILE" | wc -l)
    if [ "$open_parens" -ne "$close_parens" ]; then
        errors=$((errors + 1))
    fi

    # Unclosed quotes (simple check)
    single_quotes=$(grep -o "'" "$MIGRATION_FILE" | wc -l)
    if [ $((single_quotes % 2)) -ne 0 ]; then
        errors=$((errors + 1))
    fi

    if [ $errors -eq 0 ]; then
        test_pass
    else
        test_fail "Found $errors potential syntax errors"
    fi
}

# Test 19: UP and DOWN are in correct order
test_up_down_order() {
    test_start "UP section comes before DOWN section"

    up_line=$(grep -n -i -e "-- UP" "$MIGRATION_FILE" | head -1 | cut -d: -f1)
    down_line=$(grep -n -i -e "-- DOWN" "$MIGRATION_FILE" | head -1 | cut -d: -f1)

    if [ -n "$up_line" ] && [ -n "$down_line" ] && [ "$up_line" -lt "$down_line" ]; then
        test_pass
    else
        test_fail "UP and DOWN sections in wrong order"
    fi
}

# Test 20: Migration has description
test_has_description() {
    test_start "Migration has description"

    if grep -qi "Description:" "$MIGRATION_FILE"; then
        test_pass
    else
        test_fail "Missing description"
    fi
}

# Run all tests
run_tests() {
    echo ""
    echo "Running Migration Validation Tests"
    echo "=================================="
    echo ""

    test_migration_exists
    test_migration_not_empty
    test_migration_header
    test_migration_timestamp
    test_transaction_begin
    test_transaction_commit
    test_up_section
    test_down_section
    test_alter_table_add
    test_column_name
    test_column_updated_at
    test_index_creation
    test_index_idempotent
    test_down_drop_columns
    test_down_drop_index
    test_drop_if_exists
    test_safe_defaults
    test_basic_syntax
    test_up_down_order
    test_has_description

    echo ""
    echo "=================================="
    echo "Test Results"
    echo "=================================="
    echo "Total tests run:    $TESTS_RUN"
    echo -e "Tests passed:       ${GREEN}$TESTS_PASSED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "Tests failed:       ${RED}$TESTS_FAILED${NC}"
        echo ""
        exit 1
    else
        echo -e "Tests failed:       ${GREEN}0${NC}"
        echo ""
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Main
run_tests
