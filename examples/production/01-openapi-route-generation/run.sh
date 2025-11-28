#!/bin/bash
set -e

echo "=== Example 1: OpenAPI Route Generation ==="
echo ""

# Check prerequisites
if ! command -v ananke &> /dev/null; then
    echo "Error: ananke CLI not found. Please install Ananke first."
    echo "See main README for installation instructions."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3.8+."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Ensure output directories exist
mkdir -p constraints
mkdir -p output

# Phase 1: Extract constraints from existing code
echo "1/4 Extracting constraints from existing code..."
ananke extract input/existing_routes.ts \
  --language typescript \
  --format json \
  -o constraints/extracted.json

if [ ! -f constraints/extracted.json ]; then
    echo "Error: Failed to extract constraints"
    exit 1
fi

EXTRACTED_COUNT=$(cat constraints/extracted.json | grep -o '"type"' | wc -l)
echo "✓ Extracted $EXTRACTED_COUNT constraints from existing_routes.ts"
echo ""

# Phase 2: Merge with OpenAPI spec constraints
echo "2/4 Parsing OpenAPI spec and merging constraints..."
python3 scripts/openapi_to_constraints.py \
  input/openapi.yaml \
  constraints/extracted.json \
  -o constraints/merged.json

if [ ! -f constraints/merged.json ]; then
    echo "Error: Failed to merge constraints"
    exit 1
fi

OPENAPI_ENDPOINTS=$(cat input/openapi.yaml | grep -c '^\s*[a-z]\+:' || echo "0")
MERGED_COUNT=$(cat constraints/merged.json | grep -o '"type"' | wc -l)
echo "✓ Parsed OpenAPI spec with multiple endpoints"
echo "✓ Merged constraints: $MERGED_COUNT total"
echo ""

# Phase 3: Generate new code
echo "3/4 Generating route handler..."

# Create generation prompt
PROMPT="Generate complete Express.js route handlers for the User Management API based on the OpenAPI specification.

Requirements:
- Create a Router instance and export it as default
- Implement all endpoints defined in the OpenAPI spec: GET /users/:id, PUT /users/:id, DELETE /users/:id, GET /users, POST /users
- Use Zod for request validation (path params, query params, request body)
- Follow the error handling patterns from existing code (try/catch with specific error types)
- Return proper HTTP status codes as defined in OpenAPI spec
- Use async/await for all route handlers
- Include JSDoc comments for each route
- Format responses consistently: success responses return data directly, errors return {error, message, details} objects
- Include a mock database object similar to the existing routes
- Validate all inputs before processing
- Handle edge cases: invalid IDs, missing resources, duplicate emails, validation errors

Use TypeScript with proper type annotations and follow the coding patterns from the extracted constraints."

ananke generate "$PROMPT" \
  --constraints constraints/merged.json \
  --max-tokens 3000 \
  -o output/generated_routes.ts

if [ ! -f output/generated_routes.ts ]; then
    echo "Error: Failed to generate routes"
    exit 1
fi

LINES_GENERATED=$(wc -l < output/generated_routes.ts | tr -d ' ')
echo "✓ Generated $LINES_GENERATED lines of code"
echo ""

# Phase 4: Validate output
echo "4/4 Validating generated code..."

# Check if package.json exists and dependencies are installed
if [ ! -d node_modules ]; then
    echo "Installing dependencies..."
    npm install --silent
fi

# Run tests
npm test 2>&1 | grep -E '(✓|✗|PASS|FAIL|Test Files|Tests)' || true

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✓ Complete! See output/generated_routes.ts"
    echo ""
    echo "Next steps:"
    echo "  - Review the generated code in output/generated_routes.ts"
    echo "  - Integrate into your Express app with: import userRoutes from './generated_routes'"
    echo "  - Customize by modifying input/existing_routes.ts and re-running"
else
    echo ""
    echo "⚠ Warning: Some tests failed. Review output/generated_routes.ts"
    echo "This is expected on first run - the generated code may need refinement."
    exit 1
fi
