#!/bin/bash
# LongBench reproduction on ASAX (1× A100, ~12h on Mistral-7B).
#
# Submit via ASA's wrapper:
#   run_script reproduction/scripts/asax/longbench.sh
# At the prompts answer (adjust to current ASAX class names):
#   queue / class:  a GPU-enabled class with A100 (e.g. class50, gpu2)
#   GPUs:           1
#   walltime:       12:00:00
#   memory:         128gb
# Monitor with: qstat -u $USER
#
# Override the base model at submit time (variant defaults to paper Table 2
# for that model: mistral=sm_c, llama3=s, llama31=sm, phi3_mini=s, phi35_mini=s):
#   MODEL=llama31 run_script reproduction/scripts/asax/longbench.sh
#
# For LLaMA-3.1's paper Table 1 (per-task) row, force the S variant:
#   MODEL=llama31 VARIANT=s run_script reproduction/scripts/asax/longbench.sh
#
# Full list of submit commands per paper row: docs/paper_reproduction_runbook.md

set -euo pipefail

# Resolve repo root regardless of where this is submitted from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

# Activate the conda env — matches the user's existing ASA pattern.
source activate emllm 2>/dev/null || conda activate emllm

# Structured log alongside whatever run_script captures on its own.
LOG_DIR="reproduction/results/asax/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/longbench-$(date +%Y%m%d-%H%M%S)-${SLURM_JOB_ID:-$$}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

bash reproduction/scripts/shell/02_run_longbench.sh
