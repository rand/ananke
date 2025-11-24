# Support

## Getting Help

We're here to help you get the most out of Ananke. Here's how to find answers and get support.

## Documentation

Start with our comprehensive documentation:

- **[README.md](../README.md)** - Project overview, quickstart, and key concepts
- **[QUICKSTART.md](../QUICKSTART.md)** - Get up and running in 10 minutes
- **[USER_GUIDE.md](USER_GUIDE.md)** - Comprehensive user guide with patterns and workflows
- **[CLI_GUIDE.md](CLI_GUIDE.md)** - Complete CLI reference and examples
- **[API_DOCUMENTATION_REPORT.md](API_DOCUMENTATION_REPORT.md)** - API overview
- **[API_REFERENCE_ZIG.md](API_REFERENCE_ZIG.md)** - Zig library API documentation
- **[API_REFERENCE_RUST.md](API_REFERENCE_RUST.md)** - Rust library API documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and architecture
- **[FAQ.md](FAQ.md)** - Frequently asked questions

## Community Support

### GitHub Discussions

Ask questions and discuss features in [GitHub Discussions](https://github.com/ananke-ai/ananke/discussions).

Use this for:
- General questions about Ananke
- Help with integration
- Feature ideas and discussions
- Best practices and patterns

### GitHub Issues

Report bugs and request features using [GitHub Issues](https://github.com/ananke-ai/ananke/issues).

Use this for:
- Bug reports (use [bug report template](.github/ISSUE_TEMPLATE/bug_report.md))
- Feature requests (use [feature request template](.github/ISSUE_TEMPLATE/feature_request.md))
- Questions about specific functionality (use [question template](.github/ISSUE_TEMPLATE/question.md))

### Email Support

For private inquiries or sensitive issues:
- Security issues: security@ananke-ai.dev
- General inquiries: support@ananke-ai.dev

## Common Questions

### Installation & Setup

**Q: How do I install Ananke?**
A: See [Installation section](../README.md#installation) in README or [QUICKSTART.md](../QUICKSTART.md).

**Q: What are the system requirements?**
A: See [Prerequisites](../README.md#prerequisites) - you need Zig 0.15.2+ and Rust 1.70+ for development.

**Q: Can I use Ananke on Windows?**
A: Yes! Ananke works on Windows, macOS, and Linux. Pre-built binaries are available.

### Usage

**Q: When should I use Claude API vs inference server?**
A:
- **Claude API**: Constraint extraction and analysis (no GPU needed)
- **Inference server**: Token-level constrained generation (requires GPU)

See [When to Use Claude API vs Inference Server](../README.md#when-to-use-claude-api-vs-inference-server) for details.

**Q: How do I extract constraints from my code?**
A: See [Constraint Extraction](USER_GUIDE.md) in the user guide and [QUICKSTART.md](../QUICKSTART.md) examples.

**Q: What's the difference between Clew, Braid, and Maze?**
A: See [Architecture at a Glance](../README.md#architecture-at-a-glance) in README:
- **Clew**: Extracts constraints from code, tests, and docs
- **Braid**: Compiles constraints into optimized representations
- **Maze**: Orchestrates generation with constraints applied

**Q: Can I use Ananke without external services?**
A: Yes! Pure local extraction works without Claude API or inference server. See [Pure Local Pattern](../README.md#pattern-1-pure-local-no-claude-no-gpu) in README.

### Performance

**Q: How fast is constraint extraction?**
A: <2 seconds for typical codebases. With Claude: depends on API latency (~5-10s typically).

**Q: What's the throughput for code generation?**
A: ~22 tokens/second with JSON schema constraints. Varies by model and constraint complexity.

**Q: How long does constraint compilation take?**
A: Typically <50ms for reasonable constraint sets.

### Integration

**Q: How do I integrate Ananke with Modal?**
A: See [docs/DEPLOYMENT.md](DEPLOYMENT.md) and [maze/modal_inference/README.md](../maze/modal_inference/README.md).

**Q: Can I use Ananke with my custom inference server?**
A: Yes, if it supports llguidance. See [Inference Service](../README.md#inference-service) in README.

**Q: Does Ananke work with Claude's API?**
A: Yes, for constraint extraction and analysis. Use `use_claude=True` in extraction. See examples in [QUICKSTART.md](../QUICKSTART.md).

### Troubleshooting

**Q: I'm getting memory leaks in my Zig code. How do I fix this?**
A:
1. Run tests with `zig build test` - they're configured to check for leaks
2. Use `defer` for cleanup
3. Check you're using the right allocator
4. See [Memory Management](../CONTRIBUTING.md#memory-management) in CONTRIBUTING.md

**Q: Build fails on Windows. What's wrong?**
A:
1. Ensure Zig 0.15.2+ is installed and in PATH
2. Try rebuilding: `zig build clean && zig build`
3. Check for antivirus interference on Windows
4. Open an issue with full error message

**Q: Tests are failing. How do I debug?**
A: Run with verbose output:
```bash
zig build test --summary all
```
For specific test:
```bash
zig test src/module/test.zig
```

**Q: I'm getting incorrect constraint extraction. How can I fix this?**
A:
1. Check your source code format and language support
2. Try with simpler code first to isolate the issue
3. If using Claude: ensure API key is valid and has quota
4. Open an issue with minimal reproduction case

### Development

**Q: How do I contribute to Ananke?**
A: See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed guidelines.

**Q: What's the development workflow?**
A:
1. Fork and clone the repository
2. Create feature branch: `git checkout -b feature/my-feature`
3. Make changes and add tests
4. Run `zig fmt src/` and `zig build test`
5. Commit with conventional messages
6. Push and create Pull Request

**Q: Can I add support for a new language?**
A: Yes! See [adding language support](USER_GUIDE.md) in User Guide.

## Still Need Help?

### Before Asking

1. Check the [FAQ.md](FAQ.md) - your question might already be answered
2. Search [existing GitHub Issues](https://github.com/ananke-ai/ananke/issues)
3. Review the [documentation](../docs/) for your use case
4. Check [examples](../examples/) for working code

### When Asking

Provide:
- Clear description of what you're trying to do
- What you've already tried
- Minimal reproduction case (for bugs)
- Environment details (OS, Zig version, etc.)
- Error messages and stack traces

### Where to Ask

- **General questions**: [GitHub Discussions](https://github.com/ananke-ai/ananke/discussions)
- **Bug reports**: [GitHub Issues - Bug Report](https://github.com/ananke-ai/ananke/issues/new?template=bug_report.md)
- **Feature requests**: [GitHub Issues - Feature Request](https://github.com/ananke-ai/ananke/issues/new?template=feature_request.md)
- **Private matters**: Email support@ananke-ai.dev

## Feedback

We value your feedback! Help us improve Ananke:

- **Documentation**: Too unclear? [Open an issue](https://github.com/ananke-ai/ananke/issues)
- **Feature ideas**: [GitHub Discussions](https://github.com/ananke-ai/ananke/discussions)
- **Bug reports**: [GitHub Issues](https://github.com/ananke-ai/ananke/issues)
- **General feedback**: Email feedback@ananke-ai.dev

## Code of Conduct

Please note that this project is governed by our [Code of Conduct](../CODE_OF_CONDUCT.md). By participating, you agree to abide by its terms.

## Security

Found a security vulnerability? Please email security@ananke-ai.dev instead of using the public issue tracker.

---

**Last updated**: November 2024
**Ananke version**: v0.1.0
