# Common preamble for ASAX run_gpu / run_script wrappers. Sourced from each
# job-specific wrapper (longbench.sh, infinitebench.sh, etc.). Handles:
#
#   - Forcing all stdout/stderr into a $HOME debug log immediately, so silent
#     crashes are visible even when PBS doesn't capture the .o file properly.
#   - Resolving REPO_ROOT via PBS_O_WORKDIR / REPRO_ROOT / $HOME fallback,
#     since run_gpu copies the .sh to /scratch-local and runs it from there.
#   - Sourcing asax.env (modules + paths).
#   - Sourcing an optional ~/repro-track/.job_config so MODEL / DATASETS /
#     VARIANT / EXTRA_OVERRIDES env vars survive the PBS shell handoff that
#     would otherwise drop them.
#   - Activating the conda env, then force-prepending its bin/ to PATH and
#     lib/ to LD_LIBRARY_PATH (works around ASA's module setup which loads
#     anaconda's bin/ ahead of conda activate's prepend, and gcc/9.5's
#     libstdc++ missing GLIBCXX_3.4.29 needed by Pillow).
#   - Capping CUDA_VISIBLE_DEVICES to a single GPU (override for multi-GPU)
#     since PBS gpu queue doesn't isolate GPU visibility per-job.
#
# Caller protocol:
#   BENCH_TAG="longbench"   # used in the debug-log filename
#   source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"
#   # ... then call the relevant 0[2-7]_run_*.sh ...

# ---- 1. Debug-log capture (BEFORE anything else can fail) -------------------
mkdir -p "$HOME/repro-track/reproduction/results/asax/logs"
DEBUG_LOG="$HOME/repro-track/reproduction/results/asax/logs/${BENCH_TAG:-job}-$(date +%Y%m%d-%H%M%S)-${PBS_JOBID:-local}.log"
exec > "$DEBUG_LOG" 2>&1
[[ "${DEBUG:-1}" == "1" ]] && set -x

# Intentionally NOT `set -e`: ASA's module profile + conda activation hooks
# legitimately return non-zero from internal tests, and aborting on that
# would silently kill the wrapper. The downstream 0[2-7]_run_*.sh has its
# own strict mode for the real work.
set -o pipefail

# ---- 2. Diagnostic header ----------------------------------------------------
echo "=== env at script start (bench=${BENCH_TAG:-?}) ==="
echo "PWD=$PWD"
echo "HOME=$HOME"
echo "PBS_JOBID=${PBS_JOBID:-unset}"
echo "PBS_O_WORKDIR=${PBS_O_WORKDIR:-unset}"
echo "BASH_SOURCE[0]=${BASH_SOURCE[0]}"
echo "=========================="

# ---- 3. Resolve REPO_ROOT and cd into it -----------------------------------
REPO_ROOT="${PBS_O_WORKDIR:-${REPRO_ROOT:-$HOME/repro-track}}"
if [[ ! -d "$REPO_ROOT/reproduction" ]]; then
    echo "FATAL: no reproduction/ tree at $REPO_ROOT"
    echo "       set REPRO_ROOT or fix PBS_O_WORKDIR before re-submitting."
    exit 1
fi
cd "$REPO_ROOT"

# ---- 4. Source asax.env (modules + paths) ---------------------------------
# shellcheck disable=SC1091
source reproduction/scripts/env/asax.env

# ---- 5. Pick up per-job overrides from .job_config ---------------------------
# PBS doesn't inherit env vars from the submit shell, so MODEL=foo etc. on
# the run_gpu command line don't reach this script. Workaround: user writes
# overrides to ~/repro-track/.job_config before submitting; we source it here.
if [[ -f "$REPO_ROOT/.job_config" ]]; then
    echo "=== sourcing $REPO_ROOT/.job_config ==="
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.job_config"
    echo "=== .job_config contents applied ==="
fi

# ---- 6. Conda activate + PATH/LD_LIBRARY_PATH overrides ---------------------
echo "=== attempting conda activate emllm ==="
source activate emllm 2>/dev/null || conda activate emllm
echo "=== CONDA_PREFIX=$CONDA_PREFIX ==="

# Force the env's bin and lib to win over anaconda module and system gcc.
export PATH="$CONDA_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}"
echo "=== python now: $(which python) ==="

# ---- 7. GPU visibility -------------------------------------------------------
# ASA's PBS gpu queue assigns slots but doesn't isolate visibility — torch
# sees every GPU on the node. Cap to one device so pred.py takes the
# single-GPU branch. Override on the run_gpu line / .job_config for
# multi-GPU jobs (e.g., CUDA_VISIBLE_DEVICES=0,1,2,3 for passkey 10M).
#
# When CUDA_VISIBLE_DEVICES is unset, pick the GPU with the most free
# memory at job start instead of hard-coding GPU 0. Reason: on shared-
# visibility nodes GPU 0 is sometimes already heavily used by another
# tenant, which caused model-load OOMs (e.g., job 50132 on 2026-05-25
# died with "CUDA out of memory" trying to allocate 112 MiB while loading
# the first Mistral-7B shard). Fall back to GPU 0 if nvidia-smi isn't
# available or returns nothing.
if [[ -z "${CUDA_VISIBLE_DEVICES:-}" ]]; then
    GPU_IDX=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | \
        awk 'BEGIN{best=-1; ans=""} {v=$1+0; if (v > best) {best=v; ans=NR-1}} END{print ans}')
    if [[ -z "$GPU_IDX" || ! "$GPU_IDX" =~ ^[0-9]+$ ]]; then
        echo "=== nvidia-smi unavailable or no GPUs visible; falling back to GPU 0 ==="
        GPU_IDX=0
    fi
    export CUDA_VISIBLE_DEVICES="$GPU_IDX"
fi

echo "=== CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES ==="
nvidia-smi --query-gpu=index,name,memory.free,memory.used,memory.total \
    --format=csv,noheader 2>/dev/null \
    || echo "=== nvidia-smi diagnostic unavailable ==="

echo "=== preamble complete; ready to dispatch ==="
