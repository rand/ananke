# Ananke Constraint Pipeline

This document describes how constraints flow from task definition files to vLLM's structured output enforcement.

## Pipeline Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          CONSTRAINT PIPELINE                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  1. Task Definition Files                                                     │
│     eval/tasks/constraints/*.json                                             │
│     ┌─────────────────────────────────────────────────────────────────────┐  │
│     │ {                                                                    │  │
│     │   "task_id": "system_001_config_parser",                            │  │
│     │   "constraints": {                                                   │  │
│     │     "grammar": "from typing import Any\n\ndef parse_config...",    │  │
│     │     "regex_pattern": "^from\\s+typing\\s+import\\s+Any..."         │  │
│     │   }                                                                  │  │
│     │ }                                                                    │  │
│     └─────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│                                      ▼                                        │
│  2. Zig Evaluator (evaluator.zig)                                            │
│     - Loads constraint JSON from file                                         │
│     - Passes to constraint compiler                                           │
│                                      │                                        │
│                                      ▼                                        │
│  3. Eval Constraint Compiler (eval_constraint_compiler.zig)                   │
│     - Parses constraint JSON                                                  │
│     - Priority: regex_pattern > json_schema > prompt_only                     │
│     - Adds [\s\S]* suffix to regex patterns for continuation                  │
│     - Outputs llguidance-compatible JSON                                      │
│     ┌─────────────────────────────────────────────────────────────────────┐  │
│     │ {                                                                    │  │
│     │   "llguidance": {                                                    │  │
│     │     "type": "guidance",                                              │  │
│     │     "version": "1.0",                                                │  │
│     │     "regex": "^from\\s+typing\\s+import\\s+Any[\\s\\S]*"            │  │
│     │   },                                                                 │  │
│     │   "constraint_type": "regex",                                        │  │
│     │   "grammar": "from typing import Any..."                             │  │
│     │ }                                                                    │  │
│     └─────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│                                      ▼                                        │
│  4. Modal Client (modal_client.zig)                                          │
│     - HTTP POST to Modal endpoint                                             │
│     - Sends compiled constraints in request body                              │
│                                      │                                        │
│                                      ▼                                        │
│  5. Modal Inference Service (inference_service.py)                           │
│     - Receives compiled constraints                                           │
│     - Extracts regex/json_schema from llguidance field                        │
│     - Creates vLLM StructuredOutputsParams                                    │
│     ┌─────────────────────────────────────────────────────────────────────┐  │
│     │ StructuredOutputsParams(                                             │  │
│     │   regex="^from\\s+typing\\s+import\\s+Any[\\s\\S]*"                 │  │
│     │ )                                                                    │  │
│     └─────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│                                      ▼                                        │
│  6. vLLM with llguidance                                                      │
│     - Token-level constraint enforcement                                      │
│     - Only generates tokens that match the regex                              │
│     - Ensures output starts with required prefix                              │
│                                      │                                        │
│                                      ▼                                        │
│  7. Generated Code                                                            │
│     "from typing import Any\n\ndef parse_config(content: str) -> ..."       │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Constraint Types

### 1. Regex Constraints (Recommended)

Regex patterns provide token-level enforcement. The eval framework uses prefix patterns that anchor the beginning of the generated code.

**Input (constraint file):**
```json
{
  "regex_pattern": "^from\\s+typing\\s+import\\s+Any\\s*\\ndef\\s+parse_config\\s*\\("
}
```

**Compiled output:**
```json
{
  "regex": "^from\\s+typing\\s+import\\s+Any\\s*\\ndef\\s+parse_config\\s*\\([\\s\\S]*"
}
```

The `[\s\S]*` suffix is added to allow any content after the prefix pattern.

### 2. JSON Schema Constraints

For tasks that output JSON, JSON Schema provides structured validation.

**Input:**
```json
{
  "grammar": "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}}}"
}
```

**Compiled output:**
```json
{
  "json_schema": {"type": "object", "properties": {"name": {"type": "string"}}}
}
```

### 3. Prompt-Only Constraints

When neither regex nor JSON Schema is available, the grammar signature is used only for prompt engineering.

**Input:**
```json
{
  "grammar": "function parseConfig(content: string): Record<string, any>"
}
```

**Compiled output:**
```json
{
  "constraint_mode": "prompt_only",
  "signature": "function parseConfig(content: string): Record<string, any>"
}
```

## Key Components

### eval_constraint_compiler.zig

Location: `eval/core/eval_constraint_compiler.zig`

Key functions:
- `compile()` - Main entry point, parses JSON and routes to appropriate compiler
- `compileRegex()` - Creates llguidance regex constraint with suffix
- `compileJsonSchema()` - Wraps JSON Schema for llguidance
- `compilePromptOnly()` - Fallback for non-enforceable constraints
- `compileForModal()` - Builds complete constraint object for HTTP request

### inference_service.py

Location: `eval/modal/inference_service.py`

Key logic in `_generate_constrained_internal()`:
1. Check for `llguidance` field (compiled format)
2. Extract `regex` or `json_schema` from llguidance
3. Create `StructuredOutputsParams` for vLLM
4. Pass to `SamplingParams` for generation

## Important Notes

### Regex Pattern Suffix

The eval constraint patterns are prefix matchers (e.g., `^from\s+typing...`), designed to match the START of code. However, vLLM's regex constraint does FULL string matching.

To make prefix patterns work:
- The compiler appends `[\s\S]*` to all regex patterns
- This allows any content after the prefix is matched
- Uses `[\s\S]` instead of `.` to match newlines (dotall behavior)

### Constraint Priority

When both regex and grammar are present:
1. **regex_pattern** - Used for token-level enforcement
2. **json_schema** (in grammar field) - Used if grammar is valid JSON Schema
3. **prompt_only** - Fallback, grammar is included in prompt but not enforced

### Error Handling

The inference service wraps all generation in try/catch:
- Regex compilation errors are caught
- Invalid JSON Schema is handled gracefully
- Errors are returned in metadata field

## Testing the Pipeline

### 1. Test Constraint Compilation

```bash
zig test eval/core/eval_constraint_compiler.zig
```

### 2. Test Modal Endpoint

```bash
curl -X POST https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-inferenceservice-fastapi-app.modal.run/generate/constrained \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Write a Python config parser",
    "constraints": {
      "llguidance": {"type": "guidance", "version": "1.0", "regex": "^def\\s+add[\\s\\S]*"},
      "constraint_type": "regex"
    }
  }'
```

### 3. Run Full Evaluation

```bash
./zig-out/bin/ananke-eval run \
  --endpoint https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-inferenceservice-fastapi-app.modal.run \
  --output eval/results
```

## Troubleshooting

### Generated code stops early

**Symptom:** Output like `"def add"` instead of full function

**Cause:** Regex pattern doesn't allow continuation

**Fix:** Ensure `[\s\S]*` suffix is appended to pattern

### "grammar not defined" error

**Symptom:** Error accessing `grammar` variable

**Cause:** Variable not initialized in llguidance code path

**Fix:** Initialize `grammar = constraints.get("grammar")` early in function

### Empty responses

**Symptom:** Curl returns empty or timeout

**Cause:** Modal container cold start or connection issue

**Fix:**
1. Wait for container warmup (first request may take 2-3 minutes)
2. Check Modal logs: `modal app logs ananke-eval-inference`
