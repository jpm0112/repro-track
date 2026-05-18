# Hardware + software fingerprint for one job run.
# Sourced by 02-07_run_*.sh after their OUT_DIR exists.
#
# Writes <OUT_DIR>/run_metadata.txt with: node hostname, scheduler job id,
# GPU model + driver, CPU model + count, RAM, OS, loaded modules,
# conda env, key library versions (torch, transformers, em-llm), and the
# git SHAs of repro-track / em-llm-model / infllm-model at the moment
# the job ran. Reviewers can correlate a number in result.json to the
# exact hardware + code it came from.
#
# Usage:
#   source "$REPRO_ROOT/reproduction/scripts/shell/_capture_run_metadata.sh"
#   write_run_metadata "$OUT_DIR"

write_run_metadata() {
    local out_dir="$1"
    local meta_file="$out_dir/run_metadata.txt"
    [[ -d "$out_dir" ]] || { echo "[metadata] skipped: $out_dir does not exist"; return 0; }

    {
        echo "# Run metadata"
        echo "# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by _capture_run_metadata.sh"
        echo

        echo "## Job context"
        echo "hostname:           $(hostname)"
        echo "pbs_jobid:          ${PBS_JOBID:-unset}"
        echo "pbs_o_workdir:      ${PBS_O_WORKDIR:-unset}"
        echo "slurm_jobid:        ${SLURM_JOB_ID:-unset}"
        echo "user:               ${USER:-unknown}"
        echo "cuda_visible_devs:  ${CUDA_VISIBLE_DEVICES:-unset}"
        echo "pytorch_alloc_conf: ${PYTORCH_CUDA_ALLOC_CONF:-unset}"
        echo

        echo "## CPU"
        if command -v lscpu >/dev/null 2>&1; then
            lscpu | grep -E "Model name|Socket|Core|Thread|CPU MHz|Architecture|^CPU\(s\)" | head -12
        else
            grep -m1 "model name" /proc/cpuinfo 2>/dev/null || echo "cpu info unavailable"
            echo "cores: $(nproc 2>/dev/null || echo unknown)"
        fi
        echo

        echo "## GPU"
        if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia-smi --query-gpu=index,name,driver_version,memory.total,compute_cap --format=csv 2>&1 \
                || echo "nvidia-smi failed"
        else
            echo "nvidia-smi not on PATH"
        fi
        echo

        echo "## RAM"
        if command -v free >/dev/null 2>&1; then
            free -h | head -3
        else
            grep -E "^Mem(Total|Free|Available)" /proc/meminfo 2>/dev/null | head -3
        fi
        echo

        echo "## OS"
        if [[ -f /etc/os-release ]]; then
            grep -E "^(NAME|VERSION|ID)=" /etc/os-release | head -5
        fi
        echo "kernel:    $(uname -r 2>/dev/null)"
        echo "uname -a:  $(uname -a 2>/dev/null)"
        echo

        echo "## Loaded modules (Lmod / asax)"
        module list 2>&1 | tail -20 || echo "module command unavailable"
        echo

        echo "## Conda env"
        echo "CONDA_DEFAULT_ENV: ${CONDA_DEFAULT_ENV:-unset}"
        echo "CONDA_PREFIX:      ${CONDA_PREFIX:-unset}"
        echo "python path:       $(command -v python || echo not-found)"
        echo "python version:    $(python --version 2>&1)"
        echo

        echo "## Key Python package versions"
        python - <<'PYV' 2>&1 || echo "python introspection failed"
import importlib, sys
def v(name):
    try:
        m = importlib.import_module(name)
        ver = getattr(m, "__version__", "unknown")
        return ver
    except Exception as exc:
        return f"NOT INSTALLED ({exc.__class__.__name__})"
print(f"  torch:        {v('torch')}")
try:
    import torch
    print(f"  torch.cuda:   {torch.version.cuda} (available={torch.cuda.is_available()}, devices={torch.cuda.device_count()})")
except Exception as e:
    print(f"  torch.cuda:   query failed: {e}")
print(f"  transformers: {v('transformers')}")
print(f"  accelerate:   {v('accelerate')}")
print(f"  datasets:     {v('datasets')}")
print(f"  numpy:        {v('numpy')}")
print(f"  em_llm:       {v('em_llm')}")
PYV
        echo

        echo "## Git SHAs"
        if [[ -d "${REPRO_ROOT:-}/.git" ]]; then
            echo "repro-track:  $(git -C "$REPRO_ROOT" rev-parse HEAD 2>/dev/null) ($(git -C "$REPRO_ROOT" diff --quiet 2>/dev/null && echo clean || echo DIRTY))"
        fi
        if [[ -d "${EMLLM_ROOT:-}/.git" ]]; then
            echo "em-llm-model: $(git -C "$EMLLM_ROOT" rev-parse HEAD 2>/dev/null)"
        fi
        if [[ -d "${INFLLM_ROOT:-}/.git" ]]; then
            echo "infllm-model: $(git -C "$INFLLM_ROOT" rev-parse HEAD 2>/dev/null)"
        fi
        echo

        echo "## Disk usage of HF cache (at job start)"
        if [[ -d "${HF_HOME:-}" ]]; then
            du -sh "$HF_HOME"/hub/models--* 2>/dev/null | head -10 || echo "no models cached"
        fi
    } > "$meta_file" 2>&1

    echo "[metadata] wrote $meta_file"
}
