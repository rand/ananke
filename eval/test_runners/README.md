# Test Execution Infrastructure

Automated test execution infrastructure for the Ananke evaluation framework.

## Overview

The test execution infrastructure provides automated running and validation of generated code against test suites. It supports both TypeScript (Jest) and Python (pytest) test frameworks.

## Architecture

### Components

1. **`run_tests.sh`** - Shell script that executes tests in isolated environments
   - Creates temporary directories for test execution
   - Installs dependencies (npm/pip)
   - Runs test framework (Jest/pytest)
   - Captures results in JSON format
   - Cleans up temporary files

2. **`test_runner.zig`** - Zig module for test execution orchestration
   - Creates temporary implementation files
   - Invokes run_tests.sh script
   - Parses JSON test results
   - Returns structured TestResult data

3. **Integration with Evaluator** - Test execution integrated into eval pipeline
   - Tests run automatically after code generation
   - Results attached to EvaluationPair for comparison
   - Supports both baseline and constrained code testing

## Usage

### From Zig Code

```zig
const test_runner = @import("test_runner");

var runner = test_runner.TestRunner.init(allocator);

const result = try runner.runTests(
    "typescript",              // Language: "typescript" or "python"
    implementation_code,       // Generated code as string
    "path/to/test_suite.test.ts" // Path to test file
);

defer result.deinit(allocator);

std.debug.print("Tests passed: {d}/{d}\n", .{
    result.passed_tests,
    result.total_tests
});
```

### From Command Line

```bash
# Run TypeScript tests
./run_tests.sh typescript test_file.test.ts implementation.ts output.json

# Run Python tests
./run_tests.sh python test_file_test.py implementation.py output.json
```

## Test Result Format

The test runner returns structured results:

```zig
pub const TestResult = struct {
    success: bool,              // Overall success (all tests passed)
    total_tests: u32,           // Total number of tests
    passed_tests: u32,          // Number of passed tests
    failed_tests: u32,          // Number of failed tests
    duration_ms: u64,           // Test execution duration in milliseconds
    coverage_percent: f32,      // Code coverage percentage
    error_message: ?[]const u8, // Error message if execution failed
};
```

JSON output format from shell script:

```json
{
  "success": true,
  "language": "typescript",
  "total_tests": 10,
  "passed_tests": 10,
  "failed_tests": 0,
  "duration_ms": 1234,
  "coverage_percent": 95.5
}
```

## Supported Test Frameworks

### TypeScript/Jest

- **Framework**: Jest 29.5+ with ts-jest
- **Test File Pattern**: `**/*.test.ts`, `**/*.test.tsx`
- **Dependencies**: Installed automatically in temp directory
- **Configuration**: Minimal config with `ts-jest` preset
- **Coverage**: Collected via Jest's built-in coverage

Example test file:

```typescript
import { functionToTest } from './implementation';

describe('functionToTest', () => {
  it('should return correct result', () => {
    expect(functionToTest(42)).toBe(84);
  });
});
```

### Python/pytest

- **Framework**: pytest with pytest-json-report and pytest-cov
- **Test File Pattern**: `*_test.py`, `test_*.py`
- **Dependencies**: Installed automatically in temp directory
- **Configuration**: Default pytest configuration
- **Coverage**: Collected via pytest-cov

Example test file:

```python
from implementation import function_to_test

def test_function_to_test():
    assert function_to_test(42) == 84
```

## Integration with Evaluation Pipeline

The test runner is integrated into the evaluation pipeline at `eval/core/evaluator.zig`:

```zig
pub fn evaluateTask(self: *Evaluator, task: TaskSpec) !EvaluationPair {
    // Generate baseline code
    const baseline_result = try self.baseline_generator.generate(task);

    // Generate constrained code
    const constrained_result = try self.generateConstrained(task);

    // Run tests on both implementations
    const baseline_tests = try self.test_runner.runTests(
        task.language.toString(),
        baseline_result.code,
        task.test_suite_path,
    );

    const constrained_tests = try self.test_runner.runTests(
        task.language.toString(),
        constrained_result.code,
        task.test_suite_path,
    );

    return EvaluationPair{
        .baseline = baseline_result,
        .constrained = constrained_result,
        .baseline_tests = baseline_tests,
        .constrained_tests = constrained_tests,
    };
}
```

## Error Handling

The test runner handles various failure scenarios:

1. **Missing Dependencies**: Returns error message in TestResult
2. **Test Execution Failure**: Captures failure details in JSON
3. **JSON Parsing Error**: Returns default TestResult with error message
4. **File I/O Errors**: Propagates errors to caller

## Temporary File Management

All test execution happens in temporary directories:

- Implementation files: `/tmp/ananke_impl_{timestamp}.{ext}`
- Test results: `/tmp/ananke_test_results_{timestamp}.json`
- Test execution dirs: Created via `mktemp -d`

All temporary files are automatically cleaned up after execution.

## Performance Considerations

- **Isolation**: Each test runs in a fresh temporary directory
- **Caching**: npm/pip packages are not cached between runs
- **Timeouts**: No explicit timeout (relies on test framework defaults)
- **Parallelism**: Tests run sequentially (one at a time)

## Future Enhancements

Potential improvements for the test runner:

1. **Parallel Execution**: Run multiple test suites concurrently
2. **Package Caching**: Cache npm/pip packages for faster execution
3. **Timeout Configuration**: Add configurable timeouts per language
4. **More Languages**: Add support for Rust, Go, etc.
5. **Streaming Results**: Stream test output in real-time
6. **Detailed Diagnostics**: Capture test logs for debugging
