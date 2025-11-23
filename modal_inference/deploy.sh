#!/bin/bash
# Ananke Modal Inference Deployment Script

set -e  # Exit on error

echo "======================================"
echo "Ananke Modal Inference Deployment"
echo "======================================"
echo ""

# Check if Modal CLI is installed
if ! command -v modal &> /dev/null; then
    echo "Error: Modal CLI not found"
    echo "Install with: pip install modal"
    exit 1
fi

echo "✓ Modal CLI found"

# Check if authenticated
if ! modal token list &> /dev/null; then
    echo "Error: Not authenticated with Modal"
    echo "Run: modal token new"
    exit 1
fi

echo "✓ Modal authentication verified"

# Check for HuggingFace secret
echo ""
echo "Checking for HuggingFace secret..."
if ! modal secret list | grep -q "huggingface-secret"; then
    echo ""
    echo "⚠ HuggingFace secret not found"
    echo ""
    echo "To create the secret, run:"
    echo "  modal secret create huggingface-secret \\"
    echo "    HUGGING_FACE_HUB_TOKEN=hf_your_token_here"
    echo ""
    read -p "Have you created the secret? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please create the secret first, then run this script again."
        exit 1
    fi
else
    echo "✓ HuggingFace secret found"
fi

# Get deployment mode
echo ""
echo "Select deployment mode:"
echo "  1) Development (Llama 3.1 8B, faster, cheaper)"
echo "  2) Production (Llama 3.1 70B, higher quality)"
echo "  3) Custom (specify model)"
echo ""
read -p "Choice [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
        GPU_SIZE="40"
        echo "Selected: Development mode (8B model, A100 40GB)"
        ;;
    2)
        MODEL="meta-llama/Meta-Llama-3.1-70B-Instruct"
        GPU_SIZE="80"
        echo "Selected: Production mode (70B model, A100 80GB)"
        ;;
    3)
        read -p "Enter model name: " MODEL
        read -p "Enter GPU size (40/80) [40]: " GPU_SIZE
        GPU_SIZE=${GPU_SIZE:-40}
        echo "Selected: Custom mode ($MODEL, A100 ${GPU_SIZE}GB)"
        ;;
    *)
        echo "Invalid choice, using development mode"
        MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
        GPU_SIZE="40"
        ;;
esac

# Update inference.py with selected model (optional)
if [[ $choice != "1" ]]; then
    echo ""
    echo "Note: To use this model as default, update DEFAULT_MODEL in inference.py"
    echo "  Current: meta-llama/Meta-Llama-3.1-8B-Instruct"
    echo "  Suggested: $MODEL"
fi

# Run deployment
echo ""
echo "======================================"
echo "Deploying to Modal..."
echo "======================================"
echo ""

cd "$(dirname "$0")"

# Deploy the service
modal deploy inference.py

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✓ Deployment Successful!"
    echo "======================================"
    echo ""
    echo "Your inference service is now running on Modal."
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Test the deployment:"
    echo "   modal run inference.py"
    echo ""
    echo "2. Run the test suite:"
    echo "   modal run test_inference.py"
    echo ""
    echo "3. Try example usage:"
    echo "   python example_usage.py"
    echo ""
    echo "4. View logs:"
    echo "   modal app logs ananke-inference"
    echo ""
    echo "5. Get the web endpoint URL:"
    echo "   modal app list"
    echo "   Look for: generate_endpoint => https://..."
    echo ""
    echo "For more information, see README.md"
    echo ""
else
    echo ""
    echo "======================================"
    echo "✗ Deployment Failed"
    echo "======================================"
    echo ""
    echo "Common issues:"
    echo "  - HuggingFace token not set or invalid"
    echo "  - Model not accessible (check license agreement)"
    echo "  - Syntax errors in inference.py"
    echo "  - Network issues"
    echo ""
    echo "Check the error messages above for details."
    echo ""
    exit 1
fi
