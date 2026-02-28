# SPEC-02: sglang Backend Integration

## Rationale

Ananke extracts and compiles constraints; ananke-sglang enforces them during token generation. The boundary between these systems is a JSON contract (ConstraintSpec) sent over an OpenAI-compatible HTTP API. This spec defines the exact contract, configuration, request/response format, and the one-shot pipeline that collapses the extract-compile-generate ceremony into a single command.

---

## [SPEC-02.01] ConstraintSpec JSON Contract

The ConstraintSpec JSON object is the sole interface between Ananke (Zig/Rust) and ananke-sglang (Python). Field names and types must match `ConstraintSpec.from_dict()` in the ananke-sglang codebase exactly.

Required fields:

```json
{
  "language": "string",
  "json_schema": "object | null"
}
```

Optional fields (activate additional domains when present):

```json
{
  "type_bindings": [
    {"name": "string", "type_expr": "string", "scope": "string | null"}
  ],
  "function_signatures": [
    {
      "name": "string",
      "params": [{"name": "string", "type": "string"}],
      "return_type": "string | null",
      "is_async": "boolean",
      "is_generator": "boolean"
    }
  ],
  "class_definitions": [
    {
      "name": "string",
      "fields": [{"name": "string", "type": "string"}],
      "methods": ["string"]
    }
  ],
  "imports": [
    {"module": "string", "items": ["string"], "alias": "string | null"}
  ],
  "control_flow": {
    "is_async": "boolean",
    "is_generator": "boolean",
    "loop_depth": "integer",
    "has_try_catch": "boolean",
    "error_handling_pattern": "string | null"
  },
  "semantic_constraints": {
    "preconditions": ["string"],
    "postconditions": ["string"],
    "invariants": ["string"]
  },
  "scope_bindings": [
    {
      "name": "string",
      "type_expr": "string | null",
      "resolution_path": "string",
      "source_file": "string"
    }
  ],
  "intensity": "string"
}
```

The `intensity` field, when present, overrides automatic intensity selection in ananke-sglang. Valid values are defined in [SPEC-01.06].

**Acceptance criteria**: A conformance test must serialize a ConstraintSpec in Zig, deserialize it via `ConstraintSpec.from_dict()` in Python, and verify all fields round-trip without loss. This test runs in CI. Any field name change in either system must fail this test.

---

## [SPEC-02.02] sglang Backend Configuration

Ananke discovers the sglang endpoint through two mechanisms, in priority order:

1. **Environment variable**: `ANANKE_SGLANG_ENDPOINT` (e.g., `http://localhost:30000`)
2. **Configuration file**: `.ananke.toml` at the project root:

```toml
[sglang]
endpoint = "http://localhost:30000"
model = "Qwen/Qwen3-32B"
timeout_ms = 30000
```

The `endpoint` field is required when the `[sglang]` section is present. The `model` field is optional and used for display/logging only (the sglang server determines its own model). The `timeout_ms` field defaults to 30000.

The environment variable takes precedence over the config file. If neither is set and `--backend sglang` is requested, the CLI must exit with a clear error message naming both configuration sources.

**Acceptance criteria**: The CLI must resolve configuration in the documented priority order. Missing configuration with `--backend sglang` must produce a diagnostic error, not a connection failure. Configuration parsing must handle missing optional fields without error.

---

## [SPEC-02.03] OpenAI-Compatible Request Format

Ananke sends requests to the sglang endpoint using the OpenAI chat completions format with a `constraint_spec` extension:

```json
POST /v1/chat/completions
{
  "model": "default",
  "messages": [
    {"role": "system", "content": "...system prompt..."},
    {"role": "user", "content": "...generation prompt with context..."}
  ],
  "temperature": 0.0,
  "max_tokens": 4096,
  "constraint_spec": { ... }
}
```

The `constraint_spec` field is the ConstraintSpec JSON defined in [SPEC-02.01]. sglang's `AnankeBackend` reads this field from the request and activates the corresponding constraint domains.

The system prompt includes the generation instruction. When `--context` is provided, the user message includes the source file content with the hole location marked. The `constraint_spec` carries structured constraint data -- it is not duplicated in the prompt text.

The HTTP client must handle:
- Redirects (response buffer >= 2048 bytes to fix the existing `HttpRedirectLocationOversize` bug at `generate.zig` line 214)
- Connection timeouts (per `timeout_ms` configuration)
- Non-200 responses (extract error message from response body, present to user)

**Acceptance criteria**: The request must be accepted by a standard sglang server running with `--grammar-backend ananke`. The `constraint_spec` field must be ignored by sglang servers running without the Ananke backend (no error, no crash). The redirect buffer fix must be verified by test.

---

## [SPEC-02.04] Response Parsing

Ananke extracts generated code from the sglang response:

```json
{
  "choices": [
    {
      "message": {
        "content": "...generated code..."
      },
      "finish_reason": "stop | length"
    }
  ],
  "usage": {
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0
  }
}
```

The generated code is `choices[0].message.content`. Ananke must handle:

- `finish_reason: "length"` -- warn the user that generation was truncated.
- Empty `choices` array -- error with "no generation produced".
- Missing `content` field -- error with "malformed response".
- HTTP-level errors (connection refused, timeout) -- error with endpoint and configuration guidance.

**Acceptance criteria**: Each error case must produce a distinct, actionable error message. Truncation warnings must include the token limit that was hit. Successful responses must extract content without trailing whitespace artifacts.

---

## [SPEC-02.05] Backend Selection

The `--backend` flag selects the inference backend:

| Value | Behavior |
|-------|----------|
| `sglang` | Send to sglang endpoint with ConstraintSpec |
| `modal` | Send to Modal endpoint (existing behavior) |

Default behavior when `--backend` is omitted:

1. If `ANANKE_SGLANG_ENDPOINT` or `[sglang]` config exists, default to `sglang`.
2. Otherwise, default to `modal`.

This ensures backward compatibility: existing users without sglang configuration get the same behavior. New users who configure sglang get constrained generation by default.

**Acceptance criteria**: Omitting `--backend` with no sglang configuration must use Modal. Omitting `--backend` with sglang configuration must use sglang. Explicit `--backend` must override the default in all cases.

---

## [SPEC-02.06] One-Shot Pipeline Commands

Two commands collapse the multi-step ceremony into single invocations:

### `ananke export-spec`

Combines extract + compile + rich context into a ConstraintSpec JSON:

```bash
ananke export-spec src/auth.py -o spec.json
ananke export-spec src/auth.py --intensity FULL
ananke export-spec src/auth.py --homer  # include scope graph context
```

Output is a ConstraintSpec JSON ([SPEC-02.01]) written to stdout or the file specified by `-o`. This is useful for debugging, piping to other tools, or manual submission to sglang.

### `ananke generate --context`

Combines extract + compile + rich context + inference in a single command:

```bash
ananke generate "implement rate limiter" --context src/api/middleware.py --backend sglang
ananke generate "add validation" --context src/models/user.py --backend sglang --homer
ananke generate --fim --prefix "..." --suffix "..." --language python --backend sglang
```

The `--context` flag specifies a source file to extract constraints from. The pipeline runs internally: extract SyntaxStructure from the context file, compile to ConstraintIR, merge RichContext, build ConstraintSpec JSON, POST to sglang, return generated code.

The `--fim` flag activates fill-in-the-middle mode ([SPEC-05.05]). It requires `--prefix` and `--suffix` (the code before and after the hole) and `--language`.

**Acceptance criteria**: `export-spec` must produce valid ConstraintSpec JSON that `from_dict()` accepts without error. `generate --context` must produce the same result as running extract, compile, and generate as separate steps. The `--fim` flag must be rejected without `--prefix`, `--suffix`, and `--language`.

---

## References

- ananke-sglang: `ConstraintSpec.from_dict()` -- the canonical deserialization contract
- OpenAI Chat Completions API: request/response format baseline
- sglang `AnankeBackend`: grammar backend that consumes `constraint_spec`
