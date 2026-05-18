#!/bin/bash
# 10M-token PassKey reproduction on ASAX (4× A100, ~48h on Mistral-7B).
# Multi-GPU layer split is auto-triggered by pred.py when
# torch.cuda.device_count() > 1. Disk offload is required at this scale.
#
# Submit via ASA's wrapper:
#   run_script reproduction/scripts/asax/passkey_10m.sh
# At the prompts answer (adjust to current ASAX class names):
#   queue / class:  a GPU-enabled class with A100s available
#   GPUs:           4
#   walltime:       48:00:00
#   memory:         512gb
# Monitor with: qstat -u $USER
#
# To run a shorter passkey length (e.g. 1M tokens for a smoke test):
#   EXTENDED_PASSKEY_K=1024 run_script reproduction/scripts/asax/passkey_10m.sh

set -eo pipefail

# See longbench.sh for why we don't use BASH_SOURCE-based resolution here.
REPO_ROOT="${PBS_O_WORKDIR:-${REPRO_ROOT:-$HOME/repro-track}}"
[[ -d "$REPO_ROOT/reproduction" ]] || {
    echo "FATAL: no reproduction/ tree at $REPO_ROOT" >&2
    exit 1
}
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

source activate emllm 2>/dev/null || conda activate emllm

LOG_DIR="reproduction/results/asax/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/passkey10m-$(date +%Y%m%d-%H%M%S)-${SLURM_JOB_ID:-$$}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

EXTENDED_PASSKEY_K="${EXTENDED_PASSKEY_K:-10240}" \
ALLOW_DISK_OFFLOAD=True \
    bash reproduction/scripts/shell/04_run_passkey_extended.sh
