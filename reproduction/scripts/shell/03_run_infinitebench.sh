#!/usr/bin/env bash
# Run ∞-Bench reproduction. Same shape as 02_run_longbench.sh but with the
# upstream ∞-Bench dataset list, and disk offload enabled by default since
# kv_retrieval and longbook_qa_eng exceed `disk_offload_threshold`.
#
# Knobs:
#   MODEL                  one of mistral|llama3|llama31|phi3_mini|phi35_mini
#   DATASETS               comma-separated subset; default = upstream's ∞-Bench list
#   ALLOW_DISK_OFFLOAD     True|False; default True
#   EXTRA_OVERRIDES        extra OmegaConf CLI args appended verbatim. On the
#                          local backend with 32 GB RAM, expect to set this to
#                          "model.min_free_cpu_memory=8 model.disk_offload_threshold=200000"

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${EMLLM_ROOT:?}" "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

MODEL="${MODEL:-mistral}"
DATASETS="${DATASETS:-code_debug,math_find,kv_retrieval,passkey,number_string,longbook_choice_eng}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-True}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"

OUT_DIR="$RESULTS_ROOT/infinitebench/$MODEL"
mkdir -p "$OUT_DIR"

cd "$EMLLM_ROOT"
python benchmark/pred.py \
    --config_path "config/${MODEL}.yaml" \
    --output_dir_path "$OUT_DIR" \
    --datasets "$DATASETS" \
    --world_size 1 \
    --rank 0 \
    --allow_disk_offload "$ALLOW_DISK_OFFLOAD" \
    model.disk_offload_dir="$EMLLM_OFFLOAD_DIR" \
    ${EXTRA_OVERRIDES}

python benchmark/eval.py --dir_path "$OUT_DIR"
echo "[infinitebench] Done. Results: $OUT_DIR/result.json"
