# Ananke Modal Inference Makefile

.PHONY: help install setup deploy test run examples clean logs health

help:
	@echo "Ananke Modal Inference Service"
	@echo ""
	@echo "Available commands:"
	@echo "  make install   - Install dependencies"
	@echo "  make setup     - Set up Modal authentication and secrets"
	@echo "  make deploy    - Deploy service to Modal"
	@echo "  make test      - Run test suite"
	@echo "  make run       - Run example generation"
	@echo "  make examples  - Run all examples"
	@echo "  make health    - Check service health"
	@echo "  make logs      - Stream service logs"
	@echo "  make clean     - Clean cache files"
	@echo ""

install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt
	pip install modal pytest
	@echo "✓ Dependencies installed"

setup:
	@echo "Setting up Modal..."
	@echo ""
	@echo "1. Authenticating with Modal..."
	modal token new
	@echo ""
	@echo "2. Setting up HuggingFace secret..."
	@echo "   Get your token from: https://huggingface.co/settings/tokens"
	@echo "   Accept Llama license: https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct"
	@echo ""
	@read -p "Enter HuggingFace token: " token; \
	modal secret create huggingface-secret HUGGING_FACE_HUB_TOKEN=$$token
	@echo ""
	@echo "✓ Setup complete"

deploy:
	@echo "Deploying to Modal..."
	./deploy.sh

deploy-dev:
	@echo "Deploying development version (8B model)..."
	modal deploy inference.py

deploy-prod:
	@echo "Deploying production version (70B model)..."
	@echo "Note: Edit inference.py to set DEFAULT_MODEL to 70B before running this"
	modal deploy inference.py

test:
	@echo "Running test suite..."
	modal run test_inference.py

run:
	@echo "Running example generation..."
	modal run inference.py

examples:
	@echo "Running all examples..."
	python example_usage.py

client-example:
	@echo "Running client example..."
	python client.py

health:
	@echo "Checking service health..."
	@python -c "import modal; \
		service = modal.Cls.lookup('ananke-inference', 'InferenceService')(); \
		health = service.health_check.remote(); \
		print('Status:', health['status']); \
		print('Model:', health['model']); \
		print('Timestamp:', health['timestamp'])"

logs:
	@echo "Streaming logs (Ctrl+C to stop)..."
	modal app logs ananke-inference

logs-function:
	@echo "Streaming function logs..."
	modal function logs ananke-inference.InferenceService.generate

list:
	@echo "Listing deployed apps..."
	modal app list

clean:
	@echo "Cleaning cache files..."
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Cache cleaned"

validate-constraints:
	@echo "Validating example constraints..."
	@python -c "import modal, json; \
		service = modal.Cls.lookup('ananke-inference', 'InferenceService')(); \
		constraint = {'type': 'json', 'schema': {'type': 'object', 'properties': {'name': {'type': 'string'}}}}; \
		result = service.validate_constraints.remote(constraint); \
		print(json.dumps(result, indent=2))"

benchmark:
	@echo "Running performance benchmark..."
	@python -c "from example_usage import example_benchmark; example_benchmark()"

# Development commands
dev-shell:
	@echo "Opening Modal shell..."
	modal shell ananke-inference

dev-watch:
	@echo "Watching for changes and redeploying..."
	@echo "Note: Use Ctrl+C to stop"
	@while true; do \
		inotifywait -e modify inference.py 2>/dev/null || fswatch -1 inference.py; \
		echo "File changed, redeploying..."; \
		modal deploy inference.py; \
	done

# Quick reference
info:
	@echo "Ananke Modal Inference Service"
	@echo ""
	@echo "Service: ananke-inference"
	@echo "Class: InferenceService"
	@echo "Model: Llama 3.1 8B Instruct (default)"
	@echo "GPU: A100 40GB"
	@echo "Idle timeout: 60 seconds"
	@echo ""
	@echo "Endpoints:"
	@echo "  - generate: Generate code with constraints"
	@echo "  - health_check: Service health status"
	@echo "  - validate_constraints: Validate constraint spec"
	@echo ""
	@echo "Files:"
	@echo "  - inference.py: Main service implementation"
	@echo "  - client.py: Python client library"
	@echo "  - test_inference.py: Test suite"
	@echo "  - example_usage.py: Usage examples"
	@echo "  - config.yaml: Configuration"
	@echo ""
	@echo "For more info: make help"

quickstart:
	@echo "Quick Start Guide"
	@echo ""
	@echo "1. Install: make install"
	@echo "2. Setup:   make setup"
	@echo "3. Deploy:  make deploy"
	@echo "4. Test:    make test"
	@echo "5. Run:     make run"
	@echo ""
	@echo "See QUICKSTART.md for details"
