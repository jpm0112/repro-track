#!/usr/bin/env bash
# Run the InfLLM ∞-Bench baseline. Same shape as 06_run_infllm_longbench.sh
# but with ∞-Bench's 6-task default set and disk offload enabled (long tasks).
# Paper Table 2 reports InfLLM ∞-Bench only for the 7-8B models
# (mistral, llama3, llama31).
#
# Knobs:
#   MODEL                  one of mistral|llama3|llama31 (paper-reported)
#                          (phi3_mini|phi35_mini will run but no paper baseline)
#   DATASETS               default = upstream's 6 ∞-Bench tasks
#   ALLOW_DISK_OFFLOAD     default True
#   EXTRA_OVERRIDES        extra OmegaConf CLI args

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${INFLLM_ROOT:?INFLLM_ROOT not set; re-source env file after populating infllm-model/}"
: "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

[[ -d "$INFLLM_ROOT" && -f "$INFLLM_ROOT/benchmark/pred.py" ]] || {
    echo "[infllm-infbench] FATAL: infllm-model/ is not a populated InfLLM checkout."
    echo "                         See docs/infllm_setup.md to clone it."
    exit 1
}

MODEL="${MODEL:-mistral}"
DATASETS="${DATASETS:-code_debug,math_find,kv_retrieval,passkey,number_string,longbook_choice_eng}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-True}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"

# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_infllm_budgets.sh"
resolve_infllm_budget "$MODEL"

OUT_DIR="$RESULTS_ROOT/infinitebench_infllm/${MODEL}_${BUDGET_TAG}"
mkdir -p "$OUT_DIR"

CONFIG=""
for candidate in \
    "config/${MODEL}.yaml" \
    "config/${MODEL}-inf-llm.yaml" \
    "config/inf-llm-${MODEL}.yaml" \
; do
    if [[ -f "$INFLLM_ROOT/$candidate" ]]; then
        CONFIG="$candidate"
        break
    fi
done
if [[ -z "$CONFIG" ]]; then
    echo "[infllm-infbench] FATAL: no InfLLM config found for MODEL=$MODEL." >&2
    exit 1
fi
echo "[infllm-infbench] using config: $INFLLM_ROOT/$CONFIG"

cd "$INFLLM_ROOT"
python benchmark/pred.py \
    --config_path "$CONFIG" \
    --output_dir_path "$OUT_DIR" \
    --datasets "$DATASETS" \
    --world_size 1 \
    --rank 0 \
    --allow_disk_offload "$ALLOW_DISK_OFFLOAD" \
    model.disk_offload_dir="$EMLLM_OFFLOAD_DIR" \
    ${BUDGET_OVERRIDES} \
    ${EXTRA_OVERRIDES}

python benchmark/eval.py --dir_path "$OUT_DIR"

python "$REPRO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
    || echo "[summary] warning: summary generation failed; result.json is still valid"

echo "[infllm-infbench] Done. Results: $OUT_DIR/result.json"
echo "[infllm-infbench] Side-by-side: $OUT_DIR/summary.md"
