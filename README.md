# Reproducing EM-LLM: Human-inspired Episodic Memory for Infinite Context LLMs

Reproduction study for the **MLRC 2026 / NeurIPS 2026 Reproducibility Track**, targeting Fountas et al. (ICLR 2025), [*Human-inspired Episodic Memory for Infinite Context LLMs*](https://openreview.net/forum?id=BI2int5SAC). Submission flows through TMLR first per the [MLRC 2026 call for papers](https://reproml.org/call_for_papers/).

The upstream code lives untouched under [`em-llm-model/`](em-llm-model/), pinned to commit recorded in [`docs/upstream_commit.md`](docs/upstream_commit.md). Faithful reproduction is verified by `git diff em-llm-model/` returning empty.

The InfLLM baseline (paper Table 2 comparator) lives as a sibling vendored repo under [`infllm-model/`](infllm-model/); see [`docs/infllm_setup.md`](docs/infllm_setup.md) to populate it.

## Layout

```
repro-track/
├── em-llm-model/            # upstream EM-LLM, NEVER MODIFIED
├── infllm-model/            # upstream InfLLM (paper Table 2 baseline), NEVER MODIFIED
├── papers/                  # paper-search artifacts (PDFs + candidate list)
├── reproduction/            # verification: configs, scripts, results, analysis
│   ├── configs/{local,asax}/    OmegaConf overrides per backend
│   ├── scripts/env/             system-specific env vars (sourced before runs)
│   ├── scripts/shell/           system-agnostic wrappers around upstream entrypoints
│   ├── scripts/asax/            ASAX-only `run_script` payloads (resources via run_script flags)
│   ├── results/{local,asax}/    raw outputs by system + benchmark + method + model
│   │                              EM-LLM:  <benchmark>/<model>_<variant>/
│   │                              InfLLM:  <benchmark>_infllm/<model>_<budget>/
│   │                              each dir: result.json + summary.md/csv per run
│   └── analysis/                paper_baselines.py + make_summary.py + cross-system notebooks
├── extensions/              # ablations, additional baselines (TMLR Repro Cert)
├── docs/                    # reproduction notes, ASAX/InfLLM setup, hardware adaptations
└── manuscript/              # TMLR + ReScience C sources
```

## Requirements

Two execution backends are supported, sharing identical scripts:

| Backend | OS / shell | GPUs | RAM | Env file |
|---------|-----------|------|-----|----------|
| Local | WSL2 Ubuntu | 1× RTX 3090 (24 GB) | 32 GB | `environment.local.yml` |
| ASAX | Linux + SLURM | A100 / H100 (1-4×) | hundreds of GB | `environment.asax.yml` |

Pick the one matching your machine, then:

```bash
conda env create -f environment.${SYSTEM}.yml      # SYSTEM = local | asax
source reproduction/scripts/env/${SYSTEM}.env
bash reproduction/scripts/shell/00_env_setup.sh
huggingface-cli login                              # gated model access
bash reproduction/scripts/shell/01_download_data.sh
```

See `docs/asax_setup.md` for ASAX-specific quirks (login-node prep, modules, scratch quotas).

## Reproducing the paper

Recommended starting point — Mistral × LongBench, no overrides, on either backend:

```bash
# Local
bash reproduction/scripts/shell/02_run_longbench.sh

# ASAX (submission via ASA's run_script wrapper; monitor with qstat)
run_script reproduction/scripts/asax/longbench.sh
```

Full reproduction matrix (20 runs total: 12 EM-LLM + 8 InfLLM baselines).
Submission commands and per-run output paths live in
`docs/paper_reproduction_runbook.md`.

### EM-LLM rows (paper's main method)

| # | Benchmark | Model | Variant | Paper anchor | Their avg | Ours (local) | Ours (ASAX) |
|---|-----------|-------|---------|--------------|----------:|-------------:|------------:|
| 1 | LongBench | Mistral-7B-v2 | SM+C | Table 2 | 43.7 | — | — |
| 2 | LongBench | Llama-3-8B | S, γ=2 | Table 2 | 47.2 | — | — |
| 3 | LongBench | Llama-3.1-8B | SM | Table 2 | 51.3 | — | — |
| 4 | LongBench | Llama-3.1-8B | S | Table 1 (per-task) | 51.58 | — | — |
| 5 | LongBench | Phi-3-mini | S | Table 2 | 35.4 | — | — |
| 6 | LongBench | Phi-3.5-mini | S | Table 2 | 34.9 | — | — |
| 7 | ∞-Bench | Mistral-7B-v2 | SM+C | Table 2 | 66.1 | — | — |
| 8 | ∞-Bench | Llama-3-8B | S, γ=2 | Table 2 | 48.8 | — | — |
| 9 | ∞-Bench | Llama-3.1-8B | SM | Table 2 | 65.7 | — | — |
| 10 | ∞-Bench | Llama-3.1-8B | S | Table 1 (per-task) | 66.66 | — | — |
| 11 | Passkey 1M | Mistral-7B-v2 | S | Figure 2 | 100 | infeasible | — |
| 12 | Passkey 10M | Mistral-7B-v2 | S | Figure 2 | 100 | infeasible | — |

### InfLLM baseline rows (paper Table 2 comparator)

| # | Benchmark | Model | Budget | Paper InfLLM avg | Ours (local) | Ours (ASAX) |
|---|-----------|-------|--------|-----------------:|-------------:|------------:|
| 13 | LongBench | Mistral-7B-v2 | 4K+2K | 41.9 | — | — |
| 14 | LongBench | Llama-3-8B | 4K+4K | 47.0 | — | — |
| 15 | LongBench | Llama-3.1-8B | 4K+4K | 51.1 | — | — |
| 16 | LongBench | Phi-3-mini | 1K+3K | 34.5 | — | — |
| 17 | LongBench | Phi-3.5-mini | 1K+3K | 34.2 | — | — |
| 18 | ∞-Bench | Mistral-7B-v2 | 4K+2K | 65.8 | — | — |
| 19 | ∞-Bench | Llama-3-8B | 4K+4K | 50.2 | — | — |
| 20 | ∞-Bench | Llama-3.1-8B | 4K+4K | 64.0 | — | — |

Compare against the per-task numbers in `em-llm-model/benchmark/further_results.md`. Within ±1.5 points per task is a clean reproduction at this scale.

## Extensions and added value

TMLR's [Reproducibility Certification](https://jmlr.org/tmlr/editorial-policies.html) requires "significant added value through additional baselines, analysis, ablations, or insights" beyond pure verification. Those live in `extensions/` and are listed here once present.

The InfLLM baseline at `infllm-model/` re-verifies paper Table 2's comparator column; the RAG-with-NV-Embed-v2 and Full-Context baselines from paper Table 1 are not currently reproduced and would also belong in `extensions/`.

## What is *not* changed

Both `em-llm-model/` and `infllm-model/` are byte-identical to their pinned upstream commits ([em-llm](docs/upstream_commit.md), [infllm](docs/infllm_commit.md)). All hardware adaptations and paper-variant settings flow through OmegaConf CLI overrides applied at runtime; no upstream file is edited. Verify with:

```bash
git diff em-llm-model/        # empty
git diff infllm-model/        # empty
```

## License

Wrapper code (this repository): [MIT](LICENSE).
Upstream EM-LLM (`em-llm-model/`): MIT, retained from the upstream repository.

## Citing

See `CITATION.cff`. If you cite this work, also cite the original EM-LLM paper (BibTeX in `em-llm-model/README.md`).
