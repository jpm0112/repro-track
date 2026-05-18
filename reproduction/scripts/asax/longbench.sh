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

# Capture EVERYTHING to a known log file in $HOME immediately, before any
# command can fail silently. run_gpu's PBS .o file sometimes doesn't catch
# the user script's stdout/stderr, so this is our guaranteed-visible trail.
mkdir -p "$HOME/repro-track/reproduction/results/asax/logs"
DEBUG_LOG="$HOME/repro-track/reproduction/results/asax/logs/longbench-$(date +%Y%m%d-%H%M%S)-${PBS_JOBID:-local}.log"
exec > "$DEBUG_LOG" 2>&1
set -x

# NOTE: we deliberately do NOT use `set -e` in this wrapper. ASA's module
# profile (/apps/profiles/modules_asax.sh.dyn) and conda's activation
# hooks legitimately return non-zero from internal tests, and `set -e`
# would silently abort us mid-source. The downstream 02_run_longbench.sh
# has its own `set -euo pipefail` for the actual work.
set -o pipefail

# Diagnostic header — see exactly what env we landed in.
echo "=== env at script start ==="
echo "PWD=$PWD"
echo "HOME=$HOME"
echo "PBS_JOBID=${PBS_JOBID:-unset}"
echo "PBS_O_WORKDIR=${PBS_O_WORKDIR:-unset}"
echo "REPRO_ROOT=${REPRO_ROOT:-unset}"
echo "BASH_SOURCE[0]=${BASH_SOURCE[0]}"
echo "=========================="

# Resolve repo root. ASA's run_gpu/run_script copies this script to a
# per-node /scratch-local dir and runs it from there, so BASH_SOURCE-based
# resolution lands in the wrong place. PBS_O_WORKDIR is the submit dir
# (set by PBS); REPRO_ROOT works when sourced asax.env first; $HOME is
# the final fallback (ASA homes are NFS-shared across nodes).
REPO_ROOT="${PBS_O_WORKDIR:-${REPRO_ROOT:-$HOME/repro-track}}"
if [[ ! -d "$REPO_ROOT/reproduction" ]]; then
    echo "FATAL: no reproduction/ tree at $REPO_ROOT"
    echo "       set REPRO_ROOT or fix PBS_O_WORKDIR before re-submitting."
    exit 1
fi
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

echo "=== asax.env sourced, attempting conda activate ==="
source activate emllm 2>/dev/null || conda activate emllm

echo "=== conda env: $CONDA_DEFAULT_ENV ==="
echo "=== python: $(which python) ==="

# Prefer conda's newer libstdc++ over the system one loaded by the gcc
# module. The cuda/11.8.0 module forces gcc back to 9.5.0_all, whose
# libstdc++ lacks GLIBCXX_3.4.29 (needed by Pillow's libLerc, pulled in
# by transformers). Without this, `import transformers` raises a
# RuntimeError about the missing symbol.
export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}"
echo "=== LD_LIBRARY_PATH prefixed with: $CONDA_PREFIX/lib ==="

echo "=== handing off to 02_run_longbench.sh (with -x trace) ==="
# bash -x so the inner script's exec trace lands in our debug log too.
bash -x reproduction/scripts/shell/02_run_longbench.sh
RC=$?
echo "=== 02_run_longbench.sh exited with code $RC ==="
exit $RC
