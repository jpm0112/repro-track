#!/usr/bin/env bash
# Run the extended PassKey reproduction (∞-Bench's passkey task synthetically
# extended via extend_passkey_context() in pred.py:131). Length controlled by
# the `extended_passkey` field in the model YAML — overridable from the CLI.
#
# Headline reproduction: 10M-token PassKey on Mistral, requires ASAX (multi
# A100). On local 24 GB / 32 GB RAM, even the 1M variant is impractical.
#
# Knobs:
#   MODEL                   default mistral
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

OUT_DIR="$RESULTS_ROOT/passkey_${EXTENDED_PASSKEY_K}k/$MODEL"
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
    ${EXTRA_OVERRIDES}

python benchmark/eval.py --dir_path "$OUT_DIR"
echo "[passkey-${EXTENDED_PASSKEY_K}k] Done. Results: $OUT_DIR/result.json"
