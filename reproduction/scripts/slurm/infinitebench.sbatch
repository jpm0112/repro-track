#!/usr/bin/env bash
#SBATCH --job-name=emllm-infbench
#SBATCH --partition=ampere
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G
#SBATCH --time=24:00:00
#SBATCH --output=reproduction/results/asax/logs/infinitebench-%A.out
#SBATCH --error=reproduction/results/asax/logs/infinitebench-%A.err

# Higher --mem because long ∞-Bench tasks (kv_retrieval, longbook_qa_eng)
# trigger CPU offload. ASAX A100 nodes typically expose 256-1000 GB RAM.

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"
mkdir -p reproduction/results/asax/logs

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate emllm

bash reproduction/scripts/shell/03_run_infinitebench.sh
