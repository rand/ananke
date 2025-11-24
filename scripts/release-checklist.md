# Release Checklist for v0.1.0

Use this checklist for releasing Ananke versions.

## Pre-Release (1-2 weeks before)

### Code Quality
- [ ] All tests passing (Zig + Rust)
  ```bash
  zig build test
  cd maze && cargo test && cd ..
  ```
- [ ] Benchmarks run successfully
  ```bash
  zig build bench-zig
  cd maze && cargo bench && cd ..
  ```
- [ ] No compiler warnings
  ```bash
  zig build -Doptimize=ReleaseSafe 2>&1 | grep -i warning
  cd maze && cargo clippy -- -D warnings && cd ..
  ```
- [ ] Security audit passes
  ```bash
  cd maze && cargo audit && cd ..
  ```
- [ ] Code coverage meets minimum (70%+)
- [ ] Static analysis passes
  ```bash
  cd maze && cargo clippy && cd ..
  ```

### Documentation
- [ ] CHANGELOG.md updated with all changes
- [ ] Version bumped in build.zig
- [ ] Version bumped in maze/Cargo.toml
- [ ] README.md reflects current features
- [ ] QUICKSTART.md tested and accurate
- [ ] API documentation up to date
- [ ] Example code tested and working
- [ ] Migration guide written (if breaking changes)

### Testing
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All e2e tests pass
- [ ] Performance tests meet targets
- [ ] Manual smoke tests completed
- [ ] Installation scripts tested on:
  - [ ] Linux (Ubuntu/Debian)
  - [ ] Linux (Fedora/RHEL)
  - [ ] macOS Intel
  - [ ] macOS Apple Silicon
  - [ ] Windows 10/11
- [ ] Docker build and run tested
- [ ] Health check script passes

### Infrastructure
- [ ] CI/CD pipelines all green
- [ ] GitHub Actions workflows validated
- [ ] Modal inference service deployed and tested
- [ ] Release automation scripts tested
- [ ] Backup infrastructure verified

## Release Day

### Version Control
- [ ] Create release branch: `release/v0.1.0`
  ```bash
  git checkout -b release/v0.1.0
  ```
- [ ] Final version bump
  ```bash
  ./scripts/bump-version.sh 0.1.0
  ```
- [ ] Commit version changes
  ```bash
  git add build.zig maze/Cargo.toml CHANGELOG.md
  git commit -m "chore: bump version to v0.1.0"
  ```
- [ ] Push release branch
  ```bash
  git push origin release/v0.1.0
  ```

### Build Artifacts
- [ ] Build release binaries for all platforms
  ```bash
  ./scripts/build-release.sh x86_64-linux
  ./scripts/build-release.sh aarch64-linux
  ./scripts/build-release.sh x86_64-macos
  ./scripts/build-release.sh aarch64-macos
  ./scripts/build-release.sh x86_64-windows
  ```
- [ ] Package release artifacts
  ```bash
  ./scripts/package-release.sh v0.1.0
  ```
- [ ] Generate checksums
  ```bash
  find dist/ -type f -name "*.tar.gz" -o -name "*.zip" | xargs sha256sum > checksums.txt
  ```
- [ ] Sign release artifacts (if applicable)
- [ ] Verify all artifacts
  ```bash
  ./scripts/verify-release.sh v0.1.0
  ```

### Git Tagging
- [ ] Create annotated tag
  ```bash
  git tag -a v0.1.0 -m "Release v0.1.0: Initial public release"
  ```
- [ ] Push tag to trigger release workflow
  ```bash
  git push origin v0.1.0
  ```
- [ ] Verify GitHub Actions release workflow starts

### GitHub Release
- [ ] Wait for automated release to complete
- [ ] Verify all release assets uploaded:
  - [ ] ananke-v0.1.0-linux-x86_64.tar.gz
  - [ ] ananke-v0.1.0-linux-aarch64.tar.gz
  - [ ] ananke-v0.1.0-macos-x86_64.tar.gz
  - [ ] ananke-v0.1.0-macos-aarch64.tar.gz
  - [ ] ananke-v0.1.0-windows-x86_64.zip
  - [ ] ananke-v0.1.0-checksums.txt
  - [ ] homebrew-ananke.rb
- [ ] Edit release notes:
  - Add highlights
  - Add breaking changes
  - Add migration instructions
  - Add known issues
- [ ] Change from draft to published
- [ ] Verify release is live

### Distribution
- [ ] Publish Maze to crates.io
  ```bash
  cd maze
  cargo publish --allow-dirty
  cd ..
  ```
- [ ] Update Homebrew tap (if ready)
  ```bash
  # Clone tap repository
  git clone https://github.com/ananke-ai/homebrew-ananke.git
  cd homebrew-ananke

  # Update formula
  cp ../homebrew-ananke.rb Formula/ananke.rb

  # Update checksums
  # Edit Formula/ananke.rb with actual SHA256 values

  # Commit and push
  git add Formula/ananke.rb
  git commit -m "Update Ananke to v0.1.0"
  git push origin main
  ```
- [ ] Push Docker image to GitHub Container Registry
  ```bash
  docker build -t ghcr.io/ananke-ai/ananke:0.1.0 .
  docker tag ghcr.io/ananke-ai/ananke:0.1.0 ghcr.io/ananke-ai/ananke:latest
  docker push ghcr.io/ananke-ai/ananke:0.1.0
  docker push ghcr.io/ananke-ai/ananke:latest
  ```
- [ ] Update AUR package (if ready)

### Verification
- [ ] Test installation from all methods:
  - [ ] Quick install script (Linux)
    ```bash
    curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
    ```
  - [ ] Quick install script (macOS)
  - [ ] Quick install script (Windows)
  - [ ] Docker pull and run
    ```bash
    docker pull ghcr.io/ananke-ai/ananke:0.1.0
    docker run --rm ghcr.io/ananke-ai/ananke:0.1.0 --version
    ```
  - [ ] Homebrew (if ready)
    ```bash
    brew install ananke-ai/ananke/ananke
    ```
  - [ ] From source
    ```bash
    git clone https://github.com/ananke-ai/ananke.git
    cd ananke
    git checkout v0.1.0
    zig build -Doptimize=ReleaseSafe
    ```
- [ ] Run health check on fresh installation
  ```bash
  ./scripts/health-check.sh --verbose
  ```
- [ ] Test basic workflows:
  - [ ] Extract constraints
  - [ ] Compile constraints
  - [ ] Generate code (if Modal endpoint available)

## Post-Release

### Documentation Updates
- [ ] Update main branch with release branch changes
  ```bash
  git checkout main
  git merge release/v0.1.0
  git push origin main
  ```
- [ ] Update documentation website (if applicable)
- [ ] Update installation instructions
- [ ] Create blog post/announcement (if applicable)

### Communication
- [ ] Announce on GitHub Discussions
- [ ] Post to relevant communities:
  - [ ] Reddit (r/programming, r/rust, r/zig)
  - [ ] Hacker News
  - [ ] Twitter/X
  - [ ] Discord/Slack communities
- [ ] Send email to mailing list (if exists)
- [ ] Update project homepage

### Monitoring
- [ ] Monitor GitHub issues for installation problems
- [ ] Check download statistics
- [ ] Monitor error reports
- [ ] Track social media feedback
- [ ] Watch for security reports

### Cleanup
- [ ] Delete release branch (or keep for LTS)
  ```bash
  git branch -d release/v0.1.0
  git push origin --delete release/v0.1.0
  ```
- [ ] Archive build artifacts
- [ ] Update project board/roadmap
- [ ] Schedule next release planning meeting

## Rollback Procedure (If Needed)

If critical issues are discovered:

1. **Immediate:**
   - [ ] Mark release as pre-release in GitHub
   - [ ] Post warning on all channels
   - [ ] Document the issue

2. **Short-term:**
   - [ ] Prepare hotfix
   - [ ] Test hotfix thoroughly
   - [ ] Release v0.1.1 with fix

3. **If hotfix not possible:**
   - [ ] Yank release from GitHub
   - [ ] Remove from package managers
   - [ ] Revert to previous stable version

## Platform-Specific Verification

### Linux
- [ ] Ubuntu 22.04 LTS
- [ ] Ubuntu 24.04 LTS
- [ ] Debian 12
- [ ] Fedora 39
- [ ] RHEL 9
- [ ] Arch Linux

### macOS
- [ ] macOS 13 Ventura (Intel)
- [ ] macOS 14 Sonoma (Intel)
- [ ] macOS 14 Sonoma (Apple Silicon)
- [ ] macOS 15 Sequoia (Apple Silicon)

### Windows
- [ ] Windows 10 (21H2+)
- [ ] Windows 11
- [ ] Windows Server 2022

### Containers
- [ ] Docker on Linux
- [ ] Docker on macOS
- [ ] Docker on Windows
- [ ] Kubernetes deployment
- [ ] Podman compatibility

## Success Criteria

Release is successful if:
- [ ] All installation methods work
- [ ] No critical bugs reported in first 48 hours
- [ ] Health check passes on all platforms
- [ ] Documentation is accurate
- [ ] Community feedback is positive
- [ ] Download metrics meet expectations

## Post-Mortem (1 week after)

- [ ] Review what went well
- [ ] Document issues encountered
- [ ] Update release process
- [ ] Plan improvements for next release
- [ ] Thank contributors

---

## Notes

- Keep this checklist updated with lessons learned
- Automate as much as possible
- Test early, test often
- Communicate clearly with users
- Have rollback plan ready

## Related Documents

- [RELEASING.md](../RELEASING.md)
- [DEPLOYMENT.md](../docs/DEPLOYMENT.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [CHANGELOG.md](../CHANGELOG.md)
