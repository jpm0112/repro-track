# ASAX setup

Quick reference for running this reproduction on ASAX (Alabama Supercomputer's
Asax cluster). Assumes an account, a `$SCRATCH` allocation, and SSH access to
a login node.

ASAX uses ASA's `run_script` wrapper for submission and `qstat` for status —
not raw `sbatch`. Resource specs (GPU count, walltime, memory) are passed to
`run_script` at submit time, not as `#SBATCH` directives in the script.

## Storage layout on ASA's asax cluster

ASA's asax does **not** provision a personal `/scratch/<user>` directory.
Instead each account gets a generous **home (100 GB hard, 90 GB soft quota)**
plus `/scratch-local` (per-compute-node ephemeral). The reproduction layout
is therefore:

| Path | Purpose | Persistence |
|------|---------|-------------|
| `$HOME/repro-track` | code + configs + persistent results | persistent, quota-limited |
| `$HOME/.cache/huggingface` | model weights + benchmark datasets | persistent (~14 GB per 7-8B model) |
| `/scratch-local/emllm_offload_<user>_<jobid>` | transient per-job offload | wiped between jobs |

A bare home directory will start at ~30-50 GB used; adding the conda env
(~10 GB), Mistral weights (~14 GB), and benchmarks (~20 GB) puts you near
the soft quota. Stay under by only pre-downloading the models you actually
plan to run (override `MODELS=` in `00b_login_node_prep.sh`).

## First-time login-node setup

```bash
ssh <user>@<asax-login>      # check the ASA portal for current login hostname
cd $HOME

# Clone — current working tree includes a vendored em-llm-model
git clone https://github.com/<your-user>/repro-track.git
cd repro-track

# Source the ASAX env (loads modules, sets paths)
source reproduction/scripts/env/asax.env

# Verify modules loaded
which conda && nvidia-smi || echo "module load failed; run `module avail anaconda cuda` and fix names"
```

If `module load anaconda/3-2025.12 cuda/11.8.0` fails, run
`module avail anaconda cuda` and update the names in
`reproduction/scripts/env/asax.env` to whatever ASAX currently exposes.

## Create the conda env (login node)

```bash
bash reproduction/scripts/shell/00_env_setup.sh
```

The env defaults to wherever conda puts it. If that's your home directory and
home runs out of quota, recreate with an explicit prefix on scratch:

```bash
conda env remove -n emllm
conda env create -f environment.asax.yml -p $SCRATCH/conda-envs/emllm
source activate $SCRATCH/conda-envs/emllm
```

## HuggingFace + dataset pre-download (login node only)

Compute nodes do not have outbound internet. All HF model weights and
Infinity-Bench JSONL files must be downloaded from a login node first.

```bash
huggingface-cli login        # paste a token with read-only access
bash reproduction/scripts/shell/00b_login_node_prep.sh   # all 5 base models
bash reproduction/scripts/shell/01_download_data.sh      # LongBench + ∞-Bench
```

Mistral-7B-Instruct-v0.2 is gated — click "Agree and access" on its model
page once before `00b_login_node_prep.sh` runs, or the download will 401.

Approx sizes: Mistral-7B 14 GB, Llama-3-8B 16 GB, Llama-3.1-8B 16 GB,
Phi-3-mini 7.6 GB, Phi-3.5-mini 7.6 GB, ∞-Bench JSONL ~15 GB.

## Submit reproduction jobs

Each `.sh` payload below is a plain bash script. `run_script` reads it,
prompts for resources, then submits it as a SLURM job under the hood.

```bash
run_script reproduction/scripts/asax/longbench.sh
run_script reproduction/scripts/asax/infinitebench.sh
run_script reproduction/scripts/asax/passkey_10m.sh
```

Suggested answers to `run_script`'s prompts per job (adjust class names to
whatever your allocation currently exposes):

| Script | Class | GPUs | Walltime | Memory |
|--------|-------|------|----------|--------|
| `longbench.sh` | GPU-enabled (A100) | 1 | 12:00:00 | 128gb |
| `infinitebench.sh` | GPU-enabled (A100) | 1 | 24:00:00 | 200gb |
| `passkey_10m.sh` | GPU-enabled (A100) | 4 | 48:00:00 | 512gb |

Override knobs without editing the script — pass env vars on the submit line:

```bash
MODEL=llama31 run_script reproduction/scripts/asax/longbench.sh
DATASETS=kv_retrieval,longbook_qa_eng \
    run_script reproduction/scripts/asax/infinitebench.sh
EXTENDED_PASSKEY_K=1024 run_script reproduction/scripts/asax/passkey_10m.sh
```

## Checking progress

```bash
qstat -u $USER
tail -f reproduction/results/asax/logs/longbench-*.log
```

Each `.sh` also tees its full stdout/stderr to a timestamped file under
`reproduction/results/asax/logs/` so log location is predictable regardless
of how `run_script` captures its own output.

## Common gotchas

- **Home quota exceeded.** ASA caps home at 100 GB hard / 90 GB soft. Trim
  the HF cache (`du -sh ~/.cache/huggingface/hub/models--*` to find big
  ones), delete model weights you don't currently need, or move the conda
  env to a less crowded prefix.
- **`scripts/download.sh` fails with "no internet".** You ran it on a compute
  node by accident. Run it from a login node only.
- **Job killed by OOM.** Memory request in `run_script` was too low for the
  long-context task. Resubmit with a higher `memory:` answer; 200gb is
  usually enough for ∞-Bench, 512gb for the 10M passkey.
- **`module: command not found` inside the job.** ASAX's dynamic profile
  wasn't sourced. The `asax.env` does this with
  `source /apps/profiles/modules_asax.sh.dyn`; if that path moved after a
  maintenance window, find the new one with `ls /apps/profiles/`.
- **`source activate emllm` fails with "not found".** The conda env wasn't
  created under the default name. Either run `00_env_setup.sh` first, or
  point at the explicit prefix: `source activate $SCRATCH/conda-envs/emllm`.

## Things that went wrong the first time

If something silently fails, check `docs/asax_lessons_learned.md` — that
file collects every gotcha we hit during EM-LLM bring-up (PBS not
inheriting env vars, `cuda/11.8.0` breaking libstdc++, PBS `gpu` queue
not isolating GPU visibility, etc.) and the fix for each.

## When the run finishes

Results land in `reproduction/results/asax/<benchmark>/<model>/result.json`.
Pull them back to the local workstation for analysis with:

```bash
rsync -av <user>@<asax-login>:$SCRATCH/repro-track/reproduction/results/asax/ \
    ./reproduction/results/asax/
```
