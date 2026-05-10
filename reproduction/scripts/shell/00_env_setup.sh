#!/usr/bin/env bash
# Idempotent environment setup. Creates (or updates) the `emllm` conda env,
# then installs the upstream em_llm package in editable mode.
#
# Pre-req: source reproduction/scripts/env/${REPRO_SYSTEM}.env first.

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${REPRO_SYSTEM:?REPRO_SYSTEM not set; sourcing the env file should set it}"

ENV_FILE="$REPRO_ROOT/environment.${REPRO_SYSTEM}.yml"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE"; exit 1; }

# Resolve conda command without assuming `conda activate` is sourced.
CONDA_BIN="$(command -v conda || true)"
[[ -n "$CONDA_BIN" ]] || { echo "conda not on PATH; load the appropriate module"; exit 1; }
CONDA_BASE="$($CONDA_BIN info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"

# Create or update the env.
if conda env list | awk '{print $1}' | grep -qx "emllm"; then
    echo "[setup] Updating existing emllm conda env from $ENV_FILE"
    conda env update -n emllm -f "$ENV_FILE" --prune
else
    echo "[setup] Creating new emllm conda env from $ENV_FILE"
    conda env create -f "$ENV_FILE"
fi

conda activate emllm

# Install upstream-pinned deps and the em_llm package in editable mode.
# This installs from inside em-llm-model/ which means the bundled
# en_core_web_sm-3.7.1 wheel resolves via its relative path in
# em-llm-model/requirements.txt.
cd "$REPRO_ROOT/em-llm-model"
pip install --upgrade pip
pip install -r requirements.txt
pip install -e .

echo "[setup] Done. Activate with: conda activate emllm"
