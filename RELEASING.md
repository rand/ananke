# Release Process

This document describes how to create a new release of Ananke.

## Prerequisites

1. **Permissions**
   - Write access to the repository
   - Permission to create tags and releases
   - `CARGO_REGISTRY_TOKEN` secret configured in GitHub Actions (for crates.io publishing)

2. **Tools**
   - Git
   - Zig 0.15.1 or later
   - Rust toolchain (stable)
   - GitHub CLI (`gh`) - optional but recommended

## Release Checklist

### 1. Pre-Release Verification

Before starting the release process:

- [ ] All CI checks passing on main branch
- [ ] All tests passing locally
- [ ] Documentation is up to date
- [ ] CHANGELOG.md has been updated with release notes
- [ ] Breaking changes are clearly documented
- [ ] Examples work correctly

```bash
# Run full test suite
zig build test
cd maze && cargo test --all

# Run benchmarks to check for performance regressions
zig build bench-zig
cd maze && cargo bench

# Build and test release artifacts locally
./scripts/build-release.sh
./scripts/package-release.sh v0.1.0
./scripts/verify-release.sh dist/ananke-v0.1.0-*.tar.gz
```

### 2. Version Bump

Use the version bump script to update version numbers across the project:

```bash
./scripts/bump-version.sh 0.1.1
```

This will:
- Update `maze/Cargo.toml`
- Update `src/main.zig`
- Create/update CHANGELOG.md entry

**Manual Steps:**
1. Review the changes: `git diff`
2. Edit CHANGELOG.md to add meaningful release notes
3. Build and test with new version: `zig build && ./zig-out/bin/ananke --version`

### 3. Commit and Tag

```bash
# Stage changes
git add maze/Cargo.toml src/main.zig CHANGELOG.md

# Commit with conventional commit message
git commit -m "chore: bump version to 0.1.1"

# Create annotated tag
git tag -a v0.1.1 -m "Release v0.1.1"

# Push to remote
git push origin main
git push origin v0.1.1
```

### 4. Automated Release Process

When you push a tag matching `v*.*.*`, GitHub Actions will automatically:

1. **Create Release** - Draft release with auto-generated notes
2. **Build Binaries** - Build for all supported platforms:
   - Linux (x86_64, aarch64)
   - macOS (x86_64, aarch64/Apple Silicon)
   - Windows (x86_64)
3. **Build Libraries** - Build Rust Maze library for all platforms
4. **Package** - Create distribution archives with:
   - Binaries
   - Libraries (static and dynamic)
   - Headers
   - Examples
   - Documentation
   - Installation script
5. **Generate Checksums** - SHA256 checksums for all artifacts
6. **Publish to crates.io** - Publish Maze library (stable releases only)
7. **Generate Homebrew Formula** - Create formula for macOS/Linux installation

### 5. Post-Release Verification

After the automated workflow completes:

1. **Verify GitHub Release**
   ```bash
   # View release
   gh release view v0.1.1

   # Download and test an artifact
   gh release download v0.1.1 -p "ananke-v0.1.1-macos-x86_64.tar.gz"
   tar -xzf ananke-v0.1.1-macos-x86_64.tar.gz
   cd ananke-v0.1.1-macos-x86_64
   ./bin/ananke --version
   ```

2. **Verify Checksums**
   ```bash
   # Download checksums file
   gh release download v0.1.1 -p "*-checksums.txt"

   # Verify
   sha256sum -c ananke-v0.1.1-checksums.txt
   ```

3. **Verify crates.io** (if published)
   ```bash
   cargo search maze
   # Should show new version

   # Test installation
   cargo install maze --version 0.1.1
   ```

4. **Test Installation Methods**

   **Binary (macOS/Linux):**
   ```bash
   curl -L https://github.com/ananke-project/ananke/releases/download/v0.1.1/ananke-v0.1.1-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz | tar xz
   cd ananke-v0.1.1-*
   ./install.sh
   ananke --version
   ```

   **Homebrew** (after tap is set up):
   ```bash
   brew tap ananke-project/ananke
   brew install ananke
   ananke --version
   ```

### 6. Update Homebrew Tap (Manual)

After the first release, set up a Homebrew tap:

1. Create repository: `github.com/ananke-project/homebrew-ananke`

2. Add the generated formula:
   ```bash
   # Download formula from release assets
   gh release download v0.1.1 -p "homebrew-ananke.rb"

   # Copy to tap repository
   mkdir -p Formula
   cp homebrew-ananke.rb Formula/ananke.rb

   # Commit and push
   git add Formula/ananke.rb
   git commit -m "ananke 0.1.1"
   git push
   ```

3. Test installation:
   ```bash
   brew tap ananke-project/ananke
   brew install ananke
   ```

For subsequent releases, the formula can be updated automatically or manually.

### 7. Announce Release

After verification:

1. **Update Documentation Site** (if applicable)
2. **Social Media Announcements**
   - Twitter/X
   - Reddit (r/rust, r/programming)
   - Hacker News
3. **Community Notifications**
   - Discord server
   - Mailing list
4. **Blog Post** (for major releases)

## Release Types

### Stable Release (e.g., v1.0.0)
- Full automated workflow
- Published to crates.io
- Homebrew formula generated
- Widely announced

### Pre-Release (e.g., v1.0.0-beta.1)
- Full automated workflow
- **NOT** published to crates.io
- Marked as pre-release on GitHub
- Limited announcement (testers/early adopters)

### Patch Release (e.g., v1.0.1)
- Same as stable release
- Focus on bug fixes
- Update CHANGELOG with fixes

## Troubleshooting

### Build Failures

**Problem**: GitHub Actions build fails

**Solutions**:
1. Check CI logs in GitHub Actions tab
2. Test locally: `./scripts/build-release.sh <target>`
3. Common issues:
   - Zig version mismatch
   - Rust target not installed
   - Cross-compilation dependencies missing

### Publishing Failures

**Problem**: crates.io publish fails

**Solutions**:
1. Check if version already published: `cargo search maze`
2. Verify `CARGO_REGISTRY_TOKEN` secret is set
3. Check crates.io status page
4. Manual publish: `cd maze && cargo publish`

### Missing Artifacts

**Problem**: Some release artifacts missing

**Solutions**:
1. Re-run failed workflow jobs in GitHub Actions
2. Manual upload:
   ```bash
   # Build locally
   ./scripts/build-release.sh x86_64-macos
   ./scripts/package-release.sh v0.1.1 x86_64-macos

   # Upload to release
   gh release upload v0.1.1 dist/ananke-v0.1.1-macos-x86_64.tar.gz
   ```

### Checksum Mismatches

**Problem**: Downloaded artifact checksum doesn't match

**Solutions**:
1. Re-download artifact
2. Verify GitHub Actions completed successfully
3. Check if artifact was tampered with
4. Regenerate checksums:
   ```bash
   sha256sum ananke-v0.1.1-*.tar.gz > checksums.txt
   gh release upload v0.1.1 checksums.txt --clobber
   ```

## Rollback Procedure

If critical issues are found after release:

### Option 1: Patch Release (Recommended)
1. Fix issue in a hotfix branch
2. Follow release process for patch version (e.g., v1.0.1)
3. Update release notes explaining the fix

### Option 2: Delete Release (Last Resort)
```bash
# Delete GitHub release
gh release delete v1.0.0 --yes

# Delete tag
git push --delete origin v1.0.0
git tag -d v1.0.0

# If published to crates.io: yank version
cargo yank --version 1.0.0
```

**Note**: Yanking from crates.io doesn't delete the version, just marks it as unsuitable for new projects.

## Version Compatibility Matrix

Track compatibility between Ananke components:

| Ananke Version | Zig Version | Rust Edition | Maze Library | Modal Endpoint |
|----------------|-------------|--------------|--------------|----------------|
| 0.1.0          | 0.15.1+     | 2021         | 0.1.0        | v1             |
| 0.2.0          | 0.15.1+     | 2021         | 0.2.0        | v1             |

## Automation Improvements

Future enhancements to consider:

- [ ] Automated CHANGELOG generation from conventional commits
- [ ] Automated Homebrew tap updates
- [ ] Automated documentation deployment
- [ ] Release candidate builds on `develop` branch
- [ ] Performance regression detection
- [ ] Automated security scanning of release artifacts
- [ ] Docker image publishing
- [ ] Snap/Flatpak packaging
- [ ] Checksums in multiple formats (SHA512, GPG signatures)

## Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [crates.io Publishing Guide](https://doc.rust-lang.org/cargo/reference/publishing.html)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
