#!/bin/bash
# InfLLM LongBench baseline on ASAX (paper Table 2 comparator column).
# Same resource shape as EM-LLM longbench.sh.
#
# Pre-req: infllm-model/ populated; see docs/infllm_setup.md.
#
# Submit:
#   run_gpu reproduction/scripts/asax/longbench_infllm.sh
# Prompts: gpu / 8 / 14:00:00 / 128gb / 1 GPU
#
# Override MODEL via ~/repro-track/.job_config:
#   cat > ~/repro-track/.job_config <<EOF
#   export MODEL=mistral   # or llama3, llama31, phi3_mini, phi35_mini
#   EOF
#   run_gpu reproduction/scripts/asax/longbench_infllm.sh

BENCH_TAG="longbench-infllm"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"

echo "=== handing off to 06_run_infllm_longbench.sh ==="
bash reproduction/scripts/shell/06_run_infllm_longbench.sh
RC=$?
echo "=== 06_run_infllm_longbench.sh exited with code $RC ==="
exit $RC
