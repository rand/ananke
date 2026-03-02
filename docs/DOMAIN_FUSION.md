# Domain Fusion: 5 Domains, 1 Token

Ananke's CLaSH algebra defines five constraint domains. At every token position,
these five opinions must collapse to a single sampling decision without distorting
the language model's learned distribution. This document describes exactly how.

**Source**: `src/braid/domain_fusion.zig` (13 tests, all passing)

---

## The Problem

Five domains, one token to choose.

Three domains produce binary masks (allowed / not allowed):

| Domain | Tier | What it encodes |
|--------|------|-----------------|
| **Syntax** | Hard | Grammar conformance via Earley parser / PDA |
| **Types** | Hard | Well-typedness of the partial program via prefix automata |
| **Imports** | Hard | Symbol availability from the scope graph |

Two domains produce graded scores in [-1.0, 1.0]:

| Domain | Tier | What it encodes |
|--------|------|-----------------|
| **ControlFlow** | Soft | Error handling, async/await, loop structure patterns |
| **Semantics** | Soft | Behavioral intent: pre/postconditions, invariants |

Hard domains say "this token is impossible." Soft domains say "this token is
better or worse." A score of 0.0 means "no opinion."

The challenge: compose these without warping the probability distribution that
the LLM spent thousands of GPU-hours learning. The model already knows something
about code. Constraints should narrow the search space and nudge preferences, not
bulldoze them.

---

## Hard Domain Fusion -- Intersection

Hard masks compose by intersection. A token must pass every active hard domain to
survive. If Syntax says "yes" but Types says "no," the token is out. No appeals
process.

### Implementation

```
intersectHardMasks(allocator, masks) ![]u32
```

Takes a slice of `DomainMask` structs (each containing a sorted list of allowed
token IDs) and returns their intersection via pairwise merge-intersect.

The algorithm is straightforward: walk two sorted arrays with two pointers,
advance whichever pointer is smaller, emit when they match. O(n+m) per pair,
applied sequentially across all active hard masks.

Memory bandwidth is modest. Each mask is a sorted `[]u32` -- for a typical
vocabulary intersection step, roughly 48KB of data moves through cache. Wall time
lands around 10us per token on current hardware. This matters because it runs on
every token; anything slower would dominate latency.

### The Relaxation Cascade

Sometimes the intersection is empty. This is not a bug in the algorithm -- it
means the hard domains collectively believe no token is valid. In practice, this
usually happens when Import constraints are too tight for the current context
(the scope graph says a symbol isn't available, but the model is about to
introduce it).

When the feasible set is empty, the `fuse()` function sets
`required_relaxation = true` on the `FusionResult`. The caller -- typically the
sglang backend constraint handler -- then applies a relaxation cascade:

1. Drop **Imports** and re-intersect Syntax + Types
2. If still empty, drop **Types** and use Syntax alone
3. If still empty, drop **Syntax** -- but this means the grammar itself
   produced no valid tokens, which indicates a parser bug

Each step removes the least essential hard domain first. Import availability is
the most context-dependent (and the most likely to be wrong). Syntax is the last
to go because if the grammar says no tokens are valid, something is broken
upstream.

The cascade preserves a useful invariant: the output is always syntactically
valid code, or the system knows it has a problem.

---

## Soft Domain Fusion -- Additive Logit Reweighting

Once hard masking produces the feasible set, soft domains rank the survivors.

### Implementation

```
applySoftScores(allocator, feasible_count, scores, config) ![]f32
```

For each token `t` in the feasible set:

```
adjustment[t] = SUM over soft domains d:
    (config_weight_d * domain_weight_d * score_d[t]) / temperature
```

Where:
- `config_weight_d` is `control_flow_weight` or `semantics_weight` from
  `FusionConfig` (both default to 1.0)
- `domain_weight_d` is the per-`DomainScore` weight
- `score_d[t]` is in [-1.0, 1.0]
- `temperature` is `soft_temperature` from `FusionConfig` (default 1.0)

The result is added to the model's base logits before softmax:

```
final_logits[t] = base_logits[t] + adjustment[t]
```

Soft fusion is applied *after* hard masking. This is structural, not
incidental -- it enforces the CLaSH tier invariant. Soft domains never see
tokens that hard domains have already eliminated. They cannot override a hard
"no."

### Why Additive, Not Multiplicative

Multiplicative reweighting in probability space distorts relative token
preferences. If token A has 10x the base probability of token B, a
multiplicative soft score could compress that to 2x or inflate it to 50x,
depending on the scores. The model's learned distribution gets warped in ways
that are hard to reason about.

Additive adjustment in logit space is better behaved. Adding a constant to the
logits of two tokens shifts their log-odds by the same amount. The original
ranking is preserved unless the adjustment is large enough to overcome the
base logit difference -- which is exactly the intended behavior when a soft
domain has a strong opinion. The shape of the conditional distribution is
shifted, not deformed.

---

## Distribution Preservation -- The ASAp Insight

A natural worry: doesn't masking out tokens and renormalizing via softmax
distort the model's distribution?

No. Given an exact domain mask, softmax renormalization over the valid subset
produces the correct conditional distribution p(token | grammar). This is the
core insight from ASAp (Grammar-Aligned Decoding, NeurIPS 2024). The math is
clean: if p(x) is the model's distribution and G is the set of grammatically
valid tokens, then:

```
p(x | x in G) = p(x) / SUM_{y in G} p(y)
```

which is exactly what softmax over the masked logits computes.

Two requirements for this to hold:

1. **Single intersection, not sequential masking.** Applying Syntax masking,
   renormalizing, then applying Types masking, renormalizing again -- this
   compounds approximation error. Each renormalization step conditions on the
   previous mask, not on the full constraint set. Multi-domain hard composition
   must be a single intersection followed by a single renormalization.

2. **Soft fusion in one step.** For the same reason, soft adjustments from
   ControlFlow and Semantics are summed into a single logit delta vector, then
   applied once. No sequential soft application.

The `fuse()` function respects both requirements. Hard masks are intersected in
one pass, soft scores are accumulated in one pass, and the result is a single
`FusionResult` that the backend applies atomically.

---

## CRANE Adaptive Switching

Not every token needs five domains of scrutiny. When the model is reasoning --
planning its approach, working through logic in chain-of-thought -- tight
constraints can interfere with exploration. When it is emitting structured output
(code, JSON), constraints should be fully engaged.

CRANE (ICML 2025) formalizes this as adaptive constraint switching between
generation phases.

### Implementation

```zig
pub const GenerationPhase = enum {
    reasoning,          // chain-of-thought, planning
    structured_output,  // code, JSON, formal content
    transition,         // phase boundaries (e.g., ``` markers)
};
```

```
selectActiveDomains(intensity, phase, adaptive) DomainSet
```

When adaptive switching is enabled:

| Phase | Behavior |
|-------|----------|
| `reasoning` | Relax to syntax-only (let the model think freely) |
| `structured_output` | Apply full intensity as configured |
| `transition` | Apply current intensity |

During the `reasoning` phase, `selectActiveDomains` returns a `DomainSet` with
only `syntax = true` (unless intensity is `none`, in which case everything is
off). Types, Imports, ControlFlow, Semantics -- all suppressed. The model gets
grammatical guardrails and nothing else.

This is conservative by design. When phase detection is uncertain, the system
classifies as `structured_output` (constraints on). It is better to
over-constrain structured output than to under-constrain it; a syntax error in
generated code is worse than a slightly less fluent chain-of-thought.

Adaptive switching is opt-in via `FusionConfig.adaptive_switching` (default:
`true`).

---

## Configuration

```zig
pub const FusionConfig = struct {
    intensity: IntensityLevel = .standard,
    control_flow_weight: f32 = 1.0,
    semantics_weight: f32 = 1.0,
    adaptive_switching: bool = true,
    soft_temperature: f32 = 1.0,
};
```

### Intensity Levels

Intensity selects which domains are active via `DomainSet`, a packed struct with
five boolean flags:

| Level | Active Domains | Latency Budget |
|-------|---------------|----------------|
| `none` | (empty) | 0 us |
| `syntax_only` | {Syntax} | 50 us |
| `standard` | {Syntax, Types} | 200 us |
| `full_hard` | {Syntax, Types, Imports} | 500 us |
| `full` | all 5 | 2,000 us |
| `exhaustive` | all 5 | 5,000 us |

`full` and `exhaustive` activate the same domain set. The difference is
downstream: `exhaustive` allocates a larger latency budget (5ms vs 2ms per
token), allowing more thorough constraint evaluation. The domain fusion module
itself does not distinguish between them -- that distinction lives in the
salience-driven scheduling layer.

### Serialization

`serializeConfigJson(allocator, config)` produces JSON for the sglang
`constraint_spec` field, allowing the backend to reconstruct fusion parameters
without a Zig runtime.

---

## Per-Token Decision Pipeline

The complete flow for a single token position:

```
Token candidates (full vocabulary)
         |
         v
+-- Hard Fusion ---------------------------------+
|                                                 |
|  Syntax mask  ∩  Types mask  ∩  Imports mask    |
|  --> feasible set (sorted token IDs)            |
|                                                 |
|  If empty: set required_relaxation = true       |
|  Caller applies relaxation cascade:             |
|    1. Drop Imports, re-intersect                |
|    2. Drop Types, Syntax only                   |
|    3. If Syntax empty: parser bug               |
|                                                 |
+--------------------------+----------------------+
                           |
                           v
+-- Soft Fusion ---------------------------------+
|                                                 |
|  For each t in feasible set:                    |
|    adj[t] = w_cf * cf_score[t] / temperature    |
|           + w_sem * sem_score[t] / temperature  |
|                                                 |
+--------------------------+----------------------+
                           |
                           v
              final[t] = base_logits[t] + adj[t]
                           |
                           v
                     softmax(final)
                           |
                           v
                      Sample token
```

---

## The FusionResult Struct

```zig
pub const FusionResult = struct {
    feasible_tokens: []const u32,       // token IDs passing all hard domains
    logit_adjustments: []const f32,     // per-feasible-token soft adjustments
    active_domains: DomainSet,          // which domains were consulted
    required_relaxation: bool,          // whether the cascade was triggered
};
```

`feasible_tokens` and `logit_adjustments` are parallel arrays: `logit_adjustments[i]`
is the soft adjustment for `feasible_tokens[i]`. Both slices are owned by the
caller; `deinitResult(allocator, result)` frees them.

If no soft domains are active (e.g., during CRANE reasoning phase, or at
`standard` intensity), `logit_adjustments` is allocated and zeroed -- same
length, all 0.0. The backend does not need to special-case this.

---

## Key Functions

| Function | Purpose |
|----------|---------|
| `fuse(allocator, hard_masks, soft_scores, config, phase)` | Full pipeline: select domains, intersect, apply soft scores |
| `intersectHardMasks(allocator, masks)` | Merge-intersect sorted token ID lists |
| `applySoftScores(allocator, feasible_count, scores, config)` | Weighted additive logit adjustment |
| `selectActiveDomains(intensity, phase, adaptive)` | CRANE-style domain selection |
| `deinitResult(allocator, result)` | Free owned slices from a FusionResult |
| `serializeConfigJson(allocator, config)` | JSON for sglang constraint_spec |

---

## References

- **SPEC-05**: Domain Fusion and Performance
- **ADR-005**: Distribution-Preserving Domain Fusion
- **ASAp**: Grammar-Aligned Decoding (NeurIPS 2024) -- proves that
  mask-then-renormalize yields the exact conditional distribution
- **CRANE**: Adaptive constraint switching (ICML 2025) -- phase-aware
  constraint relaxation during reasoning
- Source: `src/braid/domain_fusion.zig` (13 tests)
- Salience integration: `src/braid/salience.zig` (IntensityLevel, latency budgets)
