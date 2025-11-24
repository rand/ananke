#!/usr/bin/env bash
# Example 2: Compile constraints to IR

set -e

echo "========================================="
echo "Ananke Example 2: Compile Constraints"
echo "========================================="
echo ""

# First extract constraints to a file
EXAMPLE_FILE="test/fixtures/typescript/auth.ts"
CONSTRAINTS_FILE="/tmp/constraints.json"

echo "Step 1: Extract constraints to JSON"
echo "Command: ananke extract $EXAMPLE_FILE --format json -o $CONSTRAINTS_FILE"
echo ""
ananke extract "$EXAMPLE_FILE" --format json -o "$CONSTRAINTS_FILE"
echo ""

echo "Step 2: Compile constraints to IR"
echo "Command: ananke compile $CONSTRAINTS_FILE --format json"
echo ""
ananke compile "$CONSTRAINTS_FILE" --format json
echo ""

echo "Step 3: Save compiled IR to file"
IR_FILE="/tmp/compiled.cir"
echo "Command: ananke compile $CONSTRAINTS_FILE -o $IR_FILE"
echo ""
ananke compile "$CONSTRAINTS_FILE" -o "$IR_FILE"
echo "Compiled IR saved to: $IR_FILE"
echo ""

echo "Step 4: Compile with high priority"
echo "Command: ananke compile $CONSTRAINTS_FILE --priority high"
echo ""
ananke compile "$CONSTRAINTS_FILE" --priority high
echo ""

echo "========================================="
echo "Example complete!"
echo "========================================="
