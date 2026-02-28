# SPEC-05: Domain Fusion and Performance

## Rationale

Five constraint domains produce five signals per token. Fusing them into a single sampling distribution is the final step before generation. Naive approaches (intersect all masks, multiply all scores) distort the LLM's learned distribution and degrade output quality. This spec defines principled fusion strategies grounded in recent research: hard domain intersection, soft domain reweighting within the feasible set, distribution preservation via ASAp-style composition, adaptive constraint switching during reasoning, FIM grammar quotienting, and call graph context inlining.

---

## [SPEC-05.01] Hard Domain Fusion by Intersection

Hard domains (Syntax, Types, Imports) compose by set intersection:

```
valid_tokens = syntax_mask AND type_mask AND import_mask
```

This is implemented as bitwise AND over vocabulary-sized bitmasks. A token is valid if and only if it satisfies all three hard domains simultaneously. There is no weighting, no relaxation, no ordering -- intersection is exact.

If the intersection is empty (no token satisfies all hard constraints), this is an unsatisfiable state. Recovery follows this cascade:

1. Drop Imports mask (most likely to over-constrain due to incomplete scope information). Retry.
2. Drop Types mask (prefix automata may have stale state). Retry.
3. Fall back to Syntax-only mask (always non-empty for valid grammar states).
4. If Syntax mask is empty, this indicates a parser bug -- log error, fall back to unconstrained.

Each fallback step is logged with the domain that was dropped. The relaxation cascade is deterministic and auditable.

Computational cost: bitwise AND over `|V|`-bit vectors. For vocabulary size 128K, each mask is 16KB. Three-way AND is ~48KB of memory bandwidth -- effectively free at ~10us/token.

**Acceptance criteria**: Hard fusion must produce the exact intersection, verified against brute-force enumeration on a small vocabulary. The relaxation cascade must follow the specified order. Each relaxation must be logged. An empty syntax mask must trigger an error, not silent fallback to unconstrained.

---

## [SPEC-05.02] Soft Domain Fusion by Weighted Reweighting

Soft domains (ControlFlow, Semantics) compose by additive logit adjustment within the feasible set defined by hard domains:

```
for each token t in valid_tokens:
    adjusted_logits[t] = base_logits[t] + alpha * controlflow_score[t] + beta * semantic_score[t]

for each token t NOT in valid_tokens:
    adjusted_logits[t] = -inf
```

Where:

- `base_logits[t]` are the LLM's raw logits for token `t`
- `controlflow_score[t]` is in [-1.0, 1.0]: positive favors convention-conformant tokens, negative disfavors
- `semantic_score[t]` is in [-1.0, 1.0]: positive favors semantically aligned tokens, negative disfavors
- `alpha` and `beta` are scaling coefficients, default 1.0, configurable per intensity level

Crucially, soft scores are applied **after** hard masking. A token rejected by hard domains is -inf regardless of soft scores. This structurally enforces [SPEC-01.04].

The additive formulation (as opposed to multiplicative) preserves the LLM's relative token preferences within the feasible set. A soft score of 0.0 means "no opinion" -- the LLM's distribution is unchanged for that token.

Soft score computation must be lazy: if ControlFlow has no constraints for the current context, `alpha * controlflow_score[t] = 0` for all t without computing individual scores.

**Acceptance criteria**: Soft scores must never make a hard-rejected token valid. With all soft scores at 0.0, the output distribution must be identical to hard-only masking. Soft scores must be additive in logit space (not probability space). Lazy evaluation must be verified: no ControlFlow computation when `control_flow_json` is null.

---

## [SPEC-05.03] Distribution Preservation (ASAp-Style Composition)

Naive hard masking distorts the LLM's conditional distribution: after masking, the renormalized probabilities do not equal the LLM's true conditional probabilities given the grammar (Grammar-Aligned Decoding, NeurIPS 2024).

ASAp (Aligned Sampling with ASp) corrects this by computing:

```
p_aligned(t | prefix, grammar) = p_LLM(t | prefix) * I[t in grammar] / Z
```

where `Z = sum over valid tokens of p_LLM(t | prefix)`.

This is exactly what standard masked sampling does -- the key insight from ASAp is that this is already the correct conditional distribution **if** the grammar is unambiguous and the masking is exact. The distortion arises from approximate masking or from multi-domain composition where domains interact.

For multi-domain hard composition, the correct approach is:

1. Compute the exact intersection mask ([SPEC-05.01]).
2. Apply the mask to logits (set invalid to -inf).
3. Let softmax renormalize over valid tokens only.

This produces the exact conditional `p(t | prefix, all_hard_constraints)` without distortion, provided each hard domain's mask is exact (which it is for Earley/PDA syntax, prefix automata types, and vocabulary subset imports).

For soft domain composition, additive logit adjustment ([SPEC-05.02]) is a deliberate distribution modification (not a distortion) -- we intentionally bias toward convention/semantic conformance.

**Acceptance criteria**: Hard-only masking must produce identical rankings to the LLM's base distribution restricted to valid tokens. A test must verify this by comparing: (a) mask then softmax vs. (b) softmax then filter -- they must produce identical distributions up to floating-point tolerance (1e-6). Multi-domain hard composition must be a single intersection, not sequential masking.

---

## [SPEC-05.04] CRANE-Style Adaptive Switching

Strictly enforcing grammar constraints during chain-of-thought reasoning degrades generation quality by up to 10 percentage points (CRANE, ICML 2025). The solution: apply constraints only to structured output tokens, not reasoning tokens.

Detection of reasoning vs. structured output:

| Signal | Classification |
|--------|---------------|
| Inside `<thinking>` / `<reasoning>` tags | Reasoning -- relax to NONE |
| Inside code fence (` ``` `) | Structured output -- apply current intensity |
| After "Here is the implementation:" or similar transition | Structured output -- apply current intensity |
| Free-form text response | Reasoning -- relax to SYNTAX_ONLY |

The switching mechanism:

1. Track a `constraint_active: bool` state per generation.
2. On each token, check if we have entered/exited a structured output region.
3. When `constraint_active = false`, apply SYNTAX_ONLY at most (ensure valid token boundaries but do not enforce types/imports).
4. When `constraint_active = true`, apply the full intensity level.

Switching must be conservative: when in doubt, classify as structured output (constraints on). False positives (unnecessary constraints during reasoning) are less harmful than false negatives (missing constraints during code output).

This feature is opt-in via `--adaptive-switching` or `adaptive_switching = true` in `.ananke.toml`. Default is off (all tokens constrained) for predictability.

**Acceptance criteria**: With adaptive switching enabled, tokens inside `<thinking>` tags must not be constrained beyond SYNTAX_ONLY. Tokens inside code fences must be fully constrained. Switching latency must be < 1us/token (string matching on boundary markers). The feature must be completely inert when disabled.

---

## [SPEC-05.05] Fill-in-the-Middle Support

FIM (fill-in-the-middle) is the most common IDE completion scenario. The generated code must be syntactically valid not in isolation but in the context of existing prefix and suffix code.

Following Ugare et al. (2024), the syntax grammar is quotiented by the surrounding context:

1. **Left-quotient by prefix**: Parse the prefix through the grammar. The resulting parser state defines what continuations are grammatically valid after the prefix.
2. **Right-quotient by suffix**: Parse the suffix backward (or use the suffix to constrain what the generated code must eventually lead into). The resulting constraint defines what the generated code must end with to connect to the suffix.
3. **Intersection**: The generated code must satisfy both the left-quotient (valid after prefix) and right-quotient (valid before suffix) simultaneously.

For the type domain, FIM means the generated code must inhabit the type expected at the hole position. The prefix provides the left type context (e.g., expected argument type); the suffix provides the right type context (e.g., the expression the result feeds into).

FIM is activated via the `--fim` flag ([SPEC-02.06]):

```bash
ananke generate --fim --prefix "def sort(items):\n    " --suffix "\n    return items" --language python
```

The syntax domain receives both prefix and suffix. The type domain receives the expected type at the hole (inferred from prefix + suffix context). Import and soft domains operate normally.

Grammar quotienting may fail for complex language constructs (e.g., C++ template syntax, Haskell layout rules). When quotienting fails, fall back to syntax-only without FIM context and emit a warning.

**Acceptance criteria**: FIM-constrained generation must produce code that, when inserted between prefix and suffix, forms a syntactically valid program. A test must verify this for Python, JavaScript, and Rust. Left-quotient failure must degrade gracefully to prefix-only constraint. Right-quotient failure must degrade to left-quotient-only. Both failing must degrade to standard (non-FIM) syntax constraint.

---

## [SPEC-05.06] Call Graph Context Inlining

Following InlineCoder (January 2026), the generation prompt includes the hole's position within its call graph for maximum context:

**Upstream inlining**: Embed the function being generated into its callers. The prompt shows how the function is called, providing:
- Expected argument types from call sites
- Expected return value usage
- Error handling expectations from caller context

**Downstream retrieval**: Include the signatures and docstrings of functions called by the function being generated. This provides:
- Available API surface
- Expected patterns from dependency contracts
- Type constraints from called function signatures

Homer's call graph provides the edges. Clew provides the content at each node. The combined context is structured, not flat:

```
--- Callers of generate_report() ---
def dashboard_view(request):
    report = generate_report(request.user, format="pdf")  # <-- call site
    return HttpResponse(report, content_type="application/pdf")

--- Function to implement ---
def generate_report(user: User, format: str = "html") -> bytes:
    # <<< HOLE >>>

--- Called by generate_report() ---
def fetch_data(user: User) -> ReportData: ...
def render_template(data: ReportData, format: str) -> bytes: ...
```

Context budget allocation:
- Upstream callers: up to 3 callers, most recent call sites preferred
- Downstream callees: up to 5 callees, direct calls only (not transitive)
- Total call graph context: at most 30% of the prompt token budget

These limits are configurable in `.ananke.toml`:

```toml
[context]
max_upstream_callers = 3
max_downstream_callees = 5
call_graph_budget_pct = 30
```

**Acceptance criteria**: The generation prompt must include at least one upstream caller and its call site when available. Callee signatures must be included when available. Context budget must be respected -- call graph context must not exceed the configured percentage. Missing call graph data (no Homer, new function with no callers) must not cause errors or empty prompts.

---

## [SPEC-05.07] Performance Budget

The constraint system must not be the bottleneck. GPU inference dominates latency (~10ms/token for typical models). The constraint pipeline runs on CPU, overlapped with GPU computation.

Per-domain latency targets:

| Component | Budget | Technique |
|-----------|--------|-----------|
| Syntax mask (Earley/PDA) | ~50us/token | llguidance derivre + Earley; XGrammar adaptive cache |
| Type mask (prefix automata) | ~100-200us/token | PLDI 2025 inhabitation search with state caching |
| Import mask (vocab subset) | ~10us/token | Precomputed scope-graph to vocab filter; bloom filter for fast rejection |
| ControlFlow score | ~50us/token | CFG analysis on partial AST; cached per scope change |
| Semantic score | ~100us/token | TF-IDF or learned surrogate; cached per sentence boundary |
| Domain fusion | ~10us/token | Bitwise AND (hard) + vectorized addition (soft) |
| **Total (FULL)** | **~500us-2ms/token** | **Hidden behind GPU inference (~10ms/token)** |

Homer queries (~100-300ms total via MCP) are amortized over the entire generation, not per-token. For a 100-token generation, Homer overhead is < 3% of total latency.

Critical performance invariant: `total_constraint_time_per_token < gpu_forward_pass_time`. As long as this holds, constrained decoding has **zero throughput overhead** versus unconstrained decoding. The constraint pipeline must never block the GPU.

If constraint computation exceeds the per-token budget, the system must shed domains in reverse priority order: Semantics, ControlFlow, Imports, Types, leaving Syntax as the floor. This is the same cascade as the unsatisfiability fallback in [SPEC-05.01], but triggered by latency rather than emptiness.

**Acceptance criteria**: Each domain must be independently benchmarked and must meet its latency target on a reference machine (to be specified in CI). The FULL intensity constraint pipeline must complete in < 2ms/token on the reference machine. Latency-triggered domain shedding must activate when per-token time exceeds 80% of the GPU forward pass time (configurable). A performance regression test must prevent merging changes that increase any domain's latency by > 20%.

---

## References

- Grammar-Aligned Decoding / ASAp: NeurIPS 2024 -- distribution preservation under grammar constraints
- CRANE: ICML 2025 -- adaptive constraint switching, 10pp quality improvement on reasoning tasks
- FIM Constrained Decoding: Ugare et al. 2024 -- left/right quotienting of CFGs
- InlineCoder: January 2026 -- call graph context inlining, 49% improvement on RepoExec
- PLDI 2025 (ETH Zurich): prefix automata for type-constrained generation
- SMC for Constraint Composition: ICLR 2025 Oral -- multiplicative constraint factors
- llguidance: Microsoft/OpenAI (May 2025) -- derivre + Earley, ~50us/token baseline
- XGrammar 2 TagDispatch: January 2026 -- dynamic grammar fragment switching
- Code Graph Models: NeurIPS 2025 -- graph structure as attention bias
