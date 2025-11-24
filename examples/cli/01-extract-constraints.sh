#!/usr/bin/env bash
# Example 1: Extract constraints from source code

set -e

echo "========================================="
echo "Ananke Example 1: Extract Constraints"
echo "========================================="
echo ""

# Example TypeScript file
EXAMPLE_FILE="test/fixtures/typescript/auth.ts"

if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "Error: Example file not found: $EXAMPLE_FILE"
    echo "Please run this script from the Ananke project root"
    exit 1
fi

echo "1. Extract constraints from TypeScript file (JSON format)"
echo "Command: ananke extract $EXAMPLE_FILE --format json"
echo ""
ananke extract "$EXAMPLE_FILE" --format json
echo ""

echo "2. Extract constraints with confidence filtering (pretty format)"
echo "Command: ananke extract $EXAMPLE_FILE --confidence 0.7 --format pretty"
echo ""
ananke extract "$EXAMPLE_FILE" --confidence 0.7 --format pretty
echo ""

echo "3. Save extracted constraints to file (YAML format)"
echo "Command: ananke extract $EXAMPLE_FILE --format yaml -o /tmp/constraints.yaml"
echo ""
ananke extract "$EXAMPLE_FILE" --format yaml -o /tmp/constraints.yaml
echo "Output saved to: /tmp/constraints.yaml"
echo ""

echo "4. Extract constraints in Ariadne DSL format"
echo "Command: ananke extract $EXAMPLE_FILE --format ariadne"
echo ""
ananke extract "$EXAMPLE_FILE" --format ariadne
echo ""

echo "========================================="
echo "Example complete!"
echo "========================================="
