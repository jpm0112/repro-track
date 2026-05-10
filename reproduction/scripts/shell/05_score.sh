#!/usr/bin/env bash
# Re-score an existing reproduction/results directory without re-running
# inference. Useful when iterating on metric definitions or after partial
# failures have been resumed.
#
# Usage:
#   bash reproduction/scripts/shell/05_score.sh reproduction/results/local/longbench/mistral

set -euo pipefail

: "${EMLLM_ROOT:?source reproduction/scripts/env/<system>.env first}"

DIR="${1:-}"
[[ -n "$DIR" && -d "$DIR" ]] || { echo "Usage: $0 <results_dir>"; exit 2; }

cd "$EMLLM_ROOT"
python benchmark/eval.py --dir_path "$(realpath "$DIR")"
echo "[score] Done. result.json refreshed in $DIR"
