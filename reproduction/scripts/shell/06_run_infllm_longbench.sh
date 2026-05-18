#!/usr/bin/env bash
# Run the InfLLM LongBench baseline that the EM-LLM paper compares against
# in Table 2. InfLLM lives in ../infllm-model/ as a sibling vendored repo.
#
# Knobs (env vars):
#   MODEL                  one of mistral|llama3|llama31|phi3_mini|phi35_mini
#   DATASETS               comma-separated subset; defaults to upstream's full
#                            English LongBench list (15 tasks)
#   ALLOW_DISK_OFFLOAD     True|False; default False (LongBench fits without)
#   EXTRA_OVERRIDES        extra OmegaConf CLI args appended after budget overrides
#
# Pre-reqs:
#   - source reproduction/scripts/env/<system>.env
#   - infllm-model/ populated (see docs/infllm_setup.md)
#   - conda activate emllm

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${INFLLM_ROOT:?INFLLM_ROOT not set; re-source env file after populating infllm-model/}"
: "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

[[ -d "$INFLLM_ROOT" && -f "$INFLLM_ROOT/benchmark/pred.py" ]] || {
    echo "[infllm-longbench] FATAL: infllm-model/ is not a populated InfLLM checkout."
    echo "                          See docs/infllm_setup.md to clone it."
    exit 1
}

MODEL="${MODEL:-mistral}"
DATASETS="${DATASETS:-2wikimqa,gov_report,hotpotqa,lcc,multi_news,multifieldqa_en,musique,narrativeqa,passage_retrieval_en,qasper,qmsum,repobench-p,samsum,trec,triviaqa}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-False}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"

# Resolve paper-faithful (n_local, n_mem) for this model. Sets BUDGET_TAG and
# BUDGET_OVERRIDES so the wrapper doesn't depend on InfLLM's stock defaults.
# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_infllm_budgets.sh"
resolve_infllm_budget "$MODEL"

# Sibling-parent layout: longbench_infllm/<model>_<budget>/ next to
# longbench/<model>_<variant>/ for EM-LLM. make_summary.py uses the _infllm
# suffix on the parent to switch its comparator dictionary.
OUT_DIR="$RESULTS_ROOT/longbench_infllm/${MODEL}_${BUDGET_TAG}"
mkdir -p "$OUT_DIR"

# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_capture_run_metadata.sh"
write_run_metadata "$OUT_DIR"

# InfLLM's per-model YAML naming may differ from EM-LLM's. We try a few
# likely paths in order before failing out so the user gets a clear hint.
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
    echo "[infllm-longbench] FATAL: no InfLLM config found for MODEL=$MODEL."
    echo "  Looked in: $INFLLM_ROOT/config/{${MODEL}.yaml, ${MODEL}-inf-llm.yaml, inf-llm-${MODEL}.yaml}"
    echo "  Either point to an existing one or copy a similar config into the InfLLM tree."
    exit 1
fi
echo "[infllm-longbench] using config: $INFLLM_ROOT/$CONFIG"

cd "$INFLLM_ROOT"
# CLI assumed to mirror EM-LLM's pred.py (EM-LLM is a fork). If InfLLM's
# pred.py args have drifted, adjust this block — see docs/infllm_setup.md.
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

# Paper-mirroring side-by-side. make_summary.py auto-detects this is an
# InfLLM run from the parent dir name (longbench_infllm) and swaps to the
# InfLLM comparator column from paper Table 2.
python "$REPRO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
    || echo "[summary] warning: summary generation failed; result.json is still valid"

echo "[infllm-longbench] Done. Results: $OUT_DIR/result.json"
echo "[infllm-longbench] Side-by-side: $OUT_DIR/summary.md"
