# Ananke Deployment Guide

Complete guide for deploying and distributing Ananke constraint-driven code generation system.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation Methods](#installation-methods)
  - [Quick Install (Recommended)](#quick-install-recommended)
  - [Homebrew (macOS/Linux)](#homebrew-macoslinux)
  - [Docker](#docker)
  - [From Source](#from-source)
  - [Pre-built Binaries](#pre-built-binaries)
- [Configuration](#configuration)
- [Verification](#verification)
- [Updating](#updating)
- [Uninstallation](#uninstallation)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

The fastest way to get started with Ananke:

### macOS/Linux

```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 | iex
```

### Verify Installation

```bash
ananke --version
ananke help
```

---

## Installation Methods

### Quick Install (Recommended)

#### Unix/Linux/macOS

The installation script automatically:
- Detects your platform and architecture
- Downloads the latest release
- Verifies checksums
- Installs to `~/.local` by default
- Updates your PATH

**Default installation:**
```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
```

**Custom installation directory:**
```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | PREFIX=/usr/local bash
```

**Specific version:**
```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | ANANKE_VERSION=v0.1.0 bash
```

**Local installation (if you've cloned the repo):**
```bash
cd ananke
./scripts/install.sh --prefix=$HOME/.local
```

#### Windows (PowerShell)

**Default installation:**
```powershell
irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 | iex
```

**Custom installation directory:**
```powershell
irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 | iex -Prefix "C:\Program Files\Ananke"
```

**Specific version:**
```powershell
& { irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 } | iex -Version "v0.1.0"
```

**Local installation:**
```powershell
.\scripts\install.ps1 -Prefix "$env:LOCALAPPDATA\ananke"
```

---

### Homebrew (macOS/Linux)

Coming soon! We're working on publishing to Homebrew.

**Once available:**
```bash
# Add Ananke tap (one time)
brew tap ananke-ai/ananke

# Install Ananke
brew install ananke

# Verify installation
ananke --version
```

**Update:**
```bash
brew update
brew upgrade ananke
```

**Uninstall:**
```bash
brew uninstall ananke
```

---

### Docker

Perfect for containerized environments, CI/CD pipelines, or isolated testing.

#### Pull Pre-built Image

```bash
# Pull latest version
docker pull ghcr.io/ananke-ai/ananke:latest

# Pull specific version
docker pull ghcr.io/ananke-ai/ananke:v0.1.0
```

#### Build Locally

```bash
# Clone repository
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# Build image
docker build -t ananke:latest .

# Verify build
docker run --rm ananke:latest --version
```

#### Usage Examples

**Extract constraints from local code:**
```bash
docker run --rm -v $(pwd):/workspace ananke:latest extract /workspace/src/
```

**Interactive shell:**
```bash
docker run --rm -it -v $(pwd):/workspace ananke:latest /bin/sh
```

**With environment variables:**
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  ananke:latest extract /workspace/src/ --use-claude
```

#### Docker Compose

For more complex setups with persistent configuration:

```bash
# Start services
docker-compose up -d

# Run commands
docker-compose run ananke extract /workspace/src/

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Custom `docker-compose.yml` configuration:**
```yaml
version: '3.8'

services:
  ananke:
    image: ghcr.io/ananke-ai/ananke:latest
    volumes:
      - ./code:/workspace:ro
      - ./output:/output
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - MODAL_ENDPOINT=${MODAL_ENDPOINT}
      - LOG_LEVEL=info
```

---

### From Source

Build Ananke from source for development or custom configurations.

#### Prerequisites

- **Zig** 0.15.2 or later
- **Rust** 1.80 or later
- **Git**

#### Installation Steps

```bash
# 1. Clone repository
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# 2. Build Zig components
zig build -Doptimize=ReleaseSafe

# 3. Build Rust Maze library
cd maze
cargo build --release
cd ..

# 4. Run tests (optional but recommended)
zig build test
cd maze && cargo test && cd ..

# 5. Install to system (optional)
./scripts/install.sh --prefix=/usr/local
```

#### Development Build

For development with debug symbols:

```bash
zig build
cd maze && cargo build && cd ..
```

---

### Pre-built Binaries

Download platform-specific binaries from GitHub releases.

#### Download

1. Go to [Releases](https://github.com/ananke-ai/ananke/releases)
2. Download the archive for your platform:
   - **Linux**: `ananke-v*-linux-x86_64.tar.gz`
   - **macOS Intel**: `ananke-v*-macos-x86_64.tar.gz`
   - **macOS Apple Silicon**: `ananke-v*-macos-aarch64.tar.gz`
   - **Windows**: `ananke-v*-windows-x86_64.zip`

#### Extract and Install

**Linux/macOS:**
```bash
# Extract
tar -xzf ananke-v0.1.0-linux-x86_64.tar.gz
cd ananke-v0.1.0-linux-x86_64

# Install (uses installation script)
./install.sh

# Or manual installation
sudo cp bin/ananke /usr/local/bin/
sudo cp lib/* /usr/local/lib/
```

**Windows:**
```powershell
# Extract ZIP file
Expand-Archive ananke-v0.1.0-windows-x86_64.zip

# Add to PATH or copy to system directory
Copy-Item .\ananke-v0.1.0-windows-x86_64\bin\ananke.exe C:\Windows\System32\
```

#### Verify Checksums

Always verify checksums for security:

```bash
# Download checksum file
curl -LO https://github.com/ananke-ai/ananke/releases/download/v0.1.0/ananke-v0.1.0-checksums.txt

# Verify (Linux/macOS)
sha256sum -c ananke-v0.1.0-checksums.txt --ignore-missing

# Verify (macOS with shasum)
shasum -a 256 -c ananke-v0.1.0-checksums.txt --ignore-missing
```

---

## Configuration

### Environment Variables

Ananke uses environment variables for configuration:

```bash
# Claude API for semantic analysis (optional)
export ANTHROPIC_API_KEY="sk-ant-..."

# Modal endpoint for constrained generation (optional)
export MODAL_ENDPOINT="https://rand--ananke-inference-generate-api.modal.run"

# Log level (debug, info, warn, error)
export LOG_LEVEL="info"

# Cache directory
export ANANKE_CACHE_DIR="$HOME/.cache/ananke"
```

### Configuration File

Create `~/.config/ananke/config.toml`:

```toml
# Ananke Configuration

[api]
# Claude API key (optional - can also use ANTHROPIC_API_KEY env var)
# anthropic_api_key = "sk-ant-..."

# Modal endpoint (optional - can also use MODAL_ENDPOINT env var)
# modal_endpoint = "https://your-modal-endpoint.modal.run"

[extraction]
# Use Claude for semantic analysis
use_claude = false

# Supported languages
languages = ["typescript", "python", "rust", "zig", "go"]

[compilation]
# Optimize with LLM
optimize_with_llm = false

[generation]
# Default model
model = "Qwen/Qwen2.5-Coder-32B-Instruct"

# Default temperature
temperature = 0.7

# Max tokens
max_tokens = 2000

[logging]
# Log level: debug, info, warn, error
level = "info"

# Log file (optional)
# file = "/var/log/ananke.log"

[cache]
# Cache directory
directory = "~/.cache/ananke"

# Cache size limit (MB)
max_size = 500
```

---

## Verification

### Health Check

Run the comprehensive health check:

```bash
# Basic health check
./scripts/health-check.sh

# Verbose output
./scripts/health-check.sh --verbose

# Check Modal connectivity
./scripts/health-check.sh --modal-endpoint https://your-endpoint.modal.run
```

### Manual Verification

```bash
# 1. Check version
ananke --version

# 2. List available commands
ananke help

# 3. Extract constraints from sample file
echo 'function add(a: number, b: number): number { return a + b; }' > test.ts
ananke extract test.ts

# 4. Compile constraints
ananke compile constraints.json

# 5. Generate code (requires Modal endpoint)
ananke generate "implement user authentication" --constraints compiled.cir
```

---

## Updating

### Quick Install Script

```bash
# Update to latest version
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash

# Update to specific version
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | ANANKE_VERSION=v0.2.0 bash
```

### Homebrew

```bash
brew update
brew upgrade ananke
```

### Docker

```bash
# Pull latest image
docker pull ghcr.io/ananke-ai/ananke:latest

# Or rebuild
docker build -t ananke:latest .
```

### From Source

```bash
cd ananke
git pull origin main
zig build -Doptimize=ReleaseSafe
cd maze && cargo build --release && cd ..
./scripts/install.sh
```

---

## Uninstallation

### Quick Install

```bash
# Remove binaries and libraries
rm -rf ~/.local/bin/ananke
rm -rf ~/.local/lib/libananke.a
rm -rf ~/.local/lib/libmaze.*

# Remove configuration
rm -rf ~/.config/ananke

# Remove cache
rm -rf ~/.cache/ananke
```

### Homebrew

```bash
brew uninstall ananke
```

### Docker

```bash
# Remove containers
docker-compose down
docker rm -f ananke-cli

# Remove images
docker rmi ananke:latest
docker rmi ghcr.io/ananke-ai/ananke:latest

# Remove volumes
docker volume rm ananke-cargo-cache ananke-zig-cache
```

---

## Production Deployment

### CI/CD Integration

#### GitHub Actions

```yaml
name: CI with Ananke

on: [push, pull_request]

jobs:
  constraint-validation:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Ananke
        run: |
          curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
          echo "$HOME/.local/bin" >> $GITHUB_PATH

      - name: Extract constraints
        run: ananke extract ./src --output constraints.json

      - name: Compile constraints
        run: ananke compile constraints.json --output compiled.cir

      - name: Validate code
        run: ananke validate ./src compiled.cir
```

#### GitLab CI

```yaml
constraint-check:
  image: ghcr.io/ananke-ai/ananke:latest
  script:
    - ananke extract ./src --output constraints.json
    - ananke compile constraints.json --output compiled.cir
    - ananke validate ./src compiled.cir
```

#### Jenkins

```groovy
pipeline {
    agent any

    stages {
        stage('Install Ananke') {
            steps {
                sh 'curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash'
            }
        }

        stage('Extract Constraints') {
            steps {
                sh 'ananke extract ./src --output constraints.json'
            }
        }

        stage('Compile Constraints') {
            steps {
                sh 'ananke compile constraints.json --output compiled.cir'
            }
        }
    }
}
```

### Kubernetes Deployment

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ananke-config
data:
  MODAL_ENDPOINT: "https://your-endpoint.modal.run"
  LOG_LEVEL: "info"

---
apiVersion: batch/v1
kind: Job
metadata:
  name: ananke-extract
spec:
  template:
    spec:
      containers:
      - name: ananke
        image: ghcr.io/ananke-ai/ananke:latest
        command: ["ananke", "extract", "/workspace/src"]
        volumeMounts:
        - name: workspace
          mountPath: /workspace
        envFrom:
        - configMapRef:
            name: ananke-config
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: workspace-pvc
      restartPolicy: Never
```

### Modal Inference Service

For production constraint-driven generation, deploy the Modal inference service:

```python
# modal_deploy.py
import modal

stub = modal.Stub("ananke-inference")

@stub.function(
    image=modal.Image.debian_slim().pip_install(
        "vllm==0.11.0",
        "llguidance==0.7.11",
    ),
    gpu="A100",
    timeout=3600,
)
def generate(prompt: str, constraints: dict) -> str:
    # Implement constrained generation with vLLM + llguidance
    pass

@stub.webhook(method="POST")
def generate_api(request: dict) -> dict:
    result = generate.call(
        request["prompt"],
        request["constraints"]
    )
    return {"code": result}
```

Deploy:
```bash
modal deploy modal_deploy.py
```

---

## Troubleshooting

### Common Issues

#### "ananke: command not found"

**Cause:** Binary not in PATH

**Solution:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# Reload shell
source ~/.bashrc  # or source ~/.zshrc
```

#### "Permission denied" when running binary

**Cause:** Binary not executable

**Solution:**
```bash
chmod +x ~/.local/bin/ananke
```

#### "Library not found" errors on Linux

**Cause:** Missing system libraries

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install libgcc1 libstdc++6

# Fedora/RHEL
sudo dnf install libgcc libstdc++

# Arch
sudo pacman -S gcc-libs
```

#### Docker build fails

**Cause:** Insufficient resources

**Solution:**
Increase Docker memory and CPU limits:
- Docker Desktop: Settings → Resources
- Recommended: 4GB+ RAM, 2+ CPUs

#### Extraction fails with "Tree-sitter not found"

**Cause:** Tree-sitter parsers not available (expected in early versions)

**Solution:**
This is a known limitation. Use Claude-based extraction:
```bash
ananke extract ./src --use-claude
```

### Getting Help

- **Documentation:** [README.md](../README.md)
- **Issues:** [GitHub Issues](https://github.com/ananke-ai/ananke/issues)
- **Discussions:** [GitHub Discussions](https://github.com/ananke-ai/ananke/discussions)
- **Security:** See [SECURITY.md](../SECURITY.md)

### Debug Mode

Enable verbose logging:

```bash
# Environment variable
export LOG_LEVEL=debug
ananke extract ./src

# Command flag
ananke --verbose extract ./src
```

### Health Check

Run comprehensive diagnostics:

```bash
./scripts/health-check.sh --verbose
```

---

## Security Considerations

See [SECURITY.md](../SECURITY.md) for:
- API key management
- Secrets handling
- Network security
- Container security
- Vulnerability reporting

---

## Next Steps

After installation:

1. **Quickstart:** Follow [QUICKSTART.md](../QUICKSTART.md)
2. **User Guide:** Read [docs/USER_GUIDE.md](USER_GUIDE.md)
3. **Examples:** Explore `examples/` directory
4. **Architecture:** Understand system design in [docs/ARCHITECTURE.md](ARCHITECTURE.md)

---

## Maintenance

### Logs

- **Linux:** `~/.cache/ananke/logs/`
- **macOS:** `~/Library/Caches/ananke/logs/`
- **Windows:** `%LOCALAPPDATA%\ananke\logs\`

### Cache

Clear cache to free space:

```bash
rm -rf ~/.cache/ananke/*
```

### Updates

Check for updates:

```bash
# View current version
ananke --version

# Check latest release
curl -s https://api.github.com/repos/ananke-ai/ananke/releases/latest | grep tag_name
```

---

For more information, visit the [Ananke GitHub repository](https://github.com/ananke-ai/ananke).
