#!/usr/bin/env bash
# Validate that all task definition files reference valid paths

set -e

echo "=== Validating Task Definitions ==="
echo ""

EVAL_DIR="eval"
DEFINITIONS_DIR="$EVAL_DIR/tasks/definitions"
ERRORS=0

for task_file in "$DEFINITIONS_DIR"/*.json; do
    task_name=$(basename "$task_file" .json)
    echo "Validating: $task_name"

    # Extract file paths from JSON (simplified parsing)
    ref_impl=$(grep -o '"reference_impl_path":[[:space:]]*"[^"]*"' "$task_file" | cut -d'"' -f4)
    test_suite=$(grep -o '"test_suite_path":[[:space:]]*"[^"]*"' "$task_file" | cut -d'"' -f4)
    constraints=$(grep -o '"constraint_path":[[:space:]]*"[^"]*"' "$task_file" | cut -d'"' -f4)

    # Check if files exist
    if [ ! -f "$ref_impl" ]; then
        echo "  ❌ Missing reference implementation: $ref_impl"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✓ Reference implementation: $ref_impl"
    fi

    if [ ! -f "$test_suite" ]; then
        echo "  ❌ Missing test suite: $test_suite"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✓ Test suite: $test_suite"
    fi

    if [ ! -f "$constraints" ]; then
        echo "  ❌ Missing constraints: $constraints"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✓ Constraints: $constraints"
    fi

    echo ""
done

echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All task definitions are valid!"
    exit 0
else
    echo "❌ Found $ERRORS missing files"
    exit 1
fi
