# Paper reproduction runbook

Exact ASAX submission commands to reproduce every row of the EM-LLM paper's
main tables (Fountas et al., ICLR 2025).

The paper reports different EM-LLM **variants** per base model. The repo's
`_paper_variants.sh` helper auto-applies the correct variant when you set
`MODEL=...`, so you usually don't need to set `VARIANT` explicitly. The one
exception is LLaMA-3.1, which appears in *two* paper tables under *two*
variants (S and SM); you need to submit both.

All commands assume you've already:
1. Cloned the repo into `$SCRATCH/repro-track`
2. Created the conda env via `bash reproduction/scripts/shell/00_env_setup.sh`
3. Run `huggingface-cli login` and accepted gating for Mistral/Llama models
4. Pre-downloaded weights via `bash reproduction/scripts/shell/00b_login_node_prep.sh`
5. Downloaded benchmarks via `bash reproduction/scripts/shell/01_download_data.sh`
6. Sourced `reproduction/scripts/env/asax.env` in your login-node shell

See `docs/asax_setup.md` for the per-job `run_script` prompt answers
(class, GPUs, walltime, memory).

## Reproduction matrix

| # | Benchmark | Base model | Variant | Paper anchor | Submit command | Lands in |
|---|-----------|-----------|---------|--------------|----------------|----------|
| 1 | LongBench | Mistral-7B-v2 | SM+C | Table 2 row 1 | `MODEL=mistral run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/mistral_sm_c/` |
| 2 | LongBench | LLaMA-3-8B | S, γ=2 | Table 2 row 2 | `MODEL=llama3 run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/llama3_s/` |
| 3 | LongBench | LLaMA-3.1-8B | SM | Table 2 row 3 | `MODEL=llama31 run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/llama31_sm/` |
| 4 | LongBench | LLaMA-3.1-8B | S | Table 1 (per-task) | `MODEL=llama31 VARIANT=s run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/llama31_s/` |
| 5 | LongBench | Phi-3-mini | S | Table 2 row 4 | `MODEL=phi3_mini run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/phi3_mini_s/` |
| 6 | LongBench | Phi-3.5-mini | S | Table 2 row 5 | `MODEL=phi35_mini run_script reproduction/scripts/asax/longbench.sh` | `results/asax/longbench/phi35_mini_s/` |
| 7 | ∞-Bench | Mistral-7B-v2 | SM+C | Table 2 row 1 | `MODEL=mistral run_script reproduction/scripts/asax/infinitebench.sh` | `results/asax/infinitebench/mistral_sm_c/` |
| 8 | ∞-Bench | LLaMA-3-8B | S, γ=2 | Table 2 row 2 | `MODEL=llama3 run_script reproduction/scripts/asax/infinitebench.sh` | `results/asax/infinitebench/llama3_s/` |
| 9 | ∞-Bench | LLaMA-3.1-8B | SM | Table 2 row 3 | `MODEL=llama31 run_script reproduction/scripts/asax/infinitebench.sh` | `results/asax/infinitebench/llama31_sm/` |
| 10 | ∞-Bench | LLaMA-3.1-8B | S | Table 1 (per-task) | `MODEL=llama31 VARIANT=s run_script reproduction/scripts/asax/infinitebench.sh` | `results/asax/infinitebench/llama31_s/` |
| 11 | Passkey 1M | Mistral-7B-v2 | S | Figure 2 right | `MODEL=mistral EXTENDED_PASSKEY_K=1024 run_script reproduction/scripts/asax/passkey_10m.sh` | `results/asax/passkey_1024k/mistral_s/` |
| 12 | Passkey 10M | Mistral-7B-v2 | S | Figure 2 right | `MODEL=mistral EXTENDED_PASSKEY_K=10240 run_script reproduction/scripts/asax/passkey_10m.sh` | `results/asax/passkey_10240k/mistral_s/` |

12 EM-LLM runs above. LongBench and ∞-Bench rows for Phi-3 / Phi-3.5 are LongBench-only
(paper does not report ∞-Bench numbers for the 4B models in Table 2).

## InfLLM baseline rows

These reproduce the **InfLLM** column from paper Table 2 — the baseline EM-LLM
is compared against. Requires `infllm-model/` to be populated first; see
`docs/infllm_setup.md` for the clone + setup steps.

| # | Benchmark | Base model | Budget | Paper anchor | Submit command | Lands in |
|---|-----------|-----------|--------|--------------|----------------|----------|
| 13 | LongBench | Mistral-7B-v2 | 4K+2K | Table 2 row 1 (InfLLM col) | `MODEL=mistral run_script reproduction/scripts/asax/longbench_infllm.sh` | `results/asax/longbench_infllm/mistral_4k_2k/` |
| 14 | LongBench | LLaMA-3-8B | 4K+4K | Table 2 row 2 (InfLLM col) | `MODEL=llama3 run_script reproduction/scripts/asax/longbench_infllm.sh` | `results/asax/longbench_infllm/llama3_4k_4k/` |
| 15 | LongBench | LLaMA-3.1-8B | 4K+4K | Table 2 row 3 (InfLLM col) | `MODEL=llama31 run_script reproduction/scripts/asax/longbench_infllm.sh` | `results/asax/longbench_infllm/llama31_4k_4k/` |
| 16 | LongBench | Phi-3-mini | 1K+3K | Table 2 row 4 (InfLLM col) | `MODEL=phi3_mini run_script reproduction/scripts/asax/longbench_infllm.sh` | `results/asax/longbench_infllm/phi3_mini_1k_3k/` |
| 17 | LongBench | Phi-3.5-mini | 1K+3K | Table 2 row 5 (InfLLM col) | `MODEL=phi35_mini run_script reproduction/scripts/asax/longbench_infllm.sh` | `results/asax/longbench_infllm/phi35_mini_1k_3k/` |
| 18 | ∞-Bench | Mistral-7B-v2 | 4K+2K | Table 2 row 1 (InfLLM col) | `MODEL=mistral run_script reproduction/scripts/asax/infinitebench_infllm.sh` | `results/asax/infinitebench_infllm/mistral_4k_2k/` |
| 19 | ∞-Bench | LLaMA-3-8B | 4K+4K | Table 2 row 2 (InfLLM col) | `MODEL=llama3 run_script reproduction/scripts/asax/infinitebench_infllm.sh` | `results/asax/infinitebench_infllm/llama3_4k_4k/` |
| 20 | ∞-Bench | LLaMA-3.1-8B | 4K+4K | Table 2 row 3 (InfLLM col) | `MODEL=llama31 run_script reproduction/scripts/asax/infinitebench_infllm.sh` | `results/asax/infinitebench_infllm/llama31_4k_4k/` |

8 InfLLM runs total. No ∞-Bench rows for Phi-3 / Phi-3.5 (paper does not
report them). No Passkey-extended InfLLM row (paper Figure 2 shows InfLLM
in the curve but not as a tabulated number — would belong in extensions/).

## Combined reproduction = 20 runs

Suggested submission order (cheapest smoke tests first, headline runs last):

1. EM-LLM LongBench Mistral (#1) — fastest, validates pipeline
2. InfLLM LongBench Mistral (#13) — validates the InfLLM pipeline
3. Remaining EM-LLM LongBench rows (#2-6)
4. Remaining InfLLM LongBench rows (#14-17)
5. EM-LLM ∞-Bench rows (#7-10)
6. InfLLM ∞-Bench rows (#18-20)
7. Passkey 1M (#11) then 10M (#12) — slowest, run last

After all 20 finish, the `summary.md` in each results dir gives you the
side-by-side; the aggregator notebook in `reproduction/analysis/` (to be
written) can merge them into one cross-method, cross-model table.

## What "Variant" actually changes

| Tag | OmegaConf flags injected |
|-----|--------------------------|
| `s` | `similarity_refinement=false`, `use_contiguity_buffer=false` (matches upstream defaults) |
| `sm` | `similarity_refinement=true`, `use_contiguity_buffer=false` |
| `s_c` | `similarity_refinement=false`, `use_contiguity_buffer=true` |
| `sm_c` | `similarity_refinement=true`, `use_contiguity_buffer=true` |

Plus LLaMA-3 gets `surprisal_threshold_gamma=2` (paper Appendix lists γ per
model: 1, 2, 1, 1, 1 for Mistral, LLaMA-3, LLaMA-3.1, Phi-3, Phi-3.5).

Context budgets (`n_local + n_mem`) are baked into upstream's
`em-llm-model/config/<model>.yaml` and are correct for the paper as-is:

| Model | n_local | n_mem | Notation |
|-------|--------:|------:|----------|
| Mistral | 4096 | 2048 | 4K + 2K |
| LLaMA-3 | 4096 | 4096 | 4K + 4K |
| LLaMA-3.1 | 4096 | 4096 | 4K + 4K |
| Phi-3 | 1024 | 3072 | 1K + 3K |
| Phi-3.5 | 1024 | 3072 | 1K + 3K |

## What lands in each results directory

```
$SCRATCH/repro-track/reproduction/results/asax/<benchmark>/<model>_<variant>/
├── result.json           upstream eval.py output, the headline metric per task
├── <task>.jsonl          raw per-example predictions (gitignored; large)
├── summary.md            paper side-by-side, markdown
└── summary.csv           paper side-by-side, CSV
```

Plus per-job logs in `reproduction/results/asax/logs/`.

## What's NOT reproduced here

`em-llm-model/` only implements the EM-LLM method. The paper also reports
**InfLLM** and **RAG (NV-Embed-v2)** and **Full-Context** baselines, which we
cite from `further_results.md` rather than re-run. To re-run those baselines,
add them under `extensions/` (would count as TMLR Repro-Cert "added value").

## After all runs finish

1. Verify the matrix is complete:
   ```bash
   find reproduction/results/asax -name result.json | sort
   ```
   Should show 12 entries matching the table above.

2. Re-generate any stale summaries (e.g. after editing `paper_baselines.py`):
   ```bash
   for d in $(find reproduction/results/asax -name result.json -printf '%h\n'); do
       python reproduction/analysis/make_summary.py "$d"
   done
   ```

3. Pull results back to local for analysis:
   ```bash
   rsync -av <user>@<asax-login>:$SCRATCH/repro-track/reproduction/results/asax/ \
       ./reproduction/results/asax/
   ```

4. Aggregate the per-run summaries into a single comparison table for the
   manuscript (notebook in `reproduction/analysis/` once written).
