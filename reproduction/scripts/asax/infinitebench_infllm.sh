#!/bin/bash
# InfLLM Infinity-Bench baseline on ASAX (paper Table 2 comparator).
# Paper only reports InfLLM ∞-Bench for the 7-8B models (mistral, llama3, llama31).
#
# Pre-req: infllm-model/ populated; see docs/infllm_setup.md.
#
# Submit:
#   run_gpu reproduction/scripts/asax/infinitebench_infllm.sh
# Prompts: gpu / 8 / 26:00:00 / 200gb / 1 GPU
#
# Override MODEL via ~/repro-track/.job_config:
#   cat > ~/repro-track/.job_config <<EOF
#   export MODEL=mistral
#   EOF
#   run_gpu reproduction/scripts/asax/infinitebench_infllm.sh

BENCH_TAG="infinitebench-infllm"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"

echo "=== handing off to 07_run_infllm_infinitebench.sh ==="
bash reproduction/scripts/shell/07_run_infllm_infinitebench.sh
RC=$?
echo "=== 07_run_infllm_infinitebench.sh exited with code $RC ==="
exit $RC
