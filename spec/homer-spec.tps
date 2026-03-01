spec ananke

# Design

## Area 0: src
files:
  - maze/src/model_selector.rs
  - maze/src/model_router.rs
  - maze/src/progressive_refinement.rs
  - maze/src/ffi.rs
  - maze/src/modal_client.rs

## Area 1: api
files:
  - src/api/retry.zig
  - src/api/http.zig

## Area 2: braid
files:
  - src/braid/sanitizer.zig
  - src/braid/braid.zig
  - src/braid/json_schema_builder.zig
  - src/braid/hole_compiler.zig

## Area 3: clew
files:
  - src/clew/clew.zig
  - src/clew/hybrid_extractor.zig

## Area 4: clew
files:
  - src/clew/extractors/zig_lang.zig
  - src/clew/extractors.zig
  - src/clew/extractors/base.zig
  - src/clew/extractors/python.zig
  - src/clew/extractors/go.zig
  - src/clew/extractors/c.zig
  - src/clew/extractors/rust.zig
  - src/clew/extractors/java.zig
  - src/clew/extractors/typescript.zig
  - src/clew/extractors/javascript.zig
  # ... and 1 more

## Area 5: test_assertion_parser_test
files:
  - test/clew/test_assertion_parser_test.zig
  - src/clew/parsers/test_assertions.zig

## Area 6: clew
files:
  - src/clew/hole_detector.zig
  - src/clew/semantic_hole_detector.zig

## Area 7: src
files:
  - src/cli/commands/init.zig
  - src/main.zig
  - src/cli/commands/generate.zig
  - src/cli/config.zig
  - src/cli/commands/help.zig
  - src/cli/commands/version.zig

## Area 8: generate_test
files:
  - test/cli/generate_test.zig
  - src/cli/args.zig
  - test/cli/cli_integration_test.zig
  - test/cli/cli_test.zig

## Area 9: cli
files:
  - src/cli/commands/extract.zig
  - src/cli/commands/compile.zig
  - src/cli/output.zig
  - src/cli/error_help.zig
  - src/cli/error.zig

## Area 10: validate
files:
  - src/cli/commands/validate.zig
  - test/security/edge_cases_test.zig
  - src/cli/path_validator.zig

## Area 11: root
files:
  - src/root.zig
  - src/utils/string_interner.zig
  - src/utils/ring_queue.zig
  - src/types/intent.zig
  - test/integration/e2e_pipeline_test.zig

## Area 12: types
files:
  - src/types/constraint_validator.zig
  - src/types/hole.zig
  - src/types/constraint.zig

## Area 13: docstring_to_test_cases
files:
  - examples/production/05-test-generator/scripts/docstring_to_test_cases.py
  - maze/tests/ffi_tests.rs

## Area 14: clew
files:
  - src/clew/tree_sitter/parser.zig
  - src/clew/tree_sitter/languages.zig
  - src/clew/tree_sitter.zig
  - src/clew/tree_sitter/c_api.zig
  - src/clew/tree_sitter/traversal.zig
  - src/clew/tree_sitter/query.zig

## Area 15: e2e
files:
  - test/e2e/helpers.zig
  - test/e2e/mocks/mock_modal.zig
  - test/e2e/e2e_test.zig

## Area 16: test_ffi_roundtrip
files:
  - test_ffi_roundtrip.zig
  - src/ffi/zig_ffi.zig

## Area 17: bench
files:
  - bench/e2e_benchmarks.zig
  - bench/cache_benchmarks.zig
  - bench/compilation_benchmarks.zig
  - bench/extraction_benchmarks.zig
  - bench/benchmark_runner.zig

## Area 18: eval
files:
  - eval/core/task_spec.zig
  - eval/core/modal_client.zig
  - eval/baseline/generator.zig

## Area 19: core
files:
  - eval/core/eval_constraint_compiler.zig
  - eval/core/failure_analyzer.zig
  - eval/core/quality_scorer.zig
  - eval/core/evaluator.zig

## Area 20: src
files:
  - maze/src/strategy_stats.rs
  - maze/src/telemetry.rs
  - maze/src/adaptive_selector.rs

## Area 21: core
files:
  - eval/core/prompt_normalizer.zig
  - eval/core/metrics/statistical_tests.zig

## Area 22: judge
files:
  - eval/judge/rubrics.zig
  - eval/judge/claude_client.zig
  - eval/judge/judge.zig

## Area 23: zig
files:
  - eval/tasks/fixtures/zig/allocator_arena.zig
  - eval/tasks/fixtures/zig/allocator_arena_test.zig

## Area 24: zig
files:
  - eval/tasks/fixtures/zig/comptime_validation_test.zig
  - eval/tasks/fixtures/zig/comptime_validation.zig

## Area 25: zig
files:
  - eval/tasks/fixtures/zig/error_union_test.zig
  - eval/tasks/fixtures/zig/error_union.zig

## Area 26: zig
files:
  - eval/tasks/fixtures/zig/simd_vector_test.zig
  - eval/tasks/fixtures/zig/simd_vector.zig

# Concepts

Concept AuthHandler:
  file: examples/01-simple-extraction/sample.ts

Concept User:
  file: examples/01-simple-extraction/sample.ts

Concept PasswordHasher:
  file: examples/01-simple-extraction/sample.ts

Concept PaymentRequest:
  file: examples/02-claude-analysis/sample.py
  description: Represents a payment request from a customer

Concept PaymentResult:
  file: examples/02-claude-analysis/sample.py
  description: Result of a payment processing attempt

Concept PaymentProcessor:
  file: examples/02-claude-analysis/sample.py
  description: Processes payments with fraud detection and compliance checks.

Concept StandardResponse:
  file: examples/05-mixed-mode/sample.ts

Concept Payment:
  file: examples/05-mixed-mode/sample.ts

Concept PaymentHandler:
  file: examples/05-mixed-mode/sample.ts

Concept tests:
  file: maze/examples/simple_generation.rs

Concept ConstraintIRFFI:
  file: maze/src/ffi.rs

Concept TokenMaskRulesFFI:
  file: maze/src/ffi.rs

Concept ConstraintIR:
  file: maze/src/ffi.rs

Concept JsonSchema:
  file: maze/src/ffi.rs

Concept Grammar:
  file: maze/src/ffi.rs

Concept GrammarRule:
  file: maze/src/ffi.rs

Concept RegexPattern:
  file: maze/src/ffi.rs

Concept TokenMaskRules:
  file: maze/src/ffi.rs

Concept IntentFFI:
  file: maze/src/ffi.rs

Concept Intent:
  file: maze/src/ffi.rs
