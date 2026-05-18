#!/usr/bin/env bash
# Run the extended PassKey reproduction (∞-Bench's passkey task synthetically
# extended via extend_passkey_context() in pred.py:131). Length controlled by
# the `extended_passkey` field in the model YAML — overridable from the CLI.
#
# Paper Figure 2 (right) reports EM-LLM_S on Mistral at 1M and 10M tokens;
# the variant default below is therefore S (NOT mistral's Table 2 SM+C).
# Override with VARIANT=sm_c if you want to test the contiguity-buffered
# variant at extended lengths.
#
# Knobs:
#   MODEL                   default mistral
#   VARIANT                 default S; can be set to sm|s_c|sm_c
#   EXTENDED_PASSKEY_K      length in 1000s of tokens; default 1024 (= 1M tokens)
#   ALLOW_DISK_OFFLOAD      default True
#   EXTRA_OVERRIDES         extra OmegaConf CLI args

set -euo pipefail

: "${REPRO_ROOT:?source reproduction/scripts/env/<system>.env first}"
: "${EMLLM_ROOT:?}" "${EMLLM_OFFLOAD_DIR:?}" "${RESULTS_ROOT:?}"

MODEL="${MODEL:-mistral}"
EXTENDED_PASSKEY_K="${EXTENDED_PASSKEY_K:-1024}"
ALLOW_DISK_OFFLOAD="${ALLOW_DISK_OFFLOAD:-True}"
EXTRA_OVERRIDES="${EXTRA_OVERRIDES:-}"

# Passkey uses EM-LLM_S in the paper (Figure 2 right) regardless of base
# model, so the default here is S unless the user overrides VARIANT.
# shellcheck disable=SC1091
source "$REPRO_ROOT/reproduction/scripts/shell/_paper_variants.sh"
resolve_paper_variant "$MODEL" "${VARIANT:-s}"

OUT_DIR="$RESULTS_ROOT/passkey_${EXTENDED_PASSKEY_K}k/${MODEL}_${VARIANT}"
mkdir -p "$OUT_DIR"

cd "$EMLLM_ROOT"
python benchmark/pred.py \
    --config_path "config/${MODEL}.yaml" \
    --output_dir_path "$OUT_DIR" \
    --datasets "passkey__long" \
    --world_size 1 \
    --rank 0 \
    --allow_disk_offload "$ALLOW_DISK_OFFLOAD" \
    model.disk_offload_dir="$EMLLM_OFFLOAD_DIR" \
    extended_passkey="$EXTENDED_PASSKEY_K" \
    ${VARIANT_OVERRIDES} \
    ${MODEL_GAMMA_OVERRIDE} \
    ${EXTRA_OVERRIDES}

python benchmark/eval.py --dir_path "$OUT_DIR"

python "$REPRO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
    || echo "[summary] warning: summary generation failed; result.json is still valid"

echo "[passkey-${EXTENDED_PASSKEY_K}k] Done. Results: $OUT_DIR/result.json"
echo "[passkey-${EXTENDED_PASSKEY_K}k] Side-by-side: $OUT_DIR/summary.md"
