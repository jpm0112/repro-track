# ASAX setup

Quick reference for running this reproduction on the Alabama Supercomputer
(ASAX). Assumes you already have an account, a `$SCRATCH` allocation, and
SSH access to a login node.

## First-time login-node setup

```bash
ssh <user>@<asax-login>      # check the ASA portal for current login hostname
cd $SCRATCH

# Clone — current working tree includes a vendored em-llm-model
git clone https://github.com/<your-user>/repro-track.git
cd repro-track

# Source the ASAX env (loads modules, sets paths)
source reproduction/scripts/env/asax.env

# Verify modules loaded
which conda && which nvcc && nvidia-smi || echo "module load failed; check names"
```

If `module load anaconda/2024.02 cuda/12.4 gcc/11.4` fails, run
`module avail anaconda cuda gcc` and update the names in
`reproduction/scripts/env/asax.env` to whatever ASAX currently exposes.

## Create the conda env (login node)

```bash
bash reproduction/scripts/shell/00_env_setup.sh
```

The env is created at the default conda location, which on ASAX often points
into `$SCRATCH` already. If it lands in your home and you blow your home
quota, recreate with an explicit prefix:

```bash
conda env remove -n emllm
conda env create -f environment.asax.yml -p $SCRATCH/conda-envs/emllm
conda activate $SCRATCH/conda-envs/emllm
```

## HuggingFace + dataset pre-download (login node only)

Compute nodes do not have outbound internet. All HF model weights and ∞-Bench
JSONL files must be downloaded from a login node first.

```bash
huggingface-cli login        # paste a token with read-only access
bash reproduction/scripts/shell/00b_login_node_prep.sh   # all 5 base models
bash reproduction/scripts/shell/01_download_data.sh      # LongBench + ∞-Bench
```

Downloaded sizes (approx): Mistral-7B 14 GB, Llama-3-8B 16 GB, Llama-3.1-8B
16 GB, Phi-3-mini 7.6 GB, Phi-3.5-mini 7.6 GB, ∞-Bench JSONL ~15 GB.

## Submit reproduction jobs

```bash
sbatch reproduction/scripts/slurm/longbench.sbatch
sbatch reproduction/scripts/slurm/infinitebench.sbatch
sbatch reproduction/scripts/slurm/passkey_10m.sbatch
```

Override knobs without editing the sbatch file:

```bash
# Different model
sbatch --export=ALL,MODEL=llama31 reproduction/scripts/slurm/longbench.sbatch

# Different ∞-Bench dataset subset
sbatch --export=ALL,DATASETS=kv_retrieval,longbook_qa_eng \
       reproduction/scripts/slurm/infinitebench.sbatch
```

## Checking progress

```bash
squeue -u $USER
sacct -j <jobid> --format=JobID,State,Elapsed,MaxRSS,ReqMem
tail -f reproduction/results/asax/logs/longbench-<jobid>.out
```

## Common gotchas

- **Home quota exceeded.** Move conda env, HF cache, and any sizeable artifact
  to `$SCRATCH`. Default `asax.env` already does this.
- **`scripts/download.sh` fails with "no internet".** You ran it on a compute
  node by accident. Run it from a login node only.
- **Job killed by OOM.** The default `--mem` in sbatch may be too low for
  long-context tasks. Bump `#SBATCH --mem=...` in the relevant `.sbatch` and
  resubmit. The 10M-passkey sbatch already requests 512 GB.
- **`module: command not found` inside sbatch.** Some ASA partitions ship a
  bare shell. Add `source /etc/profile` at the top of the sbatch before the
  `source reproduction/scripts/env/asax.env`.

## When the run finishes

Results land in `reproduction/results/asax/<benchmark>/<model>/result.json`.
Pull them back to local for analysis with:

```bash
rsync -av <user>@<asax-login>:$SCRATCH/repro-track/reproduction/results/asax/ \
    ./reproduction/results/asax/
```
