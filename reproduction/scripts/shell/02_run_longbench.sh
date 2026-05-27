#!/usr/bin/env bash
# Run LongBench reproduction. Bypasses upstream's run.sh so we can redirect
# outputs into our reproduction/results/ tree and apply OmegaConf overrides
# without editing any upstream file.
#
# Knobs (env vars):
#   MODEL                  one of mistral|llama3|llama31|phi3_mini|phi35_mini
#   VARIANT                paper EM-LLM variant tag (s|sm|s_c|sm_c). Defaults to
#                            the paper Table 2 variant for the model
#                            (mistral=sm_c, llama31=sm, others=s). Set
#                            VARIANT=s explicitly to reproduce Table 1's row
#                            for LLaMA-3.1.
#   DATASETS               comma-separated subset; defaults to upstream's full
#                            English LongBench list (15 tasks)
#   ALLOW_DISK_OFFLOAD     True|False; default False (LongBench fits without)
#   EXTRA_OVERRIDES        extra OmegaConf CLI args; appended AFTER the
#                            paper-variant overrides (so user wins)
#   SKIP_SCORING           1 to skip eval.py + make_summary.py at the end.
#                            Use when submitting per-task jobs and scoring
#                            separately via score_run.sh after all tasks land.
#
# Pre-req: source reproduction/scripts/env/<system>.env then
#          conda activate emllm.

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${EMLLM_ROOT:?}" "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

MODEL="${MODEL:-mistral}"
DATASETS="${DATASETS:-2wikimqa,gov_report,hotpotqa,lcc,multi_news,multifieldqa_en,musique,narrativeqa,passage_retrieval_en,qasper,qmsum,repobench-p,samsum,trec,triviaqa}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-False}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"
SKIP_SCORING="${SKIP_SCORING:-0}"

# Resolve paper-faithful variant overrides (sets VARIANT, VARIANT_OVERRIDES,
# MODEL_GAMMA_OVERRIDE). Pass through any user-supplied VARIANT.
# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_paper_variants.sh"
resolve_paper_variant "$MODEL" "${VARIANT:-}"

# Output dir includes variant tag so different variants for the same model do
# not overwrite each other.
OUT_DIR="$RESULTS_ROOT/longbench/${MODEL}_${VARIANT}"
mkdir -p "$OUT_DIR"

# Snapshot hardware + software fingerprint for reproducibility audits.
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

if [[ "$SKIP_SCORING" == "1" ]]; then
    echo "[longbench] SKIP_SCORING=1: skipping eval.py and make_summary.py."
    echo "[longbench] Run score_run.sh after all per-task jobs finish."
else
    python benchmark/eval.py --dir_path "$OUT_DIR"

    # Paper-mirroring side-by-side summary (soft-fail to never block the run).
    python "$REPRO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
        || echo "[summary] warning: summary generation failed; result.json is still valid"

    echo "[longbench] Done. Results: $OUT_DIR/result.json"
    echo "[longbench] Side-by-side: $OUT_DIR/summary.md"
fi
