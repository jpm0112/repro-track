#!/bin/bash
# LongBench reproduction on ASAX (1× A100/H100, ~14h on Mistral-7B full 15-task).
#
# Submit via ASA's wrapper:
#   run_gpu reproduction/scripts/asax/longbench.sh
# At the prompts answer:
#   queue:    gpu
#   cores:    8
#   walltime: 14:00:00 (or 02:00:00 for a single-task smoke test)
#   memory:   128gb   (or 32gb for smoke test)
#   GPUs:     1
# Monitor with: qstat -u $USER
#
# PBS does NOT inherit submit-shell env vars. To set MODEL / DATASETS /
# VARIANT for the job, write them to ~/repro-track/.job_config first:
#
#   cat > ~/repro-track/.job_config <<EOF
#   export MODEL=mistral
#   export DATASETS=trec        # omit for full 15-task run
#   EOF
#   run_gpu reproduction/scripts/asax/longbench.sh
#
# Full list of submit commands per paper row: docs/paper_reproduction_runbook.md

BENCH_TAG="longbench"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"

echo "=== handing off to 02_run_longbench.sh ==="
bash reproduction/scripts/shell/02_run_longbench.sh
RC=$?
echo "=== 02_run_longbench.sh exited with code $RC ==="
exit $RC
