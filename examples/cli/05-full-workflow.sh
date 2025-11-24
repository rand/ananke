#!/usr/bin/env bash
# Example 5: Complete workflow - Extract, Compile, Validate

set -e

echo "========================================="
echo "Ananke Example 5: Full Workflow"
echo "========================================="
echo ""

EXAMPLE_FILE="test/fixtures/typescript/auth.ts"
CONSTRAINTS_JSON="/tmp/workflow-constraints.json"
COMPILED_IR="/tmp/workflow-compiled.cir"
VALIDATION_REPORT="/tmp/workflow-validation.txt"

if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "Error: Example file not found: $EXAMPLE_FILE"
    exit 1
fi

echo "=== Phase 1: Extract Constraints ==="
echo ""
echo "Extracting constraints from: $EXAMPLE_FILE"
echo "Command: ananke extract $EXAMPLE_FILE --confidence 0.6 --format json -o $CONSTRAINTS_JSON"
echo ""
ananke extract "$EXAMPLE_FILE" --confidence 0.6 --format json -o "$CONSTRAINTS_JSON"
echo ""
echo "Extracted constraints:"
echo ""
ananke extract "$EXAMPLE_FILE" --confidence 0.6 --format pretty
echo ""

echo "=== Phase 2: Compile to IR ==="
echo ""
echo "Compiling constraints to intermediate representation"
echo "Command: ananke compile $CONSTRAINTS_JSON --priority high -o $COMPILED_IR"
echo ""
ananke compile "$CONSTRAINTS_JSON" --priority high -o "$COMPILED_IR"
echo ""
echo "Compiled IR preview:"
head -n 20 "$COMPILED_IR"
echo ""

echo "=== Phase 3: Validate Code ==="
echo ""
echo "Validating code against extracted constraints"
echo "Command: ananke validate $EXAMPLE_FILE -c $CONSTRAINTS_JSON --report $VALIDATION_REPORT"
echo ""
ananke validate "$EXAMPLE_FILE" -c "$CONSTRAINTS_JSON" --report "$VALIDATION_REPORT" --verbose || true
echo ""

if [ -f "$VALIDATION_REPORT" ]; then
    echo "Validation report:"
    cat "$VALIDATION_REPORT"
    echo ""
fi

echo "=== Workflow Summary ==="
echo ""
echo "Files created:"
echo "  - Constraints:  $CONSTRAINTS_JSON"
echo "  - Compiled IR:  $COMPILED_IR"
echo "  - Validation:   $VALIDATION_REPORT"
echo ""

echo "========================================="
echo "Full workflow complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Review extracted constraints"
echo "  2. Deploy Maze inference service to Modal"
echo "  3. Use 'ananke generate' with compiled constraints"
echo ""
