#!/usr/bin/env bash
# Run LongBench reproduction. Bypasses upstream's run.sh so we can redirect
# outputs into our reproduction/results/ tree and apply OmegaConf overrides
# without editing any upstream file.
#
# Knobs (env vars):
#   MODEL                  one of mistral|llama3|llama31|phi3_mini|phi35_mini
#   DATASETS               comma-separated subset; defaults to upstream's full LongBench list
#   ALLOW_DISK_OFFLOAD     True|False; default False (LongBench fits without offload)
#   EXTRA_OVERRIDES        extra OmegaConf CLI args appended verbatim
#
# Pre-req: source reproduction/scripts/env/<system>.env, then
#          conda activate emllm.

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${EMLLM_ROOT:?}" "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

MODEL="${MODEL:-mistral}"
DATASETS="${DATASETS:-2wikimqa,gov_report,hotpotqa,lcc,multi_news,multifieldqa_en,musique,narrativeqa,passage_retrieval_en,qasper,qmsum,repobench-p,samsum,trec,triviaqa}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-False}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"

OUT_DIR="$RESULTS_ROOT/longbench/$MODEL"
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
echo "[longbench] Done. Results: $OUT_DIR/result.json"
