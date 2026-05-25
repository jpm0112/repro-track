#!/bin/bash
# Submit one or more batch wrappers via direct qsub, bypassing run_gpu's
# interactive prompts. Resources per wrapper are baked in below.
#
# Usage:
#   bash reproduction/scripts/asax/batch/submit_batch.sh em_llm_longbench_mistral
#   bash reproduction/scripts/asax/batch/submit_batch.sh em_llm_longbench_mistral em_llm_infinitebench_mistral em_llm_passkey_1m_mistral
#
# Each name is a wrapper in this directory (without the .sh suffix). Each is
# submitted independently; PBS schedules them as resources free up. Monitor
# with `qstat -u $USER`.
#
# If you pass `--dry-run` as the first arg, prints the qsub commands without
# actually submitting them.
#
# Resuming a failed/killed run: just re-submit the same wrapper. `pred.py`
# scans the per-task .jsonl in the output dir and skips already-completed
# sample IDs (see get_past_ids() in em-llm-model/benchmark/pred.py). So:
#   - LongBench / IB: tasks with a fully-populated .jsonl are skipped; the
#     dataset loop only re-inferences remaining samples in remaining tasks.
#   - Passkey extended: single dataset with one sample per length — if the
#     sample didn't complete (no .jsonl row), it restarts from scratch.
# Stale files under <out_dir>/offload_data/ from a killed run are harmless
# but waste inodes; safe to `rm -rf` them before resuming.

set -eo pipefail

EMAIL="jpm0112@auburn.edu"
BATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Per-wrapper resource specs. Keep in sync with batch_submission.md table.
# Format: walltime ncpus mem gpus
#
# History:
#   2026-05-18 first batch run on Mistral hit two failure modes —
#     - LongBench: walltime 14h exhausted at 7/16 tasks (job 46923 PBS-killed).
#     - IB: died silently mid-task #2 at 15.5h with 120gb (suspected OOM).
#     - Passkey-1M: died silently at 50min/1995 chunks with 64gb (OOM-killed).
#   2026-05-24 attempted bumping IB/pk1m to 200gb; qsub rejected all three
#     with "Job violates queue and/or server resource limits" — the gpu
#     queue caps memory at 120gb (consistent with commit 80ea7a8's note).
#     Reverted memory to 120gb; bumped LongBench walltime to 26h. To
#     compensate for the tight memory on long-context runs, pass
#     EXTRA_OVERRIDES at submit time, e.g.:
#       EXTRA_OVERRIDES="model.min_free_cpu_memory=20 \
#                        model.disk_offload_threshold=150000"
#     Rerunning the same wrapper resumes per-sample via get_past_ids().
declare -A RESOURCES=(
    [em_llm_longbench_mistral]="26:00:00 4 120gb 1"
    [em_llm_longbench_llama3]="26:00:00 4 120gb 1"
    [em_llm_longbench_llama31_sm]="26:00:00 4 120gb 1"
    [em_llm_longbench_llama31_s]="26:00:00 4 120gb 1"
    [em_llm_longbench_phi3_mini]="26:00:00 4 120gb 1"
    [em_llm_longbench_phi35_mini]="26:00:00 4 120gb 1"
    [em_llm_infinitebench_mistral]="26:00:00 4 120gb 1"
    [em_llm_infinitebench_llama3]="26:00:00 4 120gb 1"
    [em_llm_infinitebench_llama31_sm]="26:00:00 4 120gb 1"
    [em_llm_infinitebench_llama31_s]="26:00:00 4 120gb 1"
    [em_llm_passkey_1m_mistral]="26:00:00 4 120gb 1"
    # passkey_10m needs 4 GPUs and 512gb; do NOT include unattended.
    # Submit separately once allocated extra resources (contact hpc@asc.edu).
    [em_llm_passkey_10m_mistral]="48:00:00 16 512gb 4"
)

DRY=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY="echo [DRY-RUN] "
    shift
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--dry-run] <wrapper-name> [more-names ...]"
    echo
    echo "Available wrappers:"
    for k in "${!RESOURCES[@]}"; do
        echo "  $k    (${RESOURCES[$k]})"
    done | sort
    exit 1
fi

for name in "$@"; do
    spec="${RESOURCES[$name]:-}"
    if [[ -z "$spec" ]]; then
        echo "ERROR: unknown wrapper '$name'. Run with no args to see the list." >&2
        exit 1
    fi
    script="$BATCH_DIR/$name.sh"
    if [[ ! -x "$script" ]]; then
        echo "ERROR: wrapper not executable: $script" >&2
        exit 1
    fi
    read -r walltime ncpus mem ngpus <<< "$spec"
    select_str="select=1:ngpus=${ngpus}:ncpus=${ncpus}:mpiprocs=${ncpus}:mem=${mem%gb}000mb"

    $DRY qsub -q gpu -j oe -N "$name" -r n -M "$EMAIL" \
        -l "walltime=$walltime" \
        -l "$select_str" \
        "$script"
done

echo
echo "Submitted. Monitor with: qstat -u \$USER"
echo "Per-job logs: ~/repro-track/reproduction/results/asax/logs/"
