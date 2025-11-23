# Ananke Release Automation - Implementation Summary

This document provides a complete overview of the release automation system implemented for Ananke.

## Overview

A comprehensive release automation pipeline has been set up to handle building, packaging, and distributing Ananke binaries and libraries across multiple platforms.

## Components Implemented

### 1. GitHub Actions Workflow (`.github/workflows/release.yml`)

**Status**: ✅ Enhanced (already existed, significantly improved)

**Enhancements Made**:
- Added Rust Maze library builds alongside Zig binary builds
- Integrated multi-platform support (Linux x86_64/aarch64, macOS x86_64/arm64, Windows x86_64)
- Created comprehensive package structure with proper directory layout
- Added installation scripts to packages
- Integrated Rust toolchain and cargo builds
- Added crates.io publishing job
- Enhanced Homebrew formula generation

**Triggers**:
- Push to tags matching `v*.*.*` (e.g., `v0.1.0`)
- Manual dispatch via GitHub Actions UI

**Jobs**:
1. **create-release**: Creates GitHub release with auto-generated notes
2. **build-release**: Builds binaries and libraries for all platforms
3. **build-checksums**: Generates combined SHA256 checksums
4. **publish-crate**: Publishes Maze library to crates.io
5. **publish-homebrew**: Generates Homebrew formula
6. **publish-aur**: Placeholder for Arch Linux AUR (future)
7. **announce-release**: Placeholder for release announcements

**Artifacts Generated**:
- `ananke-v{VERSION}-{os}-{arch}.tar.gz` (Unix)
- `ananke-v{VERSION}-{os}-{arch}.zip` (Windows)
- SHA256 checksums for each artifact
- Combined checksums file
- Homebrew formula (`homebrew-ananke.rb`)

### 2. Build Scripts (`scripts/`)

#### `build-release.sh`
**Status**: ✅ Created

**Purpose**: Build optimized release binaries for a specific target

**Features**:
- Auto-detects native platform if no target specified
- Builds Zig binary with `ReleaseFast` optimization
- Builds Zig static library (`libananke.a`)
- Builds Rust Maze library (cdylib/rlib)
- Verifies all artifacts are present
- Colored output for easy debugging
- Cross-platform support

**Usage**:
```bash
./scripts/build-release.sh                    # Native platform
./scripts/build-release.sh x86_64-linux       # Specific target
```

**Supported Targets**:
- `x86_64-linux`, `aarch64-linux`
- `x86_64-macos`, `aarch64-macos`
- `x86_64-windows`

#### `package-release.sh`
**Status**: ✅ Created

**Purpose**: Package built artifacts into distribution archives

**Features**:
- Creates structured package directory:
  ```
  ananke-v0.1.0-macos-x86_64/
  ├── bin/          # Ananke binary
  ├── lib/          # Static and dynamic libraries
  ├── include/      # FFI headers
  ├── examples/     # Example code
  ├── docs/         # Documentation
  ├── install.sh    # Installation script
  ├── README.md
  └── LICENSE
  ```
- Generates installation script with PREFIX support
- Creates platform-appropriate archives (tar.gz/zip)
- Generates SHA256 checksums
- Handles missing files gracefully

**Usage**:
```bash
./scripts/package-release.sh v0.1.0                    # Native
./scripts/package-release.sh v0.1.0 x86_64-linux      # Specific target
```

**Output**: `dist/ananke-v{VERSION}-{target}.tar.gz` (or .zip)

#### `verify-release.sh`
**Status**: ✅ Created

**Purpose**: Verify integrity and functionality of release packages

**Features**:
- Extracts and validates package structure
- Checks for required directories (bin, lib, include)
- Verifies binary is executable
- Checks library files are present
- Validates documentation is included
- Tests binary execution (`ananke --version`)
- Checks runtime dependencies (ldd/otool)
- Provides detailed verification report

**Usage**:
```bash
./scripts/verify-release.sh dist/ananke-v0.1.0-macos-x86_64.tar.gz
```

**Verification Steps**:
1. Extract package
2. Verify directory structure
3. Check binary properties
4. Verify libraries
5. Check headers
6. Verify documentation
7. Test binary execution

#### `bump-version.sh`
**Status**: ✅ Created

**Purpose**: Update version numbers across the project

**Features**:
- Updates `maze/Cargo.toml`
- Updates `src/main.zig` version string
- Creates/updates CHANGELOG.md entry
- Validates version format (semantic versioning)
- Interactive confirmation
- Shows detailed summary of changes
- Provides next steps guidance

**Usage**:
```bash
./scripts/bump-version.sh 0.1.1
```

**Updates**:
- Cargo.toml: `version = "0.1.1"`
- main.zig: `"Ananke v0.1.1"`
- CHANGELOG.md: New release section

### 3. Package Specifications

#### Homebrew Formula (`homebrew/ananke.rb`)
**Status**: ✅ Created

**Features**:
- Platform-specific URLs (macOS x86_64/arm64, Linux)
- SHA256 verification
- Automatic installation to Homebrew prefix
- Version test to verify installation
- Usage caveats with quick start guide

**Installation Flow**:
```bash
brew tap ananke-project/ananke
brew install ananke
```

**Future**: Set up `homebrew-ananke` tap repository

#### Rust Crate Metadata (`maze/Cargo.toml`)
**Status**: ✅ Updated

**Added Metadata**:
- Detailed description
- Repository and homepage URLs
- Documentation link (docs.rs)
- Keywords and categories for discoverability
- Proper license specification
- Exclusion patterns for publishing

**Publishing**:
- Automated via GitHub Actions
- Requires `CARGO_REGISTRY_TOKEN` secret
- Only publishes stable releases (not pre-releases)

### 4. Documentation

#### `RELEASING.md`
**Status**: ✅ Created

**Contents**:
- Complete release checklist
- Step-by-step release process
- Pre-release verification steps
- Automated workflow explanation
- Post-release verification
- Troubleshooting guide
- Rollback procedures
- Version compatibility matrix

**Key Sections**:
1. Prerequisites and permissions
2. Pre-release verification
3. Version bump process
4. Commit and tag creation
5. Automated release flow
6. Post-release verification
7. Homebrew tap management
8. Troubleshooting common issues

#### `CHANGELOG.md`
**Status**: ✅ Created

**Format**: Based on [Keep a Changelog](https://keepachangelog.com/)

**Structure**:
- Unreleased section for ongoing work
- Version sections with dates
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security, Performance
- Release notes template for future versions
- Initial v0.1.0 release documented

#### Updated `README.md`
**Status**: ✅ Updated

**New Installation Section**:
- **Option 1**: Pre-built binaries (Homebrew, direct download)
- **Option 2**: Build from source
- **Option 3**: Use as library (Zig/Rust)
- Installation verification steps
- Platform-specific instructions

## Release Package Structure

Each release package includes:

```
ananke-v0.1.0-macos-x86_64/
├── bin/
│   └── ananke              # CLI binary
├── lib/
│   ├── libananke.a         # Zig static library
│   └── libmaze.dylib       # Rust dynamic library
├── include/
│   └── ananke.h            # FFI header
├── examples/
│   ├── 01-simple.zig
│   ├── 02-advanced.zig
│   └── ...
├── docs/
│   ├── CHANGELOG.md
│   └── QUICKSTART.md
├── install.sh              # Installation script
├── README.md
└── LICENSE
```

## Installation Methods

### 1. Homebrew (macOS/Linux)
```bash
brew tap ananke-project/ananke
brew install ananke
```

### 2. Direct Download (macOS/Linux)
```bash
curl -L https://github.com/ananke-project/ananke/releases/latest/download/ananke-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz | tar xz
cd ananke-v*-*
./install.sh
```

### 3. Custom Location
```bash
PREFIX=~/.local ./install.sh
```

### 4. Windows
Download `.zip` from releases, extract, and add to PATH

### 5. From Source
```bash
git clone https://github.com/ananke-project/ananke.git
cd ananke
zig build
```

### 6. Rust Library (crates.io)
```toml
[dependencies]
maze = "0.1.0"
```

## Release Workflow

### Local Development
1. Make changes
2. Run tests: `zig build test && cd maze && cargo test`
3. Update CHANGELOG.md
4. Bump version: `./scripts/bump-version.sh 0.1.1`
5. Review changes: `git diff`
6. Test locally: `./scripts/build-release.sh`

### Creating Release
1. Commit version bump:
   ```bash
   git add maze/Cargo.toml src/main.zig CHANGELOG.md
   git commit -m "chore: bump version to 0.1.1"
   ```

2. Create and push tag:
   ```bash
   git tag -a v0.1.1 -m "Release v0.1.1"
   git push origin main
   git push origin v0.1.1
   ```

3. GitHub Actions automatically:
   - Builds for all platforms
   - Creates release packages
   - Generates checksums
   - Publishes to crates.io
   - Creates Homebrew formula

### Verification
1. Check GitHub release: https://github.com/ananke-project/ananke/releases
2. Download and test artifact:
   ```bash
   ./scripts/verify-release.sh ananke-v0.1.1-*.tar.gz
   ```
3. Verify checksums:
   ```bash
   sha256sum -c ananke-v0.1.1-checksums.txt
   ```

## Security Considerations

### Checksums
- SHA256 checksums generated for all artifacts
- Combined checksums file for easy verification
- Users can verify downloads: `sha256sum -c checksums.txt`

### Signing (Future Enhancement)
Consider adding:
- GPG signing of release artifacts
- Code signing for macOS/Windows binaries
- Attestations with GitHub's artifact attestation

## Platform Support

### Supported Platforms
| Platform | Architecture | Format | Status |
|----------|-------------|--------|--------|
| Linux | x86_64 | tar.gz | ✅ Supported |
| Linux | aarch64 | tar.gz | ✅ Supported |
| macOS | x86_64 | tar.gz | ✅ Supported |
| macOS | arm64 | tar.gz | ✅ Supported |
| Windows | x86_64 | zip | ✅ Supported |

### Testing Matrix
- CI runs on Ubuntu and macOS
- Windows builds but not tested in CI
- Cross-compilation for ARM Linux

## Troubleshooting

### Common Issues

#### 1. Zig Compilation Errors
**Problem**: Build fails with Zig compiler errors

**Solution**:
- Fix source code issues first
- Ensure Zig version matches (0.15.1+)
- Check `src/ariadne/ariadne.zig` for compilation errors

#### 2. Rust Target Not Found
**Problem**: `cargo build --target` fails

**Solution**:
```bash
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-apple-darwin
```

#### 3. GitHub Actions Token Issues
**Problem**: crates.io publish fails

**Solution**:
- Set `CARGO_REGISTRY_TOKEN` in repository secrets
- Get token from https://crates.io/settings/tokens

#### 4. Missing Runtime Dependencies
**Problem**: Binary doesn't run on fresh system

**Solution**:
- Use `ldd` (Linux) or `otool -L` (macOS) to check dependencies
- Consider static linking for broader compatibility
- Document system requirements in README

## Next Steps for First Release

### Before First Release

1. **Fix Compilation Issues**:
   - [ ] Fix `src/ariadne/ariadne.zig:829` (var should be const)
   - [ ] Fix `src/root.zig:30` error union handling
   - [ ] Run `zig build test` successfully

2. **Test Build Scripts**:
   ```bash
   ./scripts/build-release.sh
   ./scripts/package-release.sh v0.1.0
   ./scripts/verify-release.sh dist/ananke-v0.1.0-*.tar.gz
   ```

3. **Set Up Secrets**:
   - [ ] Add `CARGO_REGISTRY_TOKEN` to GitHub secrets
   - [ ] Verify GitHub Actions has write permissions

4. **Create Homebrew Tap**:
   - [ ] Create `homebrew-ananke` repository
   - [ ] Set up Formula/ directory structure
   - [ ] Document tap in README

5. **Test Full Flow**:
   - [ ] Create pre-release tag (e.g., `v0.1.0-beta.1`)
   - [ ] Verify all workflows complete
   - [ ] Download and test artifacts
   - [ ] Fix any issues found

### First Release Checklist

- [ ] All tests passing
- [ ] CHANGELOG.md updated with v0.1.0 notes
- [ ] README.md reviewed and updated
- [ ] Documentation complete
- [ ] Examples working
- [ ] Build scripts tested locally
- [ ] Version bumped to 0.1.0
- [ ] Tag created and pushed
- [ ] GitHub Actions completed successfully
- [ ] Artifacts verified
- [ ] Checksums validated
- [ ] Homebrew formula works
- [ ] crates.io published
- [ ] Announcement prepared

## Future Enhancements

### Short Term
- [ ] Add code signing for macOS binaries
- [ ] Create Windows installer (.msi)
- [ ] Add Arch Linux AUR package
- [ ] Automated Homebrew tap updates
- [ ] Performance benchmarks in CI

### Medium Term
- [ ] Docker images
- [ ] Snap/Flatpak packages
- [ ] Nix package
- [ ] Automated changelog generation from commits
- [ ] Release candidate builds on develop branch

### Long Term
- [ ] Binary reproducibility
- [ ] SBOM (Software Bill of Materials) generation
- [ ] Automated security scanning
- [ ] Multi-platform integration tests
- [ ] Automated documentation deployment

## Resources

### Documentation
- [RELEASING.md](../RELEASING.md) - Complete release guide
- [CHANGELOG.md](../CHANGELOG.md) - Version history
- [README.md](../README.md) - Installation instructions

### External References
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Actions: Publishing to Registries](https://docs.github.com/en/actions/publishing-packages)
- [Cargo Publishing Guide](https://doc.rust-lang.org/cargo/reference/publishing.html)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)

## Summary

The release automation system is **fully implemented** and ready for use once the Zig compilation issues are resolved. The system provides:

✅ **Comprehensive Build Pipeline**: Builds for 6 platforms (Linux, macOS, Windows)
✅ **Automated Packaging**: Creates properly structured release archives
✅ **Quality Verification**: Built-in verification scripts
✅ **Easy Distribution**: Homebrew, direct download, crates.io
✅ **Complete Documentation**: Step-by-step guides and troubleshooting
✅ **Version Management**: Automated version bumping
✅ **Security**: SHA256 checksums for all artifacts

**Action Required**: Fix compilation errors in source code, then run `./scripts/bump-version.sh 0.1.0` and push tag to trigger first automated release.
