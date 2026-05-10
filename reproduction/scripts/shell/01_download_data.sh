#!/usr/bin/env bash
# Calls upstream's data download script (LongBench via HF datasets, ∞-Bench
# via wget). Must run somewhere with internet — login node on ASAX, the local
# WSL shell otherwise.

set -euo pipefail

: "${EMLLM_ROOT:?source reproduction/scripts/env/<system>.env first}"

cd "$EMLLM_ROOT"
bash scripts/download.sh

echo "[data] LongBench → $EMLLM_ROOT/benchmark/data/longbench/"
echo "[data] ∞-Bench   → $EMLLM_ROOT/benchmark/data/infinite-bench/"
