# Ananke Installation Quick Reference

Ultra-fast guide to installing Ananke on any platform.

## One-Line Install

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 | iex
```

### Docker
```bash
docker run --rm -v $(pwd):/workspace ghcr.io/ananke-ai/ananke:latest extract /workspace/
```

## Verify Installation

```bash
ananke --version
ananke help
```

## Quick Start

```bash
# Extract constraints from code
ananke extract ./src

# Compile constraints
ananke compile constraints.json

# Generate code (requires Modal endpoint)
export MODAL_ENDPOINT="https://your-endpoint.modal.run"
ananke generate "implement auth handler" --constraints compiled.cir
```

## Installation Options

| Method | Command | Time | Best For |
|--------|---------|------|----------|
| **Quick Install** | `curl ... \| bash` | 2 min | Most users |
| **Homebrew** | `brew install ananke` | 1 min | macOS/Linux users |
| **Docker** | `docker pull ...` | 5 min | Containerized workflows |
| **Source** | `git clone && zig build` | 10 min | Developers |

## Configuration

```bash
# Optional: Claude for semantic analysis
export ANTHROPIC_API_KEY="sk-ant-..."

# Optional: Modal for constrained generation
export MODAL_ENDPOINT="https://your-modal-endpoint.modal.run"
```

## Troubleshooting

**Command not found?**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Permission denied?**
```bash
chmod +x ~/.local/bin/ananke
```

**Health check:**
```bash
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/health-check.sh | bash
```

## Get Help

- **Docs:** [github.com/ananke-ai/ananke](https://github.com/ananke-ai/ananke)
- **Issues:** [github.com/ananke-ai/ananke/issues](https://github.com/ananke-ai/ananke/issues)
- **Full Guide:** See [DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Uninstall

```bash
rm -rf ~/.local/bin/ananke ~/.local/lib/libananke.* ~/.config/ananke ~/.cache/ananke
```

---

**Version:** 0.1.0 | **License:** MIT OR Apache-2.0
