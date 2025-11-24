# Security Policy

## Supported Versions

We actively support the following versions of Ananke with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in Ananke, please report it responsibly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please email security reports to: **security@ananke-project.org**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if applicable)

### What to Expect

- **Acknowledgment:** Within 48 hours
- **Initial Assessment:** Within 5 business days
- **Status Updates:** Every 7 days until resolved
- **Resolution Target:** Critical issues within 30 days

### Disclosure Policy

- We will coordinate disclosure with you
- We request 90 days before public disclosure
- We will credit you in the security advisory (unless you prefer to remain anonymous)

## Security Best Practices

### API Key Management

#### DO:
- Store API keys in environment variables
- Use secure credential managers (e.g., 1Password, AWS Secrets Manager)
- Rotate API keys regularly
- Use separate API keys for development and production
- Revoke keys immediately when compromised

#### DON'T:
- Commit API keys to version control
- Share API keys in plain text
- Use the same API key across multiple environments
- Log API keys in application logs

**Example:**
```bash
# Good: Environment variable
export ANTHROPIC_API_KEY="sk-ant-..."

# Good: From secure credential manager
export ANTHROPIC_API_KEY=$(security find-generic-password -w -s "ananke-api-key")

# Bad: Hardcoded in script
ANTHROPIC_API_KEY="sk-ant-api03-..." # NEVER DO THIS
```

### Configuration Security

#### Secure Configuration File

Set restrictive permissions on configuration files:

```bash
# Create config directory
mkdir -p ~/.config/ananke

# Create config file
touch ~/.config/ananke/config.toml

# Set secure permissions (owner read/write only)
chmod 600 ~/.config/ananke/config.toml
```

#### Encrypt Sensitive Data

Use encrypted storage for sensitive configuration:

```bash
# macOS: Use Keychain
security add-generic-password \
  -a "ananke" \
  -s "anthropic-api-key" \
  -w "sk-ant-..."

# Retrieve in scripts
export ANTHROPIC_API_KEY=$(security find-generic-password \
  -a "ananke" \
  -s "anthropic-api-key" \
  -w)
```

### Network Security

#### TLS/HTTPS

Ananke uses HTTPS for all external API calls:
- Claude API: `https://api.anthropic.com`
- Modal endpoints: `https://*.modal.run`

#### Certificate Verification

Always verify TLS certificates (enabled by default):

```bash
# Verify certificate pinning is enabled
export ANANKE_VERIFY_TLS=true
```

#### Proxy Configuration

When using proxies, ensure they support TLS:

```bash
# Set HTTPS proxy
export HTTPS_PROXY="https://proxy.example.com:8080"

# DO NOT use HTTP proxies for sensitive traffic
# export HTTP_PROXY="http://proxy.example.com:8080"  # Insecure!
```

### Container Security

#### Docker Best Practices

**1. Use Official Images:**
```dockerfile
# Use official Alpine base
FROM alpine:3.19
```

**2. Run as Non-Root User:**
```dockerfile
# Create non-root user
RUN adduser -D -u 1000 ananke
USER ananke
```

**3. Scan Images for Vulnerabilities:**
```bash
# Scan with Trivy
trivy image ananke:latest

# Scan with Snyk
snyk container test ananke:latest
```

**4. Limit Container Capabilities:**
```yaml
# docker-compose.yml
services:
  ananke:
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

**5. Use Read-Only Filesystems:**
```yaml
services:
  ananke:
    volumes:
      - ./code:/workspace:ro  # Read-only
    read_only: true
```

#### Secrets in Containers

**DO:**
```bash
# Use environment variables
docker run -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY ananke:latest

# Use Docker secrets (Swarm)
docker secret create anthropic_key api_key.txt
docker service create --secret anthropic_key ananke:latest

# Use Kubernetes secrets
kubectl create secret generic ananke-secrets \
  --from-literal=anthropic-api-key=$ANTHROPIC_API_KEY
```

**DON'T:**
```dockerfile
# Never in Dockerfile
ENV ANTHROPIC_API_KEY="sk-ant-..."  # NEVER DO THIS
```

### Input Validation

Ananke validates all inputs to prevent injection attacks:

**File Paths:**
- Validated against directory traversal attacks
- Restricted to allowed directories
- Symlink resolution with safety checks

**Code Extraction:**
- Sandboxed execution for tree-sitter parsing
- No arbitrary code execution
- Resource limits enforced

**API Inputs:**
- JSON schema validation
- Size limits enforced
- Rate limiting applied

### Output Sanitization

Generated code is sanitized to prevent:
- Command injection
- SQL injection
- XSS attacks
- Path traversal

**Never execute generated code without review:**

```bash
# Bad: Direct execution
eval $(ananke generate "create script")

# Good: Review first
ananke generate "create script" > generated.sh
# Review generated.sh manually
chmod +x generated.sh
./generated.sh
```

### Data Privacy

#### Local Data Processing

By default, Ananke processes data locally:
- No data sent to external services (unless Claude is enabled)
- All extraction and compilation happens on your machine
- No telemetry or analytics collected

#### Claude Integration (Optional)

When using Claude for semantic analysis:
- Only code snippets explicitly marked for analysis are sent
- API calls use HTTPS with certificate verification
- No persistent storage of code on Anthropic servers
- Subject to [Anthropic's Privacy Policy](https://www.anthropic.com/privacy)

#### Modal Integration (Optional)

When using Modal for generation:
- Only compiled constraints and prompts are sent
- Generated code returned directly to client
- No persistent storage of prompts or outputs
- Subject to Modal's security policies

**Disable External Services:**
```bash
# Extract constraints locally only (no Claude)
ananke extract ./src --no-llm

# Compile locally only
ananke compile constraints.json --no-optimize
```

### Audit Logging

Enable audit logging for security-sensitive operations:

```bash
# Enable audit log
export ANANKE_AUDIT_LOG="$HOME/.cache/ananke/audit.log"

# Set log level
export LOG_LEVEL="info"

# Rotate logs
logrotate /etc/logrotate.d/ananke
```

**Audit log includes:**
- API calls with timestamps
- File access operations
- Constraint compilation events
- Generation requests

**Audit log excludes:**
- API keys
- Generated code content
- Source code content

### Dependency Security

#### Zig Dependencies

Ananke's Zig dependencies are minimal and vendored:
- Standard library only (no external packages)
- All dependencies reviewed before inclusion
- Automated vulnerability scanning via GitHub Dependabot

#### Rust Dependencies

Maze's Rust dependencies are regularly audited:

```bash
# Audit dependencies
cd maze
cargo audit

# Update dependencies
cargo update

# Check for outdated dependencies
cargo outdated
```

#### Container Dependencies

Container base images are regularly updated:
- Alpine Linux security updates applied
- Vulnerability scanning with Trivy/Snyk
- Automated rebuilds on security advisories

### Security Scanning

#### Static Analysis

```bash
# Zig static analysis
zig build test

# Rust static analysis
cd maze
cargo clippy -- -D warnings

# Security-focused linting
cargo clippy -- -D clippy::suspicious
```

#### Dynamic Analysis

```bash
# Run with AddressSanitizer
zig build -Doptimize=Debug -Dsanitize-thread=true

# Rust with sanitizers
cd maze
RUSTFLAGS="-Z sanitizer=address" cargo test
```

#### Vulnerability Scanning

```bash
# Scan Rust dependencies
cargo audit

# Scan container images
trivy image ananke:latest

# Scan with Snyk
snyk test
```

### Security Updates

#### Notification

Subscribe to security advisories:
- GitHub: Watch repository → Custom → Security alerts
- Email: security-announce@ananke-project.org

#### Applying Updates

```bash
# Check current version
ananke --version

# Update to latest version
curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash

# Verify update
ananke --version
```

### Compliance

Ananke follows security best practices:

- **OWASP Top 10:** Mitigations implemented
- **CWE Top 25:** Addressed in design
- **NIST Guidelines:** Followed where applicable
- **Supply Chain Security:** SLSA compliance in progress

### Known Security Considerations

#### Current Limitations

1. **Tree-sitter Parsing:** Uses C library with memory safety considerations
   - **Mitigation:** Sandboxed execution, resource limits
   - **Status:** Monitoring upstream for security issues

2. **Modal Generation:** External service dependency
   - **Mitigation:** HTTPS, input validation, no data retention
   - **Status:** Production-ready with security best practices

3. **Claude API:** External service dependency
   - **Mitigation:** Optional feature, HTTPS, Anthropic's security
   - **Status:** Production-ready with documented risks

#### Future Enhancements

- [ ] Code signing for released binaries
- [ ] SLSA Level 3 compliance
- [ ] Hardware security module (HSM) support for key storage
- [ ] Advanced audit logging with tamper detection
- [ ] Formal security audit by third party

### Security Checklist

Before deploying Ananke in production:

- [ ] API keys stored securely (not in code/config files)
- [ ] Configuration files have restrictive permissions (chmod 600)
- [ ] TLS certificate verification enabled
- [ ] Running as non-root user (containers and services)
- [ ] Audit logging enabled and monitored
- [ ] Dependencies up to date (run `cargo audit`)
- [ ] Container images scanned for vulnerabilities
- [ ] Input validation tested with edge cases
- [ ] Generated code reviewed before execution
- [ ] Security updates applied promptly

### Resources

- [OWASP Security Guidelines](https://owasp.org/)
- [Rust Security Guidelines](https://anssi-fr.github.io/rust-guide/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Zig Security](https://ziglang.org/documentation/master/#Security)

### Contact

For security concerns:
- **Email:** security@ananke-project.org
- **GitHub:** @ananke-ai/security-team
- **Response Time:** Within 48 hours

---

Last Updated: 2025-11-24
Version: 0.1.0
