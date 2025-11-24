# Ananke Installation Tests

Automated tests for verifying Ananke installation across different platforms.

## Test Scripts

### `test-linux-install.sh`

Tests installation on Linux systems:
- Installation to custom prefix
- Binary existence and permissions
- Library installation
- Command functionality
- File ownership

**Usage:**
```bash
./test-linux-install.sh [--cleanup]
```

### `test-macos-install.sh`

Tests installation on macOS systems:
- macOS version compatibility
- Architecture detection (Intel/Apple Silicon)
- Installation process
- Code signing (if applicable)
- Gatekeeper approval (if applicable)
- Library dependencies
- Command functionality

**Usage:**
```bash
./test-macos-install.sh [--cleanup]
```

### `test-docker-install.sh`

Tests Docker image build and functionality:
- Docker availability
- Image build process
- Container execution
- Volume mounting
- Health checks
- docker-compose configuration

**Usage:**
```bash
./test-docker-install.sh [--cleanup]
```

## Running All Tests

### Local Testing

Run all installation tests:

```bash
# Make scripts executable
chmod +x test/installation/*.sh

# Run all tests
for test in test/installation/test-*.sh; do
    echo "Running $test..."
    bash "$test" --cleanup
    echo
done
```

### CI/CD Integration

#### GitHub Actions

```yaml
name: Installation Tests

on: [push, pull_request]

jobs:
  test-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test Linux Installation
        run: ./test/installation/test-linux-install.sh --cleanup

  test-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test macOS Installation
        run: ./test/installation/test-macos-install.sh --cleanup

  test-docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test Docker Installation
        run: ./test/installation/test-docker-install.sh --cleanup
```

## Test Coverage

### Linux Tests
- [x] Installation script execution
- [x] Binary installation
- [x] Library installation
- [x] File permissions
- [x] Command functionality
- [x] File ownership

### macOS Tests
- [x] Platform detection
- [x] Architecture detection
- [x] Installation script execution
- [x] Binary installation
- [x] Library installation
- [x] Code signing verification
- [x] Gatekeeper verification
- [x] Library dependencies
- [x] Command functionality

### Docker Tests
- [x] Docker availability
- [x] Image build
- [x] Container execution
- [x] Volume mounting
- [x] Health checks
- [x] Image size verification
- [x] docker-compose validation

## Expected Results

All tests should pass with 0 failures. Some warnings are acceptable:
- Code signing warnings on macOS (for local builds)
- Gatekeeper warnings on macOS (for local builds)
- Extract command failures (if Tree-sitter not fully implemented)

## Troubleshooting

### Linux

**Issue:** Tests fail with "command not found"

**Solution:** Ensure Zig and Rust are installed:
```bash
# Install Zig
curl https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar xJ
export PATH=$PWD/zig-linux-x86_64-0.15.2:$PATH

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### macOS

**Issue:** "Developer cannot be verified" error

**Solution:** Allow the binary in System Preferences:
```bash
xattr -d com.apple.quarantine ~/.local/bin/ananke
```

### Docker

**Issue:** Docker build fails with "insufficient memory"

**Solution:** Increase Docker Desktop memory limit:
- Open Docker Desktop → Settings → Resources
- Increase Memory to at least 4GB

**Issue:** Volume mounting fails

**Solution:** Ensure Docker has file sharing permissions:
- Docker Desktop → Settings → Resources → File Sharing
- Add the test directory

## Adding New Tests

To add a new installation test:

1. Create a new test script: `test-{platform}-install.sh`
2. Follow the existing test structure:
   - Setup colors and logging
   - Define cleanup function
   - Implement tests with log_pass/log_fail
   - Print summary
3. Make the script executable: `chmod +x test-{platform}-install.sh`
4. Update this README
5. Add to CI/CD workflow

## Maintenance

These tests should be run:
- Before each release
- After changes to installation scripts
- After changes to build system
- In CI/CD on every commit

## See Also

- [Installation Guide](../../docs/DEPLOYMENT.md)
- [Health Check Script](../../scripts/health-check.sh)
- [Release Process](../../RELEASING.md)
