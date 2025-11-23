# Ananke Example Sample Files Catalog

Complete catalog of all sample files across examples, organized by language, pattern type, and complexity.

## Overview

This catalog indexes **25+ sample files** across 5 examples, demonstrating diverse constraint scenarios in multiple languages and domains.

## Quick Navigation

- [By Language](#by-language)
- [By Example](#by-example)
- [By Constraint Category](#by-constraint-category)
- [By Complexity](#by-complexity)
- [By Domain](#by-domain)

---

## By Language

### TypeScript (8 files)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `01-simple-extraction/sample.ts` | 01 | 122 | Simple | Authentication handler with JWT |
| `01-simple-extraction/sample_python.py` | 01 | 250 | Medium | FastAPI user management endpoint |
| `02-claude-analysis/sample_security.ts` | 02 | 520 | Complex | Security-critical auth with MFA, session management |
| `04-full-pipeline/sample.ts` | 04 | 135 | Medium | Payment processing with retry logic |
| `04-full-pipeline/sample_api.ts` | 04 | 410 | Complex | Complete CRUD API with validation, caching, transactions |
| `05-mixed-mode/sample.ts` | 05 | 143 | Medium | Mixed constraint sources demonstration |
| `05-mixed-mode/sample_large.ts` | 05 | 580 | Very High | E-commerce platform backend |

### Python (4 files)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `01-simple-extraction/sample_python.py` | 01 | 250 | Medium | FastAPI endpoint with Pydantic validation |
| `02-claude-analysis/sample.py` | 02 | 150 | Medium | Payment processing with business logic |
| `02-claude-analysis/sample_complex_logic.py` | 02 | 470 | Complex | Insurance pricing engine with intricate rules |
| `04-full-pipeline/sample_data.py` | 04 | 490 | Complex | Data processing pipeline with quality monitoring |

### Rust (1 file)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `01-simple-extraction/sample_rust.rs` | 01 | 320 | Medium | Async HTTP handler with repository pattern |

### Go (1 file)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `01-simple-extraction/sample_go.go` | 01 | 380 | Medium | HTTP handler with in-memory repository |

### Ariadne DSL (6 files)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `03-ariadne-dsl/api_security.ariadne` | 03 | 200 | Medium | API security constraints |
| `03-ariadne-dsl/performance.ariadne` | 03 | 150 | Medium | Performance optimization rules |
| `03-ariadne-dsl/type_safety.ariadne` | 03 | 120 | Simple | Type safety requirements |
| `03-ariadne-dsl/database.ariadne` | 03 | 280 | Complex | Database query and transaction constraints |
| `03-ariadne-dsl/api_design.ariadne` | 03 | 340 | Complex | REST API design patterns |
| `03-ariadne-dsl/error_handling.ariadne` | 03 | 310 | Complex | Error handling and resilience patterns |

### JSON Constraints (3 files)

| File | Example | Lines | Complexity | Description |
|------|---------|-------|------------|-------------|
| `05-mixed-mode/constraints.json` | 05 | 91 | Simple | Basic constraint definitions |
| `05-mixed-mode/constraints/security.json` | 05 | 150 | Medium | Security constraint library |
| `05-mixed-mode/constraints/performance.json` | 05 | 130 | Medium | Performance constraint library |
| `05-mixed-mode/constraints/data_validation.json` | 05 | 180 | Medium | Data validation rules |

---

## By Example

### Example 01: Simple Extraction

**Focus**: Basic constraint extraction without LLM, demonstrating static analysis capabilities.

| File | Language | Lines | Key Constraints |
|------|----------|-------|-----------------|
| `sample.ts` | TypeScript | 122 | Type safety, syntactic patterns, authentication |
| `sample_python.py` | Python | 250 | Type hints, async patterns, Pydantic validation |
| `sample_rust.rs` | Rust | 320 | Type safety, error handling, async patterns |
| `sample_go.go` | Go | 380 | Error handling, repository pattern, HTTP handlers |

**Total**: 4 files, 1,072 lines, 4 languages

### Example 02: Claude Analysis

**Focus**: Semantic constraint extraction requiring LLM understanding of business logic.

| File | Language | Lines | Key Constraints |
|------|----------|-------|-----------------|
| `sample.py` | Python | 150 | Payment processing, business rules |
| `sample_security.ts` | TypeScript | 520 | Authentication, session management, MFA, rate limiting |
| `sample_complex_logic.py` | Python | 470 | Insurance pricing, complex calculations, regulatory compliance |

**Total**: 3 files, 1,140 lines, 2 languages

### Example 03: Ariadne DSL

**Focus**: Declarative constraint definition using domain-specific language.

| File | Type | Lines | Focus Area |
|------|------|-------|------------|
| `api_security.ariadne` | DSL | 200 | Security constraints for APIs |
| `performance.ariadne` | DSL | 150 | Performance optimization |
| `type_safety.ariadne` | DSL | 120 | Type system enforcement |
| `database.ariadne` | DSL | 280 | Database patterns and transactions |
| `api_design.ariadne` | DSL | 340 | RESTful API design principles |
| `error_handling.ariadne` | DSL | 310 | Error handling and resilience |

**Total**: 6 files, 1,400 lines, comprehensive DSL library

### Example 04: Full Pipeline

**Focus**: End-to-end constraint extraction, compilation, and validation workflow.

| File | Language | Lines | Key Constraints |
|------|----------|-------|-----------------|
| `sample.ts` | TypeScript | 135 | Payment processing, retry logic |
| `sample_api.ts` | TypeScript | 410 | CRUD operations, validation, caching |
| `sample_data.py` | Python | 490 | Data pipeline, validation, quality monitoring |

**Total**: 3 files, 1,035 lines, full-stack constraints

### Example 05: Mixed Mode

**Focus**: Combining extracted, JSON, and DSL constraints for comprehensive coverage.

| File | Type | Lines | Key Constraints |
|------|------|-------|-----------------|
| `sample.ts` | TypeScript | 143 | Basic constraint mixing |
| `sample_large.ts` | TypeScript | 580 | E-commerce platform, production-scale |
| `constraints.json` | JSON | 91 | Basic constraint definitions |
| `custom.ariadne` | DSL | 100 | Custom organizational rules |
| `constraints/security.json` | JSON | 150 | Security policy library |
| `constraints/performance.json` | JSON | 130 | Performance rules library |
| `constraints/data_validation.json` | JSON | 180 | Validation constraint library |

**Total**: 7 files, 1,374 lines, production-ready pattern

---

## By Constraint Category

### Type Safety

**Files demonstrating type safety constraints:**

- `01-simple-extraction/sample.ts` - TypeScript interfaces and type annotations
- `01-simple-extraction/sample_python.py` - Pydantic models and type hints
- `01-simple-extraction/sample_rust.rs` - Rust type system and ownership
- `03-ariadne-dsl/type_safety.ariadne` - Type safety rules
- `04-full-pipeline/sample_api.ts` - Zod schemas and type guards
- `05-mixed-mode/sample_large.ts` - Comprehensive type definitions

**Key patterns**: Explicit types, schema validation, type guards, generic constraints

### Security

**Files demonstrating security constraints:**

- `01-simple-extraction/sample.ts` - Password hashing, authentication
- `02-claude-analysis/sample_security.ts` - MFA, session management, rate limiting
- `03-ariadne-dsl/api_security.ariadne` - Security policy definitions
- `05-mixed-mode/constraints/security.json` - Security constraint library

**Key patterns**: Authentication, authorization, input validation, SQL injection prevention, PII handling

### Performance

**Files demonstrating performance constraints:**

- `03-ariadne-dsl/performance.ariadne` - Performance rules
- `04-full-pipeline/sample_api.ts` - Caching, pagination
- `04-full-pipeline/sample_data.py` - Batch processing, streaming
- `05-mixed-mode/constraints/performance.json` - Performance library
- `05-mixed-mode/sample_large.ts` - Connection pooling, caching layer

**Key patterns**: Caching, pagination, batch operations, connection pooling, query optimization

### Data Validation

**Files demonstrating validation constraints:**

- `01-simple-extraction/sample_python.py` - Pydantic validators
- `04-full-pipeline/sample_data.py` - Data quality monitoring
- `05-mixed-mode/constraints/data_validation.json` - Validation rules

**Key patterns**: Schema validation, bounds checking, format validation, business rule enforcement

### Error Handling

**Files demonstrating error handling constraints:**

- `01-simple-extraction/sample_rust.rs` - Result types, error propagation
- `01-simple-extraction/sample_go.go` - Error returns, graceful degradation
- `03-ariadne-dsl/error_handling.ariadne` - Error handling patterns
- `04-full-pipeline/sample.ts` - Retry logic, circuit breakers

**Key patterns**: Try-catch blocks, error types, retry logic, circuit breakers, graceful degradation

### Architectural

**Files demonstrating architectural constraints:**

- `01-simple-extraction/sample_rust.rs` - Repository pattern
- `01-simple-extraction/sample_go.go` - Interface-based design
- `04-full-pipeline/sample_api.ts` - Service layer pattern
- `05-mixed-mode/sample_large.ts` - Multi-layered architecture

**Key patterns**: Repository pattern, service layers, dependency injection, separation of concerns

---

## By Complexity

### Simple (3 files, ~300 lines)

**Ideal for learning basics**

- `01-simple-extraction/sample.ts` (122 lines) - Basic auth handler
- `03-ariadne-dsl/type_safety.ariadne` (120 lines) - Type safety rules
- `05-mixed-mode/constraints.json` (91 lines) - Basic constraints

**Best for**: First-time users, understanding core concepts

### Medium (12 files, ~2,800 lines)

**Production-ready examples**

- `01-simple-extraction/sample_python.py` (250 lines) - FastAPI endpoint
- `01-simple-extraction/sample_rust.rs` (320 lines) - Async Rust handler
- `01-simple-extraction/sample_go.go` (380 lines) - Go HTTP service
- `02-claude-analysis/sample.py` (150 lines) - Payment processing
- `03-ariadne-dsl/api_security.ariadne` (200 lines) - Security DSL
- `03-ariadne-dsl/performance.ariadne` (150 lines) - Performance DSL
- `04-full-pipeline/sample.ts` (135 lines) - Payment retry logic
- `05-mixed-mode/sample.ts` (143 lines) - Mixed constraints
- `05-mixed-mode/constraints/security.json` (150 lines) - Security library
- `05-mixed-mode/constraints/performance.json` (130 lines) - Performance library
- `05-mixed-mode/constraints/data_validation.json` (180 lines) - Validation library

**Best for**: Intermediate users, real-world patterns

### Complex (6 files, ~2,500 lines)

**Advanced scenarios**

- `02-claude-analysis/sample_security.ts` (520 lines) - Security system
- `02-claude-analysis/sample_complex_logic.py` (470 lines) - Insurance pricing
- `03-ariadne-dsl/database.ariadne` (280 lines) - Database constraints
- `03-ariadne-dsl/api_design.ariadne` (340 lines) - API design patterns
- `03-ariadne-dsl/error_handling.ariadne` (310 lines) - Error handling
- `04-full-pipeline/sample_api.ts` (410 lines) - Complete CRUD API
- `04-full-pipeline/sample_data.py` (490 lines) - Data pipeline

**Best for**: Advanced users, complex systems

### Very High (1 file, 580 lines)

**Production-scale codebase**

- `05-mixed-mode/sample_large.ts` (580 lines) - E-commerce platform

**Best for**: Understanding Ananke on real production code

---

## By Domain

### API Development

- `01-simple-extraction/sample_python.py` - FastAPI basics
- `03-ariadne-dsl/api_security.ariadne` - API security
- `03-ariadne-dsl/api_design.ariadne` - REST API patterns
- `04-full-pipeline/sample_api.ts` - Complete CRUD API

### Authentication & Security

- `01-simple-extraction/sample.ts` - JWT authentication
- `02-claude-analysis/sample_security.ts` - Advanced auth system
- `05-mixed-mode/constraints/security.json` - Security policies

### Data Processing

- `04-full-pipeline/sample_data.py` - Analytics pipeline
- `05-mixed-mode/sample_large.ts` - E-commerce data layer

### Database Operations

- `03-ariadne-dsl/database.ariadne` - Query patterns
- `05-mixed-mode/sample_large.ts` - Transaction handling

### Payment Processing

- `02-claude-analysis/sample.py` - Basic payment flow
- `04-full-pipeline/sample.ts` - Payment with retry
- `05-mixed-mode/sample_large.ts` - Order processing

### Business Logic

- `02-claude-analysis/sample_complex_logic.py` - Insurance pricing
- `05-mixed-mode/sample_large.ts` - E-commerce rules

---

## Constraint Extraction Expected Results

### Example 01: Simple Extraction

**Expected constraints per file:**
- `sample.ts`: ~12 constraints (type safety, syntactic, security)
- `sample_python.py`: ~15 constraints (type hints, validation, async)
- `sample_rust.rs`: ~18 constraints (type system, error handling, ownership)
- `sample_go.go`: ~16 constraints (error handling, interfaces, patterns)

**Total**: ~61 constraints across 4 languages

### Example 02: Claude Analysis

**Expected constraints per file:**
- `sample.py`: ~8 constraints (business rules, thresholds)
- `sample_security.ts`: ~25 constraints (security patterns, session management)
- `sample_complex_logic.py`: ~30 constraints (business rules, calculations, compliance)

**Total**: ~63 semantic constraints requiring LLM

### Example 03: Ariadne DSL

**Defined constraints:**
- `api_security.ariadne`: 10 security constraints
- `performance.ariadne`: 8 performance constraints
- `type_safety.ariadne`: 6 type constraints
- `database.ariadne`: 10 database constraints
- `api_design.ariadne`: 10 API design constraints
- `error_handling.ariadne`: 10 error handling constraints

**Total**: 54 explicitly defined DSL constraints

### Example 04: Full Pipeline

**Expected constraints per file:**
- `sample.ts`: ~10 constraints (retry, timeout, validation)
- `sample_api.ts`: ~35 constraints (CRUD, validation, caching, transactions)
- `sample_data.py`: ~40 constraints (pipeline, validation, quality)

**Total**: ~85 constraints demonstrating full workflow

### Example 05: Mixed Mode

**Constraint sources:**
- Extracted from code: ~45 constraints
- JSON libraries: 35 constraints (security + performance + validation)
- Ariadne DSL: ~8 custom constraints

**Total**: ~88 constraints from multiple sources

---

## Usage Recommendations

### For Learning (Start Here)

1. **Example 01 / sample.ts** - Understand basic extraction
2. **Example 03 / type_safety.ariadne** - Learn DSL syntax
3. **Example 05 / constraints.json** - Understand JSON format

### For API Development

1. **Example 01 / sample_python.py** - FastAPI patterns
2. **Example 03 / api_design.ariadne** - REST best practices
3. **Example 04 / sample_api.ts** - Complete CRUD example

### For Security-Critical Systems

1. **Example 02 / sample_security.ts** - Comprehensive auth
2. **Example 03 / api_security.ariadne** - Security policies
3. **Example 05 / constraints/security.json** - Security library

### For Production Deployment

1. **Example 04 / sample_api.ts** - Production API patterns
2. **Example 05 / sample_large.ts** - Large codebase handling
3. **Example 05 / constraints/** - Complete constraint libraries

---

## File Naming Conventions

- `sample.{ext}` - Primary example file
- `sample_{descriptor}.{ext}` - Additional samples by focus area
- `constraints.json` - Basic JSON constraints
- `{area}.ariadne` - DSL constraints by domain
- `constraints/{area}.json` - Organized constraint libraries

---

## Testing the Samples

### Validate Syntax

```bash
# TypeScript
tsc --noEmit sample.ts

# Python
python -m py_compile sample.py

# Rust
rustc --crate-type lib sample.rs

# Go
go build sample.go
```

### Extract Constraints

```bash
# Simple extraction (no LLM)
ananke extract sample.ts --output constraints.json

# With Claude analysis
ananke extract sample.py --claude --output constraints.json

# Compile constraints
ananke compile constraints.json --output compiled.cir
```

---

## Contributing Samples

Want to add a new sample? Follow these guidelines:

1. **Naming**: `sample_{focus_area}.{ext}`
2. **Size**: 100-500 lines for medium, 500+ for complex
3. **Comments**: Annotate constraints with inline comments
4. **Diversity**: Cover patterns not in existing samples
5. **Quality**: Syntactically valid, runnable code

---

## Summary Statistics

**Total Files**: 25+
**Total Lines**: ~6,800
**Languages**: TypeScript, Python, Rust, Go, Ariadne DSL, JSON
**Examples**: 5
**Constraint Types**: 6 (type safety, security, performance, semantic, architectural, operational)
**Complexity Levels**: 4 (simple, medium, complex, very high)
**Domains**: API, Auth, Data, Database, Payment, Business Logic

---

**Last Updated**: 2025-11-23
**Ananke Version**: v1.0
**Maintainer**: Ananke Team
