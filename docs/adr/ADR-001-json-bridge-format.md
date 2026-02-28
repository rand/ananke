# ADR-001: JSON as Bridge Format Between Zig Engine and Python sglang

## Status
Proposed

## Context
The Constraint-Shaped Code Synthesis pipeline spans two systems running in separate processes: Ananke (Zig/Rust CLI) extracts and compiles constraints, while ananke-sglang (Python) enforces them during token-level decoding. These systems communicate over HTTP via an OpenAI-compatible API with a `constraint_spec` extension field. A serialization format is needed for this bridge.

Constraint data per request is small -- typically <10KB of JSON describing function signatures, type bindings, import lists, control flow patterns, and semantic hints across the five CLaSH domains. This is negligible relative to the inference cost (seconds of GPU time per generation).

## Decision
Use JSON as the serialization format, with the contract defined by `ConstraintSpec.from_dict()` in ananke-sglang. The Zig side serializes via `SyntaxStructure.toConstraintSpecJson()` and the Python side deserializes via `ConstraintSpec.from_dict()`. Field names in the JSON must match exactly between the two systems.

The `ananke export-spec` command provides a one-shot pipeline that produces the complete ConstraintSpec JSON, enabling independent testing of each side.

## Consequences

**Positive:**
- Independent testability: each system can be tested with static JSON fixtures without running the other.
- Backward compatibility: adding new optional fields to the JSON does not break existing consumers. Old Ananke versions work with new sglang versions and vice versa.
- Debugging transparency: constraint specs are human-readable and can be inspected, logged, and diffed.
- No build coupling: Zig and Python have independent build systems with no shared codegen step.
- Aligns with the existing OpenAI-compatible API surface that sglang already uses.

**Negative:**
- Serialization overhead exists (though negligible at <10KB per request vs seconds of inference time).
- Schema drift risk: the Zig serializer and Python deserializer can diverge silently. Mitigated by CI round-trip conformance tests (serialize in Zig, deserialize in Python, validate field integrity).
- No compile-time contract enforcement across the language boundary.

## Alternatives Considered

**Protocol Buffers (Protobuf):** Provides schema enforcement and compact binary encoding. Rejected because it adds a codegen step to both build systems, the schema enforcement benefit is achievable via CI tests, and the compact encoding is unnecessary at <10KB payloads.

**FlatBuffers:** Zero-copy deserialization would be relevant for high-frequency per-token communication but is overkill for once-per-request constraint specs. Adds build complexity.

**MessagePack:** Binary JSON-compatible format. Marginal size reduction does not justify losing human readability for debugging.

**Binary encoding via Zig FFI:** Direct memory-layout sharing between Zig and Python (via ctypes or cffi). Would eliminate serialization overhead entirely but tightly couples the systems, makes independent testing difficult, and introduces platform-specific alignment concerns. Reserved as a Phase 4b optimization only if profiling justifies it.

## References
- ConstraintSpec.from_dict() contract in ananke-sglang
- Integration plan Phase 1 (Connect the Pipeline) and Phase 2 (Rich Context Export)
- OpenAI Chat Completions API specification
