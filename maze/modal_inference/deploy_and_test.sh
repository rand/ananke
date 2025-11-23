#!/bin/bash
#
# Deploy Modal inference service fix and verify it works
#

set -e  # Exit on error

echo "======================================================================"
echo "Ananke Modal Inference Service - Deploy & Test"
echo "======================================================================"
echo ""

# Change to the modal_inference directory
cd "$(dirname "$0")"

echo "Step 1: Verify Modal authentication"
echo "----------------------------------------------------------------------"
if ! modal token list &> /dev/null; then
    echo "Error: Not authenticated with Modal"
    echo "Run: modal token new"
    exit 1
fi
echo "✓ Modal authentication verified"
echo ""

echo "Step 2: Deploy the fixed inference service"
echo "----------------------------------------------------------------------"
echo "Deploying to Modal..."
modal deploy inference.py
echo "✓ Deployment complete"
echo ""

echo "Step 3: Extract endpoint URLs"
echo "----------------------------------------------------------------------"
# Get the health URL
HEALTH_URL="https://rand--ananke-inference-health.modal.run"
GENERATE_URL="https://rand--ananke-inference-generate-api.modal.run"

echo "Health endpoint:    $HEALTH_URL"
echo "Generate endpoint:  $GENERATE_URL"
echo ""

echo "Step 4: Wait for service to be ready (5 seconds)"
echo "----------------------------------------------------------------------"
sleep 5
echo "✓ Ready"
echo ""

echo "Step 5: Quick smoke test - Health check"
echo "----------------------------------------------------------------------"
if curl -s "$HEALTH_URL" | grep -q "healthy"; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    exit 1
fi
echo ""

echo "Step 6: Quick smoke test - Simple generation"
echo "----------------------------------------------------------------------"
RESPONSE=$(curl -s -X POST "$GENERATE_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Write a Python function to add two numbers:",
    "max_tokens": 50,
    "temperature": 0.7
  }')

# Check if response contains error
if echo "$RESPONSE" | grep -q '"finish_reason": "error"'; then
    echo "✗ Generation failed with error:"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
elif echo "$RESPONSE" | grep -q '"generated_text"'; then
    echo "✓ Generation succeeded"
    echo "$RESPONSE" | python3 -m json.tool | head -20
else
    echo "✗ Unexpected response format"
    echo "$RESPONSE"
    exit 1
fi
echo ""

echo "Step 7: Run comprehensive test suite"
echo "----------------------------------------------------------------------"
if [ -f "test_fix.py" ]; then
    echo "Running test_fix.py..."
    python3 test_fix.py "$GENERATE_URL" || {
        echo ""
        echo "⚠ Some tests failed. Check the output above."
        exit 1
    }
else
    echo "⚠ test_fix.py not found, skipping comprehensive tests"
fi
echo ""

echo "======================================================================"
echo "✓ DEPLOYMENT AND TESTING COMPLETE"
echo "======================================================================"
echo ""
echo "Service URLs:"
echo "  Health:   $HEALTH_URL"
echo "  Generate: $GENERATE_URL"
echo ""
echo "Next steps:"
echo "  1. Update .env file with endpoint URLs"
echo "  2. Test with client.py"
echo "  3. Monitor logs: modal app logs ananke-inference --follow"
echo "  4. Update Rust integration config"
echo ""
