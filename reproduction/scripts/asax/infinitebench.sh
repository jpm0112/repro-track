#!/bin/bash
# Infinity-Bench reproduction on ASAX (1× A100/H100, ~24h on Mistral-7B).
# Higher memory request than LongBench because long tasks (kv_retrieval,
# longbook_qa_eng) trigger CPU offload during EM-LLM block management.
#
# Submit via ASA's wrapper:
#   run_gpu reproduction/scripts/asax/infinitebench.sh
# At the prompts answer:
#   queue:    gpu
#   cores:    8
#   walltime: 26:00:00
#   memory:   200gb
#   GPUs:     1
#
# Override MODEL / DATASETS / VARIANT via ~/repro-track/.job_config:
#   cat > ~/repro-track/.job_config <<EOF
#   export MODEL=llama31
#   export DATASETS=kv_retrieval,longbook_choice_eng
#   EOF
#   run_gpu reproduction/scripts/asax/infinitebench.sh
#
# Full list of submit commands per paper row: docs/paper_reproduction_runbook.md

BENCH_TAG="infinitebench"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"

echo "=== handing off to 03_run_infinitebench.sh ==="
bash reproduction/scripts/shell/03_run_infinitebench.sh
RC=$?
echo "=== 03_run_infinitebench.sh exited with code $RC ==="
exit $RC
