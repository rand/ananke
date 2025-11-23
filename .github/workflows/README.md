# Ananke CI/CD Workflows

This directory contains all GitHub Actions workflows for the Ananke project. Our CI/CD pipeline is designed to be modular, cost-effective, and comprehensive.

## Workflow Overview

### 🔧 Core CI/CD

| Workflow | Purpose | Triggers | Duration | Cost |
|----------|---------|----------|----------|------|
| [ci.yml](ci.yml) | Main CI pipeline for Zig | Push to main/develop, PRs | ~5-8 min | Medium |
| [maze-tests.yml](maze-tests.yml) | Rust maze orchestration tests | Push to main/develop, PRs, Daily | ~3-5 min | Low |
| [release.yml](release.yml) | Release automation and binaries | Tags (v*.*.*), Manual | ~15-20 min | High |

### 📚 Documentation

| Workflow | Purpose | Triggers | Duration | Cost |
|----------|---------|----------|----------|------|
| [docs.yml](docs.yml) | Build and deploy documentation | Push to main, PRs | ~2-3 min | Low |

### 🔒 Security

| Workflow | Purpose | Triggers | Duration | Cost |
|----------|---------|----------|----------|------|
| [security.yml](security.yml) | Security scans and audits | Push, PRs, Weekly | ~5-7 min | Low |

### 🚀 Performance

| Workflow | Purpose | Triggers | Duration | Cost |
|----------|---------|----------|----------|------|
| [benchmarks.yml](benchmarks.yml) | Performance benchmarking | Weekly, Tags, Manual | ~10-15 min | Medium |

---

## Detailed Workflow Descriptions

### ci.yml - Main CI Pipeline

**Purpose**: Comprehensive continuous integration for the Zig codebase.

**Jobs**:
- `build-and-test`: Multi-platform builds (Ubuntu, macOS, Windows) with Zig 0.15.2
- `lint`: Code formatting and static analysis
- `coverage`: Test coverage reporting
- `security`: Basic security scans
- `build-matrix`: Cross-compilation for multiple targets
- `integration`: Integration testing
- `all-checks`: Gate job ensuring all checks pass

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual dispatch

**Caching**:
- Zig cache (`~/.cache/zig`, `.zig-cache`, `zig-out`)
- Key: OS + Zig version + hash of `build.zig` and `build.zig.zon`

**Artifacts**:
- Build binaries (7-day retention)
- Cross-compiled binaries for multiple platforms

**Cost Optimization**:
- Build artifacts only uploaded from Ubuntu runner
- Cross-compilation matrix runs only after main tests pass
- Caching reduces build times by 60-70%

---

### maze-tests.yml - Rust Testing

**Purpose**: Comprehensive testing for the Maze orchestration layer written in Rust.

**Jobs**:
- `test`: Run tests on Ubuntu and macOS with stable and beta Rust
- `coverage`: Generate code coverage with tarpaulin, upload to Codecov
- `benchmark`: Run Criterion benchmarks on PRs
- `security-audit`: Run `cargo audit` for vulnerability scanning

**Triggers**:
- Push to `main` or `develop` (when maze/ changes)
- Pull requests to `main` or `develop` (when maze/ changes)
- Daily scheduled run (2 AM UTC)
- Manual dispatch

**Matrix**:
- OS: Ubuntu (stable, beta), macOS (stable only)
- Rust: stable, beta

**Caching**:
- Cargo registry, git index, and build artifacts
- Key: OS + hash of `Cargo.lock`

**Artifacts**:
- Test results markdown (retention: indefinite)
- Coverage reports (uploaded to Codecov)

**Cost Optimization**:
- Beta tests only on Ubuntu to save macOS minutes
- Path filters ensure it only runs when maze/ directory changes
- Benchmark runs only on PRs (not every push)

---

### release.yml - Release Automation

**Purpose**: Automated release builds and asset publishing.

**Jobs**:
- `create-release`: Generate changelog and create GitHub release
- `build-release`: Build binaries for all platforms (Linux, macOS, Windows, x86_64/aarch64)
- `build-checksums`: Generate SHA256 checksums for all assets
- `publish-homebrew`: Placeholder for Homebrew formula update
- `publish-aur`: Placeholder for AUR package update
- `announce-release`: Placeholder for release announcements

**Triggers**:
- Push tags matching `v*.*.*` (e.g., v1.0.0)
- Manual dispatch with tag input

**Platforms**:
- Linux: x86_64, aarch64
- macOS: x86_64, aarch64 (Apple Silicon)
- Windows: x86_64

**Optimization**: ReleaseFast for maximum performance

**Artifacts**:
- Compressed binaries (.tar.gz for Unix, .zip for Windows)
- SHA256 checksums for verification
- Combined checksum file

**Cost**: ~15-20 minutes per release (High cost, but infrequent)

---

### docs.yml - Documentation

**Purpose**: Build and deploy documentation to GitHub Pages.

**Jobs**:
- `build-docs`: Generate API documentation and convert markdown to HTML
- `preview-pr`: Create PR preview artifacts with download link
- `deploy-docs`: Deploy to GitHub Pages (main branch only)
- `check-links`: Validate documentation links
- `validate-docs`: Check documentation completeness

**Triggers**:
- Push to `main` (when docs/, src/, or README.md change)
- Pull requests to `main` (when docs/, src/, or README.md change)
- Manual dispatch

**Features**:
- Automatic API documentation extraction from Zig source
- Markdown to HTML conversion with custom styling
- PR preview artifacts for reviewing doc changes
- Broken link detection
- Documentation completeness checks

**Pages URL**: https://[username].github.io/ananke (after deployment)

**Cost**: Low (~2-3 minutes, path-filtered)

---

### security.yml - Security Scanning

**Purpose**: Comprehensive security auditing across the entire codebase.

**Jobs**:
- `rust-security`: Rust dependency auditing with `cargo-audit` and `cargo-deny`
- `zig-security`: Scan for hardcoded secrets, unsafe patterns, and insecure dependencies
- `dependency-review`: GitHub dependency review (PRs only)
- `codeql`: CodeQL analysis for Python code
- `secret-scanning`: Gitleaks secret detection
- `license-compliance`: License compatibility checking
- `security-summary`: Aggregate all security reports

**Triggers**:
- Push to `main` or `develop`
- Pull requests to `main` or `develop`
- Weekly scheduled scan (Monday 4 AM UTC)
- Manual dispatch

**Security Checks**:
- Known CVEs in Rust dependencies
- License violations (GPL, AGPL)
- Hardcoded secrets (passwords, API keys, tokens)
- Unsafe Zig patterns (@ptrCast, unreachable, etc.)
- Insecure HTTP URLs in dependencies
- Leaked secrets in git history

**Reports**:
- Detailed markdown reports for each security domain
- SARIF uploads to GitHub Security tab
- PR comments with security summary

**Tools**:
- `cargo-audit` - Rust vulnerability database
- `cargo-deny` - Dependency policy enforcement
- `cargo-license` - License checking
- `gitleaks` - Secret scanning
- CodeQL - Static application security testing

**Cost**: Low-Medium (~5-7 minutes)

---

### benchmarks.yml - Performance Benchmarking

**Purpose**: Track performance metrics over time and detect regressions.

**Jobs**:
- `benchmark-zig`: Run Zig benchmarks (clew, braid, ffi)
- `benchmark-rust`: Run Rust Criterion benchmarks
- `compare-baseline`: Compare against historical baseline (manual runs)
- `check-regressions`: Basic regression detection
- `report`: Generate comprehensive benchmark report

**Triggers**:
- Weekly scheduled run (Sunday 3 AM UTC)
- Manual dispatch (with optional baseline comparison)
- Release tags (to capture baseline performance)

**Benchmarks**:

**Zig**:
- Clew extraction benchmarks
- Braid compilation benchmarks
- FFI bridge benchmarks

**Rust**:
- Orchestration layer performance
- Constraint compilation speed
- Cache performance

**Artifacts**:
- Benchmark results (90-day retention)
- Benchmark history (365-day retention for main branch)
- Performance comparison reports

**Performance Targets**:
| Operation | Target | Status |
|-----------|--------|--------|
| Constraint validation | <50μs | 🔄 In progress |
| Extraction | <2s (with Claude) | 🔄 In progress |
| Compilation | <50ms | 🔄 In progress |
| Generation | <5s | 🔄 In progress |

**Cost**: Medium (~10-15 minutes, weekly only)

**Future Enhancements**:
- Automated regression detection with statistical analysis
- Performance trend visualization
- Alerts for >10% regression
- Benchmark result database for historical comparison

---

## Workflow Interactions

```
┌─────────────────────────────────────────────────────────────┐
│                         Developer Push                       │
└────────────┬────────────────────────────────────────────────┘
             │
             ├──────────────┬──────────────┬──────────────┐
             ▼              ▼              ▼              ▼
        ┌─────────┐   ┌──────────┐   ┌──────────┐   ┌──────┐
        │   CI    │   │   Maze   │   │   Docs   │   │ Sec  │
        │ (Zig)   │   │  Tests   │   │  Build   │   │ Scan │
        └────┬────┘   └────┬─────┘   └────┬─────┘   └───┬──┘
             │             │              │             │
             └─────────────┴──────────────┴─────────────┘
                                 │
                                 ▼
                         ┌───────────────┐
                         │  All Checks   │
                         │    Passed?    │
                         └───────┬───────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
              ┌──────────┐             ┌───────────┐
              │  Merge   │             │   Block   │
              │   PR     │             │    PR     │
              └────┬─────┘             └───────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
  ┌─────────┐           ┌──────────┐
  │  Tagged │           │  Weekly  │
  │ Release │           │  Jobs    │
  └────┬────┘           └────┬─────┘
       │                     │
       ▼                     ▼
  ┌─────────┐         ┌─────────────┐
  │ Release │         │ Benchmarks  │
  │ Workflow│         │  Security   │
  └─────────┘         └─────────────┘
```

---

## Status Badges

Add these badges to your README.md:

```markdown
[![CI](https://github.com/[username]/ananke/actions/workflows/ci.yml/badge.svg)](https://github.com/[username]/ananke/actions/workflows/ci.yml)
[![Maze Tests](https://github.com/[username]/ananke/actions/workflows/maze-tests.yml/badge.svg)](https://github.com/[username]/ananke/actions/workflows/maze-tests.yml)
[![Security](https://github.com/[username]/ananke/actions/workflows/security.yml/badge.svg)](https://github.com/[username]/ananke/actions/workflows/security.yml)
[![Docs](https://github.com/[username]/ananke/actions/workflows/docs.yml/badge.svg)](https://github.com/[username]/ananke/actions/workflows/docs.yml)
```

---

## Cost Analysis

### Monthly GitHub Actions Minutes Estimate

**Assumptions**:
- 20 working days/month
- 10 PRs/day average
- 5 commits to main/day

| Workflow | Frequency | Duration | Monthly Minutes |
|----------|-----------|----------|-----------------|
| CI | 200 runs | 6 min | 1,200 min |
| Maze Tests | 50 runs (path filtered) | 4 min | 200 min |
| Docs | 30 runs (path filtered) | 3 min | 90 min |
| Security | 104 runs (push + weekly) | 6 min | 624 min |
| Benchmarks | 4 runs (weekly) | 12 min | 48 min |
| Release | 2 runs/month | 18 min | 36 min |
| **TOTAL** | | | **~2,198 min/month** |

**Cost Breakdown**:
- Linux minutes: ~1,800 min/month × 1× multiplier
- macOS minutes: ~300 min/month × 10× multiplier = 3,000 equivalent
- Windows minutes: ~100 min/month × 2× multiplier = 200 equivalent
- **Total equivalent Linux minutes**: ~5,000 min/month

**GitHub Free Tier**: 2,000 min/month (Linux equivalent)
**Estimated overage**: ~3,000 min/month
**Cost**: $0.008/min × 3,000 = **~$24/month**

### Cost Optimization Strategies

1. **Path Filtering**: Only run workflows when relevant files change
   - Saves ~40% on maze-tests and docs workflows

2. **Caching**: Aggressive caching of dependencies
   - Reduces build times by 60-70%
   - CI time: 15 min → 6 min

3. **Conditional Jobs**:
   - Benchmarks only weekly and on releases
   - Beta tests only on Ubuntu
   - Integration tests only after unit tests pass

4. **Artifact Retention**:
   - Build artifacts: 7 days
   - Test results: 90 days
   - Benchmarks: 90 days
   - Benchmark history: 365 days

5. **Matrix Optimization**:
   - Full OS matrix only on main CI
   - Reduced matrix on secondary workflows

---

## Troubleshooting

### Common Issues

**Issue**: Workflow fails with "Resource not accessible by integration"
**Solution**: Check workflow permissions in the YAML file. May need `write` permissions for certain operations.

**Issue**: Benchmarks show high variance
**Solution**: GitHub Actions runners have variable performance. Run benchmarks multiple times and use median values. Consider dedicated benchmark infrastructure for production.

**Issue**: Security workflow fails on GPL dependencies
**Solution**: Review `cargo-deny` configuration in `maze/deny.toml`. Either remove the dependency or add exception with justification.

**Issue**: Documentation preview not working on PRs
**Solution**: Ensure the PR is from the same repository (not a fork). Artifact downloads require authentication for fork PRs.

**Issue**: Cache not being restored
**Solution**: Check that cache keys match. Ensure `hashFiles()` patterns match actual files. Caches are scoped to branches.

### Debugging Workflows

1. **Enable debug logging**:
   ```yaml
   env:
     ACTIONS_STEP_DEBUG: true
     ACTIONS_RUNNER_DEBUG: true
   ```

2. **Use workflow_dispatch**: Most workflows support manual triggering for testing

3. **Check action versions**: Ensure all actions use stable versions (v4, not v3 or latest)

4. **Review permissions**: Many failures are permission-related

5. **Test locally**: Use [act](https://github.com/nektos/act) to test workflows locally

---

## Future Improvements

### Planned Enhancements

1. **Benchmark Dashboard**:
   - Automated performance trend visualization
   - Regression alerts (>10% slowdown)
   - Historical comparison database

2. **Documentation Preview**:
   - Deploy PR previews to temporary subdomain
   - Automatic cleanup after merge

3. **Release Automation**:
   - Automated Homebrew formula updates
   - Automated AUR package publishing
   - Release announcement posting (Discord, Twitter, etc.)

4. **Enhanced Security**:
   - SBOM (Software Bill of Materials) generation
   - Container image scanning (if added)
   - Fuzzing integration
   - Dependency update automation (Dependabot + auto-merge)

5. **Test Reporting**:
   - Visual test result dashboard
   - Flaky test detection
   - Test duration tracking
   - Coverage trend visualization

6. **Deployment**:
   - Staging environment deployments
   - Production deployment workflow
   - Rollback automation
   - Canary deployments

7. **Cost Optimization**:
   - Self-hosted runners for expensive operations
   - Spot instance usage for benchmarks
   - More aggressive caching strategies

---

## Contributing

When adding or modifying workflows:

1. **Follow naming conventions**: Use descriptive job and step names
2. **Add documentation**: Update this README with workflow details
3. **Test thoroughly**: Use workflow_dispatch to test before merging
4. **Optimize costs**: Consider frequency and duration
5. **Add caching**: Cache dependencies whenever possible
6. **Use path filters**: Only run when relevant files change
7. **Set retention**: Appropriate artifact retention periods
8. **Add permissions**: Explicit permissions following least privilege

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Pricing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

**Last Updated**: 2025-11-23
**Maintainer**: Ananke Contributors
