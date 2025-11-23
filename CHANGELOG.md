# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial development

## [0.1.0] - 2025-11-23

### Added

#### Core Features
- **Clew**: Constraint extraction engine for analyzing source code
  - Tree-sitter based syntax analysis
  - Claude API integration for semantic constraint discovery
  - Multi-language support (TypeScript, Python, Rust, Go, Java, Zig)
  - FFI interface for cross-language integration

- **Braid**: Constraint compilation engine
  - Converts extracted constraints to ConstraintIR
  - Optimizes constraint rules for inference
  - Validates constraint consistency
  - Supports multiple constraint types (schema, grammar, regex, token masks)

- **Maze**: Rust orchestration layer
  - HTTP client for Modal/RunPod inference services
  - Constraint compilation to llguidance format
  - LRU caching for compiled constraints
  - Provenance tracking for generated code
  - FFI bridge for Zig integration
  - Async/await support with Tokio

- **Ariadne**: Optional DSL for constraint definition
  - Human-readable constraint syntax
  - Compiler to ConstraintIR
  - Type checking and validation

#### CLI Interface
- `ananke extract` - Extract constraints from source files
- `ananke compile` - Compile constraints to IR
- `ananke generate` - Generate code with constraints
- `ananke validate` - Validate code against constraints

#### Infrastructure
- GitHub Actions CI/CD pipeline
  - Multi-platform testing (Linux, macOS)
  - Automated benchmarking
  - Code coverage reporting
  - Security auditing
- Comprehensive test suite (unit, integration, FFI, end-to-end)
- Performance benchmarks for all components

#### Documentation
- Architecture overview
- API documentation
- Integration guides (Zig ↔ Rust FFI)
- Example projects
- Quickstart guide

### Performance
- Constraint extraction: <100ms for typical files
- Constraint compilation: ~10-50ms (with caching: ~1μs)
- FFI overhead: <10μs per call
- Inference latency: ~2-10s (model dependent)
- Token masking: ~50μs per token (llguidance)

### Known Limitations
- Tree-sitter integration temporarily disabled pending Zig 0.15.x compatibility
- Streaming generation not yet implemented
- Local GGUF model support not yet implemented
- Windows support is experimental

### Dependencies
- Zig 0.15.1 or later
- Rust 1.70 or later
- Modal/RunPod inference service (for generation)

---

## Release Notes Template

For future releases, use this template:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features and capabilities

### Changed
- Changes to existing functionality
- Breaking changes (mark with **BREAKING**)

### Deprecated
- Features marked for removal

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements and vulnerability fixes

### Performance
- Performance improvements and optimizations
```

---

## Version History

[0.1.0]: https://github.com/ananke-project/ananke/releases/tag/v0.1.0
