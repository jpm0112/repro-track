# Reproducing EM-LLM: Human-inspired Episodic Memory for Infinite Context LLMs

Reproduction study for the **MLRC 2026 / NeurIPS 2026 Reproducibility Track**, targeting Fountas et al. (ICLR 2025), [*Human-inspired Episodic Memory for Infinite Context LLMs*](https://openreview.net/forum?id=BI2int5SAC). Submission flows through TMLR first per the [MLRC 2026 call for papers](https://reproml.org/call_for_papers/).

The upstream code lives untouched under [`em-llm-model/`](em-llm-model/), pinned to commit recorded in [`docs/upstream_commit.md`](docs/upstream_commit.md). Faithful reproduction is verified by `git diff em-llm-model/` returning empty.

## Layout

```
repro-track/
├── em-llm-model/            # upstream EM-LLM, NEVER MODIFIED
├── papers/                  # paper-search artifacts (PDFs + candidate list)
├── reproduction/            # verification: configs, scripts, results, analysis
│   ├── configs/{local,asax}/    OmegaConf overrides per backend
│   ├── scripts/env/             system-specific env vars (sourced before runs)
│   ├── scripts/shell/           system-agnostic wrappers around upstream entrypoints
│   ├── scripts/slurm/           ASAX-only sbatch submission files
│   ├── results/{local,asax}/    raw outputs by system + benchmark + model
│   └── analysis/                comparison artifacts
├── extensions/              # ablations, baselines, insights (TMLR Repro Cert)
├── docs/                    # reproduction notes, hardware adaptations, ASAX setup
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

# ASAX
sbatch reproduction/scripts/slurm/longbench.sbatch
```

Full reproduction matrix (filled in as runs complete):

| Benchmark | Model | Their result | Our result (local) | Our result (ASAX) |
|-----------|-------|--------------|--------------------|--------------------|
| LongBench (avg) | Mistral-7B-Instruct-v0.2 | — | — | — |
| LongBench (avg) | Llama-3-8B-Instruct | — | — | — |
| LongBench (avg) | Llama-3.1-8B-Instruct | — | — | — |
| LongBench (avg) | Phi-3-mini-128k | — | — | — |
| LongBench (avg) | Phi-3.5-mini | — | — | — |
| ∞-Bench (avg) | Mistral-7B-Instruct-v0.2 | — | — | — |
| Passkey 1M | Mistral-7B-Instruct-v0.2 | — | infeasible | — |
| Passkey 10M | Mistral-7B-Instruct-v0.2 | — | infeasible | — |

Compare against the per-task numbers in `em-llm-model/benchmark/further_results.md`. Within ±1.5 points per task is a clean reproduction at this scale.

## Extensions and added value

TMLR's [Reproducibility Certification](https://jmlr.org/tmlr/editorial-policies.html) requires "significant added value through additional baselines, analysis, ablations, or insights" beyond pure verification. Those live in `extensions/` and are listed here once present.

## What is *not* changed

`em-llm-model/` is byte-identical to the [upstream commit](docs/upstream_commit.md). All hardware adaptations flow through OmegaConf CLI overrides applied at runtime; no upstream file is edited. Verify with:

```bash
git diff em-llm-model/        # empty
```

## License

Wrapper code (this repository): [MIT](LICENSE).
Upstream EM-LLM (`em-llm-model/`): MIT, retained from the upstream repository.

## Citing

See `CITATION.cff`. If you cite this work, also cite the original EM-LLM paper (BibTeX in `em-llm-model/README.md`).
