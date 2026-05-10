#!/usr/bin/env bash
#SBATCH --job-name=emllm-passkey10m
#SBATCH --partition=ampere
#SBATCH --gres=gpu:a100:4         # multi-GPU layer split for 10M tokens
#SBATCH --cpus-per-task=16
#SBATCH --mem=512G
#SBATCH --time=48:00:00
#SBATCH --output=reproduction/results/asax/logs/passkey10m-%A.out
#SBATCH --error=reproduction/results/asax/logs/passkey10m-%A.err

# The headline 10M-token PassKey reproduction. Uses 4× A100 layer-split via
# accelerate (auto-triggered when torch.cuda.device_count() > 1 in pred.py:58).
# Disk offload required; results land in $EMLLM_OFFLOAD_DIR (per-job scratch).

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"
mkdir -p reproduction/results/asax/logs

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate emllm

EXTENDED_PASSKEY_K=10240 \
ALLOW_DISK_OFFLOAD=True \
    bash reproduction/scripts/shell/04_run_passkey_extended.sh
