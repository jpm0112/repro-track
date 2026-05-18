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

set -eo pipefail

EMAIL="jpm0112@auburn.edu"
BATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Per-wrapper resource specs. Keep in sync with paper_reproduction_runbook.md.
# Format: walltime ncpus mem gpus
declare -A RESOURCES=(
    [em_llm_longbench_mistral]="14:00:00 8 128gb 1"
    [em_llm_longbench_llama3]="14:00:00 8 128gb 1"
    [em_llm_longbench_llama31_sm]="14:00:00 8 128gb 1"
    [em_llm_longbench_llama31_s]="14:00:00 8 128gb 1"
    [em_llm_longbench_phi3_mini]="14:00:00 8 128gb 1"
    [em_llm_longbench_phi35_mini]="14:00:00 8 128gb 1"
    [em_llm_infinitebench_mistral]="26:00:00 8 200gb 1"
    [em_llm_infinitebench_llama3]="26:00:00 8 200gb 1"
    [em_llm_infinitebench_llama31_sm]="26:00:00 8 200gb 1"
    [em_llm_infinitebench_llama31_s]="26:00:00 8 200gb 1"
    [em_llm_passkey_1m_mistral]="26:00:00 8 64gb 1"
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
