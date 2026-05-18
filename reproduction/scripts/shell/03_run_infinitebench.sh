#!/usr/bin/env bash
# Run ∞-Bench reproduction. Same shape as 02_run_longbench.sh but with the
# upstream ∞-Bench dataset list, and disk offload enabled by default since
# kv_retrieval and longbook_qa_eng exceed `disk_offload_threshold`.
#
# Knobs:
#   MODEL                  one of mistral|llama3|llama31|phi3_mini|phi35_mini
#                            (paper Table 2 reports only mistral, llama3, llama31)
#   VARIANT                paper variant tag (defaults to model's Table 2 variant)
#   DATASETS               comma-separated subset; default = upstream's 6 ∞-Bench tasks
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

# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_paper_variants.sh"
resolve_paper_variant "$MODEL" "${VARIANT:-}"

OUT_DIR="$RESULTS_ROOT/infinitebench/${MODEL}_${VARIANT}"
mkdir -p "$OUT_DIR"

# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_capture_run_metadata.sh"
write_run_metadata "$OUT_DIR"

cd "$EMLLM_ROOT"
python benchmark/pred.py \
    --config_path "config/${MODEL}.yaml" \
    --output_dir_path "$OUT_DIR" \
    --datasets "$DATASETS" \
    --world_size 1 \
    --rank 0 \
    --allow_disk_offload "$ALLOW_DISK_OFFLOAD" \
    model.disk_offload_dir="$EMLLM_OFFLOAD_DIR" \
    ${VARIANT_OVERRIDES} \
    ${MODEL_GAMMA_OVERRIDE} \
    ${EXTRA_OVERRIDES}

python benchmark/eval.py --dir_path "$OUT_DIR"

python "$REPRO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
    || echo "[summary] warning: summary generation failed; result.json is still valid"

echo "[infinitebench] Done. Results: $OUT_DIR/result.json"
echo "[infinitebench] Side-by-side: $OUT_DIR/summary.md"
