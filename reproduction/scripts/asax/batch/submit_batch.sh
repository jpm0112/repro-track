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
# Flags (order-independent, must precede wrapper names):
#   --dry-run    Print qsub commands without actually submitting them.
#   --per-task   Submit one PBS job per benchmark task instead of one job for
#                all tasks. Supported for longbench and infinitebench wrappers
#                only; passkey wrappers error out (single-sample-per-length).
#                Each per-task job passes DATASETS=<task>,SKIP_SCORING=1 via
#                qsub -v. After all tasks complete, run score_run.sh to score.
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
#   2026-05-27 added --per-task flag. Motivated by job 50131
#     (em_llm_infinitebench_mistral, 26h) being PBS walltime-killed after
#     completing only code_debug; the remaining 5 IB tasks never ran. With
#     --per-task each task gets its own PBS job so a slow task only burns its
#     own slot. Scoring is deferred: per-task jobs set SKIP_SCORING=1 and the
#     caller runs score_run.sh after all tasks land.
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

# Task lists for per-task mode. These must stay in sync with the DATASETS
# defaults inside the shell runners (02_run_longbench.sh:28, 03_run_infinitebench.sh:22).
# LongBench: 15 tasks
LB_TASKS="2wikimqa gov_report hotpotqa lcc multi_news multifieldqa_en musique narrativeqa passage_retrieval_en qasper qmsum repobench-p samsum trec triviaqa"
# InfiniteBench: 6 tasks
IB_TASKS="code_debug math_find kv_retrieval passkey number_string longbook_choice_eng"

# Per-task resource overrides for --per-task mode.
# Format: walltime ncpus mem gpus  (same as RESOURCES values)
# LongBench default: 12h (single task is much faster than the full 26h run).
LB_TASK_DEFAULT="12:00:00 4 120gb 1"
# InfiniteBench default: 30h per task (most IB tasks are long-context-heavy).
IB_TASK_DEFAULT="30:00:00 4 120gb 1"
# Per-task IB overrides: kv_retrieval and longbook_choice_eng involve the
# longest token sequences and have historically needed extra wall time.
declare -A IB_TASK_OVERRIDES=(
    [kv_retrieval]="36:00:00 4 120gb 1"
    [longbook_choice_eng]="36:00:00 4 120gb 1"
)

# ---------------------------------------------------------------------------
# Parse flags (order-independent: --dry-run and --per-task may appear in
# any order before the wrapper name(s)).
# ---------------------------------------------------------------------------
DRY=""
PER_TASK=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY="echo [DRY-RUN] "
            shift
            ;;
        --per-task)
            PER_TASK=1
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--dry-run] [--per-task] <wrapper-name> [more-names ...]"
    echo
    echo "Available wrappers:"
    for k in "${!RESOURCES[@]}"; do
        echo "  $k    (${RESOURCES[$k]})"
    done | sort
    exit 1
fi

# ---------------------------------------------------------------------------
# Helper: build and emit (or dry-run) a single qsub call.
# Args: $1=walltime $2=ncpus $3=mem $4=ngpus $5=jobname $6=script $7=extra_v
#   $7 is the value to pass to qsub -v (empty string = no -v flag).
# ---------------------------------------------------------------------------
emit_qsub() {
    local walltime="$1" ncpus="$2" mem="$3" ngpus="$4"
    local jobname="$5" script="$6" extra_v="$7"
    local select_str="select=1:ngpus=${ngpus}:ncpus=${ncpus}:mpiprocs=${ncpus}:mem=${mem%gb}000mb"

    if [[ -n "$extra_v" ]]; then
        $DRY qsub -q gpu -j oe -N "$jobname" -r n -M "$EMAIL" \
            -l "walltime=$walltime" \
            -l "$select_str" \
            -v "$extra_v" \
            "$script"
    else
        $DRY qsub -q gpu -j oe -N "$jobname" -r n -M "$EMAIL" \
            -l "walltime=$walltime" \
            -l "$select_str" \
            "$script"
    fi
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # Per-task mode
    # ------------------------------------------------------------------
    if [[ -n "$PER_TASK" ]]; then
        # Determine benchmark family and task list.
        if [[ "$name" == em_llm_longbench_* ]]; then
            bench_family="longbench"
            task_list="$LB_TASKS"
            task_default="$LB_TASK_DEFAULT"
        elif [[ "$name" == em_llm_infinitebench_* ]]; then
            bench_family="infinitebench"
            task_list="$IB_TASKS"
            task_default="$IB_TASK_DEFAULT"
        elif [[ "$name" == em_llm_passkey_* ]]; then
            echo "ERROR: --per-task is not supported for passkey wrappers." >&2
            echo "  Passkey runs are single-sample-per-length, not task-splittable." >&2
            echo "  Submit '$name' without --per-task." >&2
            exit 1
        else
            echo "ERROR: --per-task: cannot determine benchmark family for '$name'." >&2
            echo "  Expected name prefix: em_llm_longbench_* or em_llm_infinitebench_*" >&2
            exit 1
        fi

        for task in $task_list; do
            # Resolve per-task resource spec (IB has per-task overrides).
            task_spec=""
            if [[ "$bench_family" == "infinitebench" ]]; then
                task_spec="${IB_TASK_OVERRIDES[$task]:-$task_default}"
            else
                task_spec="$task_default"
            fi
            read -r wt ncpus mem ngpus <<< "$task_spec"

            # Job name: <wrapper>__<task>
            # PBS on ASAX does not enforce a 15-char job-name limit in practice
            # (the queue accepts long names and they appear in qstat output
            # without truncation). Using the full readable form here so logs are
            # unambiguous. If ASAX's scheduler rejects a long name in future,
            # truncate to the last 15 chars: "${jobname: -15}".
            jobname="${name}__${task}"

            emit_qsub "$wt" "$ncpus" "$mem" "$ngpus" \
                "$jobname" "$script" "DATASETS=${task},SKIP_SCORING=1"
        done

    # ------------------------------------------------------------------
    # All-tasks mode (original behavior)
    # ------------------------------------------------------------------
    else
        read -r walltime ncpus mem ngpus <<< "$spec"
        emit_qsub "$walltime" "$ncpus" "$mem" "$ngpus" "$name" "$script" ""
    fi
done

echo
echo "Submitted. Monitor with: qstat -u \$USER"
echo "Per-job logs: ~/repro-track/reproduction/results/asax/logs/"
