#!/bin/bash
# Extended PassKey reproduction on ASAX.
# 10M tokens needs 4 GPUs and ~48h; 1M tokens is the cheaper version
# that fits in ~24h on a single GPU.
#
# Submit via ASA's wrapper:
#   run_gpu reproduction/scripts/asax/passkey_10m.sh
# At the prompts answer (for 10M):
#   queue:    gpu
#   cores:    16
#   walltime: 48:00:00
#   memory:   512gb
#   GPUs:     4
# For 1M, request 1 GPU / 32gb / 26:00:00 instead.
#
# Configure via ~/repro-track/.job_config — example for the 10M Mistral run:
#   cat > ~/repro-track/.job_config <<EOF
#   export MODEL=mistral
#   export EXTENDED_PASSKEY_K=10240
#   export CUDA_VISIBLE_DEVICES=0,1,2,3      # required for 10M (4-GPU split)
#   EOF
#   run_gpu reproduction/scripts/asax/passkey_10m.sh
#
# For a 1M smoke test (~24h, 1 GPU): set EXTENDED_PASSKEY_K=1024 and leave
# CUDA_VISIBLE_DEVICES at the default (single GPU).

BENCH_TAG="passkey"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_asax_job_setup.sh"

echo "=== handing off to 04_run_passkey_extended.sh ==="
bash reproduction/scripts/shell/04_run_passkey_extended.sh
RC=$?
echo "=== 04_run_passkey_extended.sh exited with code $RC ==="
exit $RC
