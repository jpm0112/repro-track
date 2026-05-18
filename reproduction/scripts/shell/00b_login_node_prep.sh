#!/usr/bin/env bash
# ASAX-only: pre-fetch HuggingFace model weights on the login node so compute
# nodes (which lack internet) can load them via TRANSFORMERS_OFFLINE=1.
#
# Pre-req: sourced reproduction/scripts/env/asax.env, huggingface-cli login done.

set -euo pipefail

: "${HF_HOME:?source reproduction/scripts/env/asax.env first}"
: "${REPRO_ROOT:?}"

if [[ "${REPRO_SYSTEM:-}" != "asax" ]]; then
    echo "This script is for the ASAX backend. Skipping on REPRO_SYSTEM=${REPRO_SYSTEM:-<unset>}." >&2
    exit 0
fi

# Defaults to all five base models the upstream supports. Override via
# MODELS="..." env var to fetch a subset.
DEFAULT_MODELS=(
    "mistralai/Mistral-7B-Instruct-v0.2"
    "meta-llama/Meta-Llama-3-8B-Instruct"
    "meta-llama/Meta-Llama-3.1-8B-Instruct"
    "microsoft/Phi-3-mini-128k-instruct"
    "microsoft/Phi-3.5-mini-instruct"
)
read -ra MODELS <<< "${MODELS:-${DEFAULT_MODELS[*]}}"

for m in "${MODELS[@]}"; do
    echo "[login-prep] Pre-fetching $m into \$HF_HOME/hub"
    # No --cache-dir: huggingface-cli auto-routes into $HF_HOME/hub, which is
    # exactly where transformers' from_pretrained() looks when
    # TRANSFORMERS_OFFLINE=1 on compute nodes. Passing --cache-dir $HF_HOME
    # would put weights one level too high and the compute job would 404.
    huggingface-cli download "$m"
done

echo "[login-prep] Done. Compute jobs can now run with TRANSFORMERS_OFFLINE=1."
