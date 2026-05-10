#!/usr/bin/env bash
#SBATCH --job-name=emllm-longbench
#SBATCH --partition=ampere      # adjust to actual ASAX GPU partition name
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --output=reproduction/results/asax/logs/longbench-%A.out
#SBATCH --error=reproduction/results/asax/logs/longbench-%A.err

# Submit from the repo root:
#   sbatch reproduction/scripts/slurm/longbench.sbatch
# Override model:
#   sbatch --export=ALL,MODEL=llama3 reproduction/scripts/slurm/longbench.sbatch

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"
mkdir -p reproduction/results/asax/logs

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate emllm

bash reproduction/scripts/shell/02_run_longbench.sh
