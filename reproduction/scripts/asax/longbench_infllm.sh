#!/bin/bash
# InfLLM LongBench baseline on ASAX (1× A100, ~12h on a 7-8B model).
# This is the InfLLM column from paper Table 2 — comparator for the EM-LLM
# results produced by reproduction/scripts/asax/longbench.sh.
#
# Submit via ASA's wrapper:
#   MODEL=mistral run_script reproduction/scripts/asax/longbench_infllm.sh
# At the prompts answer (adjust to current ASAX class names):
#   queue / class:  GPU-enabled (A100)
#   GPUs:           1
#   walltime:       12:00:00
#   memory:         128gb
# Monitor with: qstat -u $USER
#
# Full list of submit commands: docs/paper_reproduction_runbook.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

source activate emllm 2>/dev/null || conda activate emllm

LOG_DIR="reproduction/results/asax/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/longbench-infllm-$(date +%Y%m%d-%H%M%S)-${SLURM_JOB_ID:-$$}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

bash reproduction/scripts/shell/06_run_infllm_longbench.sh
