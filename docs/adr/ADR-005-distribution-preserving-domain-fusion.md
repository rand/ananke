# ADR-005: Distribution-Preserving Domain Fusion

## Status
Proposed

## Context
Composing multiple constraint domains into a single per-token decision is the central algorithmic challenge of multi-domain constrained decoding. The naive approach -- intersecting all domain masks -- has been shown to distort the LLM's probability distribution (Grammar-Aligned Decoding, NeurIPS 2024). Specifically, naive masking changes the conditional distribution `p(x|grammar)` in ways that bias toward shorter or more common tokens, degrading generation quality even when the output is technically valid.

Additionally, CRANE (ICML 2025) demonstrates that strictly enforcing structural constraints during reasoning/planning tokens degrades quality by up to 10 percentage points. The model needs freedom to "think" before committing to structured output.

A principled fusion strategy must:
1. Preserve the LLM's conditional distribution shape within the valid token set.
2. Compose hard and soft domains using semantically appropriate operators.
3. Allow the model to reason freely when not producing structured output.

## Decision
Three-part fusion architecture:

**1. Hard domains compose by exact intersection.**
```
valid_tokens = syntax_mask AND type_mask AND import_mask
```
This is exact -- a token that violates any hard domain IS invalid. There is no weighting or approximation. The intersection defines the feasible set.

**2. Soft domains compose by additive logit reweighting within the feasible set.**
```
logits[t] = base_logits[t] + alpha * controlflow_score[t] + beta * semantic_score[t]
    for all t in valid_tokens
```
This preserves the conditional distribution shape (ASAp insight from Grammar-Aligned Decoding): the relative ordering of tokens within the feasible set is adjusted by additive bias, not multiplicative masking. Soft scores guide the model toward convention-conformant and semantically appropriate tokens without eliminating any hard-valid option.

**3. CRANE-style adaptive switching disables constraints during reasoning tokens.**
During chain-of-thought or planning tokens, relax to SYNTAX_ONLY intensity. During structured output tokens, apply the full constraint intensity (STANDARD through EXHAUSTIVE). The switching boundary is determined by output format markers (e.g., code fence delimiters, JSON structure boundaries).

## Consequences

**Positive:**
- Hard constraint intersection is mathematically exact: no valid token is wrongly excluded, no invalid token is wrongly included.
- Additive logit reweighting for soft domains preserves the LLM's learned distribution shape, avoiding the distribution distortion that naive masking causes.
- Soft domain noise is bounded: worst case is suboptimal token ranking within the feasible set, never generation failure.
- CRANE-style switching prevents constraint interference with the model's reasoning process, maintaining quality on tasks that require planning before generating code.
- Each component is independently testable: hard intersection can be verified with exact token sets, soft reweighting can be verified with logit comparisons, adaptive switching can be verified with format-marker detection.

**Negative:**
- Soft weight parameters (alpha, beta) require tuning. Poor weights degrade generation quality (too high biases away from the model's knowledge; too low provides no guidance).
- Adaptive switching introduces a classification problem: determining which tokens are "reasoning" vs "structured output" is not always clear-cut, especially in mixed-format responses.
- Additive reweighting assumes soft scores are calibrated on a comparable scale to LLM logits. Miscalibrated scores have outsized or negligible effect.
- The approach does not handle deep constraint interactions (e.g., where the optimal token for ControlFlow is terrible for Semantics). Future SMC-based composition could address this.

## Alternatives Considered

**Naive intersection of all domains:** Treat all five domains as hard and intersect their masks. Rejected because: (a) Grammar-Aligned Decoding (NeurIPS 2024) proves this distorts the conditional distribution; (b) soft domains (ControlFlow, Semantics) do not have exact token masks -- they have graded scores; (c) intersection of five masks can produce extremely sparse or empty feasible sets, causing generation failure.

**SMC-based particle composition:** Sequential Monte Carlo treats each constraint domain as a multiplicative factor in a probabilistic program, using particles to explore the joint distribution (ICLR 2025 Oral). Theoretically superior for handling complex multi-domain interactions. Rejected as the initial approach because: (a) SMC adds significant per-token computational cost; (b) the simpler additive reweighting is adequate when hard/soft separation is maintained; (c) SMC is better suited as a future refinement for cases where soft domain interactions are complex. Reserved for future work.

**Single unified grammar:** Compile all constraints into a single grammar (or automaton) that captures all five domains simultaneously. Rejected because: (a) the product automaton of five domain grammars has exponential state space; (b) soft constraints are not naturally expressible as grammars; (c) a single grammar loses the compositional structure that enables independent domain development and adaptive intensity.

## References
- Grammar-Aligned Decoding (ASAp), NeurIPS 2024 -- proves naive masking distorts conditional distributions; proposes distribution-preserving composition
- CRANE: Adaptive Constraint Switching, ICML 2025 -- shows strict constraints during reasoning degrades quality by up to 10pp; proposes adaptive switching
- Sequential Monte Carlo for Constrained LLMs, ICLR 2025 Oral -- particle-based multi-constraint composition
- Integration plan: Phase 5A (Domain Fusion Architecture)
- Integration plan: Performance Model section
