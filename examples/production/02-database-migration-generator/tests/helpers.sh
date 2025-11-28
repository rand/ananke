#!/bin/bash
# Test Helper Functions
#
# Utility functions for migration testing

# Extract SQL section from migration file
# Usage: extract_section <file> <section_name>
extract_section() {
    local file="$1"
    local section="$2"

    awk "/-- $section/,/COMMIT;/" "$file"
}

# Count occurrences of a pattern
# Usage: count_pattern <file> <pattern>
count_pattern() {
    local file="$1"
    local pattern="$2"

    grep -c "$pattern" "$file" 2>/dev/null || echo "0"
}

# Validate PostgreSQL syntax (if psql is available)
# Usage: validate_sql <file>
validate_sql() {
    local file="$1"

    if command -v psql &> /dev/null; then
        # Syntax check only, no execution
        psql --echo-errors --no-psqlrc -f "$file" --dry-run 2>&1
        return $?
    else
        echo "psql not available, skipping syntax validation"
        return 0
    fi
}

# Check if migration is reversible
# Usage: check_reversible <file>
check_reversible() {
    local file="$1"

    local has_up=$(grep -c "-- UP" "$file" 2>/dev/null || echo "0")
    local has_down=$(grep -c "-- DOWN" "$file" 2>/dev/null || echo "0")

    if [ "$has_up" -gt 0 ] && [ "$has_down" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Export functions
export -f extract_section
export -f count_pattern
export -f validate_sql
export -f check_reversible
