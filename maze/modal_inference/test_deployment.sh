#!/bin/bash
# Test script for deployed Ananke Modal Inference Service

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service URL
SERVICE_URL="https://rand--ananke-inference-generate-api.modal.run"
HEALTH_URL="https://rand--ananke-inference-health.modal.run"

echo "=========================================="
echo "Ananke Modal Inference Service Test"
echo "=========================================="
echo ""

# Test 1: Health check
echo -e "${GREEN}Test 1: Health Check${NC}"
echo "URL: $HEALTH_URL"
HEALTH_RESPONSE=$(curl -s "$HEALTH_URL")
echo "Response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi
echo ""

# Test 2: Simple generation
echo -e "${GREEN}Test 2: Simple Generation${NC}"
echo "Generating Python function..."
SIMPLE_REQUEST='{
  "prompt": "Write a Python function to add two numbers:",
  "max_tokens": 100,
  "temperature": 0.7
}'

SIMPLE_RESPONSE=$(curl -s -X POST "$SERVICE_URL" \
  -H "Content-Type: application/json" \
  -d "$SIMPLE_REQUEST")

echo "Response:"
echo "$SIMPLE_RESPONSE" | jq . 2>/dev/null || echo "$SIMPLE_RESPONSE"

if echo "$SIMPLE_RESPONSE" | grep -q "generated_text"; then
    echo -e "${GREEN}✓ Simple generation passed${NC}"
    GENERATED_TEXT=$(echo "$SIMPLE_RESPONSE" | jq -r '.generated_text' 2>/dev/null)
    echo "Generated text: $GENERATED_TEXT"
else
    echo -e "${RED}✗ Simple generation failed${NC}"
fi
echo ""

# Test 3: JSON schema constrained generation
echo -e "${GREEN}Test 3: JSON Schema Constrained Generation${NC}"
echo "Generating user profile with JSON schema..."
JSON_REQUEST='{
  "prompt": "Generate a user profile:",
  "constraints": {
    "json_schema": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"},
        "email": {"type": "string"}
      },
      "required": ["name", "age"]
    }
  },
  "max_tokens": 100,
  "temperature": 0.7
}'

JSON_RESPONSE=$(curl -s -X POST "$SERVICE_URL" \
  -H "Content-Type: application/json" \
  -d "$JSON_REQUEST")

echo "Response:"
echo "$JSON_RESPONSE" | jq . 2>/dev/null || echo "$JSON_RESPONSE"

if echo "$JSON_RESPONSE" | grep -q "generated_text"; then
    echo -e "${GREEN}✓ JSON schema generation passed${NC}"
    CONSTRAINT_SATISFIED=$(echo "$JSON_RESPONSE" | jq -r '.constraint_satisfied' 2>/dev/null)
    echo "Constraint satisfied: $CONSTRAINT_SATISFIED"
else
    echo -e "${RED}✗ JSON schema generation failed${NC}"
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Service URL: $SERVICE_URL"
echo "Health URL: $HEALTH_URL"
echo ""
echo "All tests completed!"
echo ""
echo "To use this service in your code:"
echo "  export MODAL_ENDPOINT=\"https://rand--ananke-inference-generate-api.modal.run\""
echo "  export MODAL_HEALTH_ENDPOINT=\"https://rand--ananke-inference-health.modal.run\""
echo ""
