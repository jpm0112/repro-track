# InfLLM baseline setup

The paper compares EM-LLM against **InfLLM** (Xiao et al., NeurIPS 2024) at
matched context budgets. EM-LLM is itself a fork of InfLLM, so the benchmark
pipeline is the same; only the segmentation strategy differs (InfLLM uses
uniform fixed-size blocks; EM-LLM uses surprise-based + refined blocks).

This doc covers cloning InfLLM, running it through the same benchmarks the
EM-LLM reproduction uses, and getting paper-comparable numbers.

## One-time setup

```bash
# 1. Clone InfLLM into the sibling directory at the repo root.
cd $SCRATCH/repro-track    # or wherever the repo lives
rm -rf infllm-model
git clone https://github.com/thunlp/InfLLM infllm-model

# 2. Pin the SHA so reviewers can verify identity later.
cd infllm-model
git rev-parse HEAD
# Paste the SHA into docs/infllm_commit.md, fill in the cloned-on date.
cd ..

# 3. Install InfLLM into the same conda env as EM-LLM. The 00_env_setup.sh
#    wrapper now picks this up automatically if infllm-model/ exists.
conda activate emllm
bash reproduction/scripts/shell/00_env_setup.sh    # idempotent; re-running is safe
```

## Configs

InfLLM ships its own `config/*.yaml` files in `infllm-model/config/`. The
key fields are:

```yaml
model:
  type: inf-llm
  path: <hf-model-id>
  n_local: 4096        # local attention window
  n_mem: 2048          # retrieved tokens
  block_size: 128
  topk: 16
  ...
```

Paper-faithful context budgets (Table 2):

| Model | n_local | n_mem | Budget tag |
|-------|--------:|------:|------------|
| Mistral-7B-v2 | 4096 | 2048 | 4k_2k |
| Llama-3-8B | 4096 | 4096 | 4k_4k |
| Llama-3.1-8B | 4096 | 4096 | 4k_4k |
| Phi-3-mini | 1024 | 3072 | 1k_3k |
| Phi-3.5-mini | 1024 | 3072 | 1k_3k |

If `infllm-model/config/<model>.yaml` doesn't exist for one of the five
models, the wrapper falls back to overriding paths against the closest
available config. See `reproduction/scripts/shell/_infllm_budgets.sh`.

## Running the baselines

LongBench (1× A100, ~12h per model):
```bash
MODEL=mistral run_script reproduction/scripts/asax/longbench_infllm.sh
MODEL=llama3 run_script reproduction/scripts/asax/longbench_infllm.sh
MODEL=llama31 run_script reproduction/scripts/asax/longbench_infllm.sh
MODEL=phi3_mini run_script reproduction/scripts/asax/longbench_infllm.sh
MODEL=phi35_mini run_script reproduction/scripts/asax/longbench_infllm.sh
```

∞-Bench (paper only reports 7-8B models for InfLLM ∞-Bench):
```bash
MODEL=mistral run_script reproduction/scripts/asax/infinitebench_infllm.sh
MODEL=llama3 run_script reproduction/scripts/asax/infinitebench_infllm.sh
MODEL=llama31 run_script reproduction/scripts/asax/infinitebench_infllm.sh
```

Results land in `reproduction/results/<system>/<benchmark>_infllm/<model>_<budget>/`,
which is a sibling of the EM-LLM results tree:

```
reproduction/results/asax/
├── longbench/                  EM-LLM (existing)
│   └── mistral_sm_c/result.json
├── longbench_infllm/           InfLLM (new)
│   └── mistral_4k_2k/result.json
└── ...
```

Each InfLLM run also emits a paper-mirroring `summary.md` and `summary.csv`,
comparing our InfLLM number to the paper's InfLLM column from Table 2.

## Caveats

- **InfLLM's CLI may differ from EM-LLM's**. The wrappers assume a near-
  identical entry point (`benchmark/pred.py --config_path ... --output_dir_path ...
  --datasets ...`) because EM-LLM forked from InfLLM. If InfLLM's `pred.py`
  signature has drifted, edit `06_run_infllm_longbench.sh` /
  `07_run_infllm_infinitebench.sh` to match. The wrappers explicitly flag
  the lines that assume the EM-LLM CLI shape.
- **InfLLM may not ship configs for all 5 models** (Mistral is the
  guaranteed one; Llama / Phi may need user-added configs). When a config
  is missing, the wrapper prints a clear error pointing here.
- **InfLLM doesn't have variants** (no SM, SM+C, etc.) — it has one method.
  The budget tag in the output dir (`mistral_4k_2k`) records which n_local
  + n_mem we used.
- **Same conda env**. InfLLM's deps overlap heavily with EM-LLM's; both
  install cleanly into the `emllm` env. If you hit a version conflict, see
  the troubleshooting note in `docs/reproduction_notes.md`.
- **No `pred.py` re-implementation**. We do not modify upstream InfLLM, same
  as we don't modify upstream EM-LLM. All adaptations happen via OmegaConf
  CLI overrides.
