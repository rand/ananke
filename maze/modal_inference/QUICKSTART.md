# Ananke Modal Inference Service - Quick Start Guide

## Service Information

**Status**: ✓ DEPLOYED
**Health URL**: https://rand--ananke-inference-health.modal.run
**API URL**: https://rand--ananke-inference-generate-api.modal.run
**Dashboard**: https://modal.com/apps/rand/main/deployed/ananke-inference

## Quick Setup

### 1. Load Environment Variables

```bash
cd /Users/rand/src/ananke/maze/modal_inference
source .env
```

This sets:
- `MODAL_ENDPOINT` - Main API endpoint
- `MODAL_HEALTH_ENDPOINT` - Health check endpoint
- `MODAL_MODEL` - Model being used

### 2. Test Health Check

```bash
curl $MODAL_HEALTH_ENDPOINT
```

Expected response:
```json
{"status":"healthy","service":"ananke-inference","version":"1.0.0"}
```

### 3. Test Generation (when fixed)

```bash
curl -X POST $MODAL_ENDPOINT \
  -H "Content-Type: application/json" \
  -d @test_request.json
```

## Integration with Rust Maze

Update your Maze configuration to use the deployed service:

```bash
# In your shell
export MODAL_ENDPOINT="https://rand--ananke-inference-generate-api.modal.run"

# Then run Maze examples
cd /Users/rand/src/ananke/maze
cargo run --example simple_generation
```

Or configure programmatically in Rust:

```rust
use maze::{MazeOrchestrator, ModalConfig};

let config = ModalConfig::new(
    "https://rand--ananke-inference-generate-api.modal.run".to_string(),
    "meta-llama/Llama-3.1-8B-Instruct".to_string(),
);

let orchestrator = MazeOrchestrator::new(config)?;
```

## Management Commands

```bash
# View logs
modal app logs ananke-inference

# List apps
modal app list

# Stop the service
modal app stop ananke-inference

# Redeploy after changes
modal deploy inference.py
```

## Known Issues

⚠️ **Current Issue**: The generation endpoint has a model initialization bug. See `DEPLOYMENT_REPORT.md` for details and fixes.

The health check works perfectly, but generation needs a quick fix to the initialization code.

## Files Reference

- `inference.py` - Main service code
- `client.py` - Python client library
- `config.yaml` - Configuration
- `deploy.sh` - Deployment script
- `.env` - Environment variables
- `DEPLOYMENT_REPORT.md` - Full deployment details
- `README.md` - Complete documentation

## Cost Information

- **Idle**: $0 (scales to zero after 60s)
- **Active**: ~$3.60/hour (A100-40GB GPU)
- **Light usage**: $5-10/month (100 requests/day)

## Support

- Dashboard: https://modal.com/apps/rand/main/deployed/ananke-inference
- Logs: `modal app logs ananke-inference`
- Modal Docs: https://modal.com/docs
