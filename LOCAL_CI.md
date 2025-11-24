# Local CI/CD for Ananke

**Status**: Primary validation method for v0.1.0+
**GitHub Actions**: Disabled (private repository, manual validation preferred)

## Quick Start

Run all tests and checks before committing:

```bash
./scripts/local-ci.sh
```

## What It Does

The local CI script runs:

1. **Prerequisites Check**
   - Zig 0.15.2+ installation
   - Rust/Cargo installation

2. **Zig Tests** (Required)
   - Build project: `zig build`
   - Run all tests: `zig build test --summary all`
   - Result: 118/118 tests must pass

3. **Rust Tests** (Required)
   - Format check: `cargo fmt --check`
   - Linting: `cargo clippy`
   - Build: `cargo build`
   - Tests: `cargo test --all`
   - Result: 32/32 tests must pass

4. **Benchmarks** (Optional)
   - Zig: `zig build bench`
   - Rust: `cargo bench --no-run`

5. **Security** (Optional)
   - Check for hardcoded secrets
   - Run `cargo audit` (if installed)

## Skip Optional Checks

To skip benchmarks and security checks:

```bash
SKIP_OPTIONAL=1 ./scripts/local-ci.sh
```

## Manual Test Commands

### Zig Tests Only
```bash
zig build test --summary all
```

### Rust Tests Only
```bash
cd maze && cargo test --all
```

### Quick Validation
```bash
zig build test && cd maze && cargo test
```

## Pre-Commit Workflow

Recommended workflow before committing:

```bash
# 1. Run local CI
./scripts/local-ci.sh

# 2. If all tests pass, commit
git add .
git commit -m "your commit message"

# 3. Push to remote
git push
```

## CI Results Interpretation

### Success Output
```
===================================================
CI Summary
===================================================
✓ All checks passed! ✓

Safe to commit and push your changes.

Next steps:
  git add .
  git commit -m "your message"
  git push
```

### Failure Output
```
===================================================
CI Summary
===================================================
✗ Some checks failed ✗

Please fix the failures before committing.
```

## Expected Test Counts

- **Zig**: 118 tests (27 build steps)
- **Rust**: 32 tests
  - FFI tests: 12
  - Orchestrator tests: 11
  - Zig integration: 8
  - Doc tests: 1
- **Total**: 150 tests

## Performance Metrics

Expected local test runtime:
- **Zig tests**: ~5-10 seconds
- **Rust tests**: ~15-30 seconds
- **Total**: ~30-45 seconds

## Troubleshooting

### "Zig not found"
Install Zig 0.15.2+:
```bash
# macOS
brew install zig

# Or download from https://ziglang.org/download/
```

### "Cargo not found"
Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Tests Failing
1. Check that you're on the latest `main` branch
2. Run `zig build clean && cd maze && cargo clean`
3. Try again with `./scripts/local-ci.sh`
4. If still failing, check the specific error messages

### Permission Denied
Make script executable:
```bash
chmod +x scripts/local-ci.sh
```

## GitHub Actions (Disabled)

GitHub Actions workflows are currently disabled for this private repository.
File: `.github/workflows/maze-tests.yml.disabled`

**Reason**: Private repository with billing constraints, local CI is more cost-effective.

**To Re-enable** (if/when repository becomes public):
```bash
mv .github/workflows/maze-tests.yml.disabled .github/workflows/maze-tests.yml
git add .github/workflows/
git commit -m "ci: re-enable GitHub Actions"
git push
```

## Integration with Git Hooks

Optional: Set up pre-commit hook to run CI automatically:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running local CI before commit..."
./scripts/local-ci.sh
EOF

chmod +x .git/hooks/pre-commit
```

Now CI runs automatically before every commit.

## For Contributors

All contributors must run local CI before submitting changes:

1. **Fork & clone** the repository
2. **Make changes** in a feature branch
3. **Run CI**: `./scripts/local-ci.sh`
4. **Fix any failures**
5. **Commit only when all tests pass**
6. **Submit pull request**

Note: Even with GitHub Actions disabled, maintainers will run local CI to validate PRs.

## Comparison to GitHub Actions

| Feature | Local CI | GitHub Actions |
|---------|----------|----------------|
| Cost | Free | $$$ (private repos) |
| Speed | Fast (local hardware) | Slower (queue + cold start) |
| Platforms | Current OS only | Multi-platform |
| Feedback | Immediate | After push |
| Offline | Works offline | Requires internet |
| Debugging | Easy (local) | Harder (remote) |

For v0.1.0, local CI provides faster feedback and zero cost for private development.

## Future Plans

- **v0.1.1**: Continue with local CI
- **v0.2.0**: Consider GitHub Actions if repository becomes public
- **v1.0.0**: Automated multi-platform CI for releases

---

**Last Updated**: 2025-11-24
**Maintained By**: Ananke Core Team
