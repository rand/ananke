#!/usr/bin/env bash
# Example 3: Validate code against constraints

set -e

echo "========================================="
echo "Ananke Example 3: Validate Code"
echo "========================================="
echo ""

EXAMPLE_FILE="test/fixtures/typescript/auth.ts"
CONSTRAINTS_FILE="/tmp/constraints.json"

# Extract constraints first
echo "Step 1: Extract constraints"
ananke extract "$EXAMPLE_FILE" --format json -o "$CONSTRAINTS_FILE" > /dev/null
echo "Constraints extracted to: $CONSTRAINTS_FILE"
echo ""

echo "Step 2: Validate code against constraints"
echo "Command: ananke validate $EXAMPLE_FILE -c $CONSTRAINTS_FILE"
echo ""
ananke validate "$EXAMPLE_FILE" -c "$CONSTRAINTS_FILE" || true
echo ""

echo "Step 3: Validate with detailed output"
echo "Command: ananke validate $EXAMPLE_FILE -c $CONSTRAINTS_FILE --verbose"
echo ""
ananke validate "$EXAMPLE_FILE" -c "$CONSTRAINTS_FILE" --verbose || true
echo ""

echo "Step 4: Validate in strict mode (warnings as errors)"
echo "Command: ananke validate $EXAMPLE_FILE -c $CONSTRAINTS_FILE --strict"
echo ""
ananke validate "$EXAMPLE_FILE" -c "$CONSTRAINTS_FILE" --strict || true
echo ""

echo "Step 5: Generate validation report"
REPORT_FILE="/tmp/validation-report.txt"
echo "Command: ananke validate $EXAMPLE_FILE -c $CONSTRAINTS_FILE --report $REPORT_FILE"
echo ""
ananke validate "$EXAMPLE_FILE" -c "$CONSTRAINTS_FILE" --report "$REPORT_FILE" || true
echo "Report saved to: $REPORT_FILE"
echo ""

echo "========================================="
echo "Example complete!"
echo "========================================="
