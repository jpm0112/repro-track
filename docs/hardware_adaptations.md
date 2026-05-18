# Hardware adaptations

This document records every override applied at runtime that deviates from the
paper's exact configuration, the reason it was needed, and the expected impact
on results. Reviewers use this to judge whether result discrepancies have a
hardware-induced cause.

**Invariant:** every override is applied via OmegaConf CLI args at invocation.
No file under `em-llm-model/` is edited.

## Local backend (RTX 3090, 32 GB RAM)

### Long-context CPU offload (∞-Bench long tasks, PassKey extended)

| field | upstream default | local override | reason |
|-------|------------------|----------------|--------|
| `model.min_free_cpu_memory` | 100 (GB) | 8 | Upstream default exceeds available RAM (32 GB). Triggering CPU-cache allocation at 100 GB GBs OOMs immediately (`em-llm-model/em_llm/attention/context_manager.py:425`) |
| `model.disk_offload_threshold` | 300000 | 200000 | Lowered so disk-offload activates earlier, keeping the active CPU cache footprint manageable |
| `model.vector_offload_threshold` | 50000 | 30000 | Representative-token tensor moves to CPU sooner; small RAM cost reduction |
| `model.disk_offload_dir` | `./offload_data` | `$EMLLM_OFFLOAD_DIR` (defaults to `/tmp/emllm_offload`) | Keep upstream's tree clean; route offload to a path the wrappers control |

Expected impact: **outputs should match exactly** (these are runtime memory
management choices that don't affect numerical computations). Throughput
differs.

### LongBench

No overrides applied. The LongBench max context (≤ 200K) stays under
`disk_offload_threshold=300000` so the CPU-cache code path is never entered.

## ASAX backend (A100 / H100, hundreds of GB RAM)

### All benchmarks

| field | upstream default | ASAX override | reason |
|-------|------------------|---------------|--------|
| `model.disk_offload_dir` | `./offload_data` | `$EMLLM_OFFLOAD_DIR` (= `$SCRATCH/emllm_offload/$SLURM_JOB_ID`) | Per-job scratch path on Lustre/BeeGFS; avoids cross-job collisions and home-dir quota issues |

No other overrides — ASAX hardware satisfies upstream defaults verbatim. This
is the highest-fidelity execution path and is the source of truth for the
reproduction.

## Paper-faithful overrides (NOT hardware adaptations)

The upstream `config/<model>.yaml` files all default to EM-LLM variant **S**
(no refinement, no contiguity buffer) with `surprisal_threshold_gamma=1.0`.
But the paper's main Tables 1 and 2 use different variants and γ values per
base model. To run paper-faithful reproductions, the wrappers inject these
overrides via `_paper_variants.sh`:

| Model | Paper Table 2 variant | γ | OmegaConf overrides applied |
|-------|----------------------|---|-----------------------------|
| Mistral | SM+C | 1 | `similarity_refinement=true`, `use_contiguity_buffer=true` |
| LLaMA-3 | S | **2** | `surprisal_threshold_gamma=2` |
| LLaMA-3.1 | SM | 1 | `similarity_refinement=true` |
| Phi-3 | S | 1 | none (matches upstream default) |
| Phi-3.5 | S | 1 | none (matches upstream default) |

LLaMA-3.1 is also reproduced under variant **S** for the paper Table 1 row
(per-task vs Full-Context comparator). See `docs/paper_reproduction_runbook.md`
for the exact submission commands per paper row.

These are not "hardware adaptations" — they are the paper's reported settings.
They do not appear above because they don't differ between local and ASAX.

## Things explicitly *not* changed

- `n_init`, `n_local`, `n_mem`, `min_block_size`, `max_block_size`,
  `repr_topk`, `chunk_size`, `exc_block_size`, `base`, `distance_scale`,
  `refine_from_layer`, `similarity_metric`, `contiguity_buffer_size`,
  `repr_topk` — every architectural parameter is taken verbatim from the
  upstream `config/<model>.yaml`.
- `em_splitter`, `compute_ppl`, `extended_passkey` (when applicable) —
  per-benchmark settings unchanged.

If a hyperparameter sweep is added later as a TMLR-Reproducibility-Cert
"added value", it lives in `extensions/` and does not contaminate the
verification numbers in `reproduction/results/`.
