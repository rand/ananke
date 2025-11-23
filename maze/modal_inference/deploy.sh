#!/bin/bash
# Ananke Modal Inference Service Deployment Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SERVICE_NAME="ananke-inference"
PYTHON_VERSION="3.11"

# Functions
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

check_modal_cli() {
    print_step "Checking Modal CLI installation..."

    if ! command -v modal &> /dev/null; then
        print_error "Modal CLI not found. Installing..."
        pip install modal
    else
        print_step "Modal CLI found: $(modal --version)"
    fi
}

check_modal_auth() {
    print_step "Checking Modal authentication..."

    if ! modal token list &> /dev/null; then
        print_warning "Not authenticated with Modal"
        echo "Please run: modal token new"
        echo "This will open a browser to authenticate."
        read -p "Press Enter after authenticating..."

        if ! modal token list &> /dev/null; then
            print_error "Authentication failed"
            exit 1
        fi
    else
        print_step "Modal authentication verified"
    fi
}

install_dependencies() {
    print_step "Installing Python dependencies..."

    # Create virtual environment if it doesn't exist
    if [ ! -d "$SCRIPT_DIR/venv" ]; then
        python3 -m venv "$SCRIPT_DIR/venv"
    fi

    source "$SCRIPT_DIR/venv/bin/activate"

    pip install -q --upgrade pip
    pip install -q modal requests

    print_step "Dependencies installed"
}

validate_config() {
    print_step "Validating configuration..."

    if [ ! -f "$SCRIPT_DIR/config.yaml" ]; then
        print_error "config.yaml not found"
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/inference.py" ]; then
        print_error "inference.py not found"
        exit 1
    fi

    print_step "Configuration valid"
}

deploy_service() {
    print_step "Deploying Modal service..."

    cd "$SCRIPT_DIR"

    # Deploy the service
    modal deploy inference.py

    print_step "Deployment initiated"
}

get_service_url() {
    print_step "Getting service URL..."

    # Wait a bit for deployment to complete
    sleep 2

    # Get the app URL
    APP_URL=$(modal app list | grep "$SERVICE_NAME" | awk '{print $2}' || true)

    if [ -z "$APP_URL" ]; then
        print_warning "Could not automatically detect service URL"
        echo "Please check: modal app list"
    else
        print_step "Service URL: $APP_URL"
        echo "export MODAL_ENDPOINT=\"$APP_URL\"" > "$SCRIPT_DIR/.env"
        print_step "Saved to $SCRIPT_DIR/.env"
    fi
}

test_service() {
    print_step "Testing deployed service..."

    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi

    if [ -z "${MODAL_ENDPOINT:-}" ]; then
        print_warning "MODAL_ENDPOINT not set, skipping tests"
        echo "Set MODAL_ENDPOINT and run: python client.py"
        return
    fi

    # Test with client
    python3 "$SCRIPT_DIR/client.py" "$MODAL_ENDPOINT" || {
        print_warning "Client test failed - service may still be starting"
        echo "Wait a few seconds and try: MODAL_ENDPOINT=$MODAL_ENDPOINT python client.py"
    }
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "Deployment Summary"
    echo "=========================================="
    echo "Service Name: $SERVICE_NAME"
    echo "Status: Deployed"
    echo ""

    if [ -f "$SCRIPT_DIR/.env" ]; then
        echo "Environment variables saved to: $SCRIPT_DIR/.env"
        echo "Load with: source $SCRIPT_DIR/.env"
        echo ""
    fi

    echo "Useful commands:"
    echo "  modal app list                  # List deployed apps"
    echo "  modal app logs $SERVICE_NAME    # View logs"
    echo "  modal app stop $SERVICE_NAME    # Stop the app"
    echo ""
    echo "Test the service:"
    echo "  export MODAL_ENDPOINT=<your-url>"
    echo "  python $SCRIPT_DIR/client.py"
    echo ""
    echo "Integration with Rust:"
    echo "  export MODAL_ENDPOINT=<your-url>"
    echo "  cd .."
    echo "  cargo run --example simple_generation"
    echo "=========================================="
}

# Main execution
main() {
    print_step "Starting Modal deployment for $SERVICE_NAME"

    check_modal_cli
    check_modal_auth
    install_dependencies
    validate_config
    deploy_service
    get_service_url

    # Optional: test the service
    if [ "${SKIP_TESTS:-false}" != "true" ]; then
        test_service
    fi

    print_summary
}

# Run main
main "$@"
