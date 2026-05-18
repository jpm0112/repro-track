#!/bin/bash
# Infinity-Bench reproduction on ASAX (1× A100, ~24h on Mistral-7B).
# Higher memory than LongBench because long tasks (kv_retrieval,
# longbook_qa_eng) trigger CPU offload.
#
# Submit via ASA's wrapper:
#   run_script reproduction/scripts/asax/infinitebench.sh
# At the prompts answer (adjust to current ASAX class names):
#   queue / class:  a GPU-enabled class with A100 (e.g. class50, gpu2)
#   GPUs:           1
#   walltime:       24:00:00
#   memory:         200gb
# Monitor with: qstat -u $USER
#
# Override the base model or dataset subset at submit time. Variant defaults
# to paper Table 2 for the model (mistral=sm_c, llama3=s, llama31=sm).
#   MODEL=llama31 run_script reproduction/scripts/asax/infinitebench.sh
#   MODEL=llama31 VARIANT=s run_script reproduction/scripts/asax/infinitebench.sh
#   DATASETS=kv_retrieval,longbook_qa_eng \
#       run_script reproduction/scripts/asax/infinitebench.sh
#
# Full list of submit commands per paper row: docs/paper_reproduction_runbook.md

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
LOG_FILE="$LOG_DIR/infinitebench-$(date +%Y%m%d-%H%M%S)-${SLURM_JOB_ID:-$$}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

bash reproduction/scripts/shell/03_run_infinitebench.sh
