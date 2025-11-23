# Ananke Modal Inference - File Overview

Complete listing of all files in the modal_inference directory with descriptions.

## Core Implementation

### inference.py (14KB)
Main Modal service implementation.

**Contents:**
- InferenceService class with vLLM integration
- llguidance constraint compilation
- GPU configuration (A100 40GB/80GB)
- Three main endpoints:
  - `generate()`: Constrained code generation
  - `health_check()`: Service health status
  - `validate_constraints()`: Pre-validate constraints
- Comprehensive error handling and logging
- Provenance tracking for all generated code
- Support for multiple constraint types (JSON, regex, grammar, composite)

**Key Features:**
- Scale-to-zero (60s idle timeout)
- Concurrent request handling (10 per container)
- Sub-50μs logit masking
- Model caching across requests
- Detailed performance metrics

## Client Libraries

### client.py (13KB)
Python client library for easy integration.

**Contents:**
- `AnankeInferenceClient`: Modal-native client
- `AnankeInferenceHTTPClient`: HTTP client for cross-language use
- `ConstraintSpec`: Type-safe constraint specification
- `GenerationConfig`: Generation parameter configuration
- `GenerationResult`: Structured response with provenance
- Convenience methods for common constraint types

**Usage:**
```python
from modal_inference.client import AnankeInferenceClient

client = AnankeInferenceClient()
result = client.generate_with_json_schema(prompt, schema)
```

## Configuration

### config.yaml (3.6KB)
Comprehensive configuration file.

**Sections:**
- Service metadata (name, version, description)
- Model configuration (defaults, available models)
- GPU settings (type, count, memory utilization)
- Container settings (timeouts, concurrency)
- Generation defaults (temperature, top_p, max_tokens)
- Constraint settings (supported types, validation)
- Logging configuration
- Performance tuning
- Security options
- Monitoring metrics
- Development vs production presets

### requirements.txt (853B)
Python dependencies with pinned versions.

**Dependencies:**
- vllm==0.8.2 (inference engine)
- llguidance==0.2.0 (constraint enforcement)
- torch==2.5.1 (GPU operations)
- transformers==4.46.0 (model loading)
- huggingface-hub==0.26.2 (model downloads)
- pydantic==2.9.2 (validation)
- modal>=0.63.0 (deployment platform)

## Testing

### test_inference.py (12KB)
Comprehensive test suite.

**Test Suites:**
- `TestHealthAndValidation`: Health checks, constraint validation
- `TestConstrainedGeneration`: JSON schema, regex, minimal constraints
- `TestPerformance`: Speed benchmarks, cold start timing
- `TestErrorHandling`: Edge cases, malformed input
- `TestProvenance`: Metadata tracking, completeness

**Run with:**
```bash
modal run test_inference.py
# or
pytest test_inference.py
```

## Examples

### example_usage.py (12KB)
Seven comprehensive usage examples.

**Examples:**
1. JSON Schema Constraint (API handler generation)
2. Regex Pattern Constraint (class definition)
3. Grammar Constraint (custom DSL)
4. Composite Constraint (multiple rules)
5. Full Pipeline Simulation (Clew → Braid → Maze → Modal)
6. Health Check and Validation
7. Performance Benchmarking

**Run with:**
```bash
python example_usage.py
```

## Deployment

### deploy.sh (3.9KB)
Interactive deployment script.

**Features:**
- Modal CLI verification
- Authentication check
- HuggingFace secret setup
- Deployment mode selection (dev/prod/custom)
- Model configuration
- Post-deployment instructions
- Error handling and troubleshooting

**Run with:**
```bash
./deploy.sh
```

### Makefile (4.5KB)
Convenience commands for common operations.

**Commands:**
- `make install`: Install dependencies
- `make setup`: Configure Modal and secrets
- `make deploy`: Deploy service
- `make test`: Run tests
- `make run`: Run example
- `make examples`: Run all examples
- `make health`: Check service health
- `make logs`: Stream logs
- `make clean`: Clean cache
- Plus many more...

**Run with:**
```bash
make help  # Show all commands
```

## Documentation

### README.md (13KB)
Complete user documentation.

**Sections:**
- Overview and key features
- Architecture diagram
- Prerequisites and setup
- Deployment instructions
- Usage examples (Python and HTTP)
- Constraint types and examples
- Integration with Ananke pipeline
- Performance benchmarks
- Cost estimates
- Monitoring and debugging
- Troubleshooting
- Production deployment
- Security considerations

### QUICKSTART.md (3.9KB)
5-minute quick start guide.

**Steps:**
1. Install Modal
2. Authenticate
3. Set up HuggingFace
4. Deploy
5. Test
6. Use it

Includes common issues and next steps.

### ARCHITECTURE.md (9KB)
Technical architecture documentation.

**Contents:**
- System overview and diagrams
- Design decisions (why vLLM, llguidance, Modal)
- Model selection rationale
- Component breakdown
- Performance characteristics
- Constraint compilation details
- Error handling strategies
- Monitoring and observability
- Security considerations
- Integration points
- Future improvements

### FILES.md (this file)
Index of all files with descriptions.

## Supporting Files

### .gitignore (500B)
Standard gitignore for Python projects.

**Excludes:**
- Python cache and bytecode
- Virtual environments
- IDE files
- Modal cache
- Test artifacts
- Secrets and keys
- Temporary files

## File Tree

```
modal_inference/
├── inference.py              # Main service (14KB)
├── client.py                 # Client library (13KB)
├── config.yaml               # Configuration (3.6KB)
├── requirements.txt          # Dependencies (853B)
├── test_inference.py         # Tests (12KB)
├── example_usage.py          # Examples (12KB)
├── deploy.sh                 # Deployment script (3.9KB, executable)
├── Makefile                  # Task automation (4.5KB)
├── README.md                 # User docs (13KB)
├── QUICKSTART.md             # Quick start (3.9KB)
├── ARCHITECTURE.md           # Technical docs (9KB)
├── FILES.md                  # This file
└── .gitignore                # Git exclusions (500B)

Total: 12 files, ~85KB of code and documentation
```

## Quick Reference

### Getting Started
```bash
# Deploy
./deploy.sh

# Test
make test

# Run example
make run
```

### Most Used Files

**For users:**
1. QUICKSTART.md - Get started fast
2. README.md - Complete reference
3. example_usage.py - Copy/paste examples

**For developers:**
1. inference.py - Service implementation
2. client.py - Integration library
3. ARCHITECTURE.md - Technical details

**For operations:**
1. deploy.sh - Deployment
2. Makefile - Common tasks
3. config.yaml - Configuration

### File Sizes
- Code: ~39KB (inference.py + client.py + test_inference.py)
- Examples: ~12KB (example_usage.py)
- Docs: ~30KB (README + QUICKSTART + ARCHITECTURE)
- Config: ~5KB (config.yaml + requirements.txt + Makefile)
- Scripts: ~4KB (deploy.sh)

### Lines of Code
- Python code: ~1,400 lines
- Documentation: ~800 lines
- Configuration: ~200 lines
- Total: ~2,400 lines

## Integration Examples

### From Maze (Rust)
See README.md section "Integration with Ananke Pipeline"

### From Ananke CLI
See example_usage.py example 5

### From Python
See client.py examples at bottom of file

## Next Steps

After reviewing these files:

1. **Quick start**: Follow QUICKSTART.md
2. **Deploy**: Run ./deploy.sh
3. **Test**: Run make test
4. **Integrate**: Use client.py in your code
5. **Learn more**: Read ARCHITECTURE.md

## Support

For help with any file:
- File-specific questions: See comments in the file
- Usage questions: See README.md
- Technical questions: See ARCHITECTURE.md
- Quick answers: Run `make help` or `make info`
