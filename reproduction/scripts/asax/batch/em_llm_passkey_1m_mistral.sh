#!/bin/bash
# Paper row 11: Extended PassKey 1M, Mistral-7B-Instruct-v0.2, EM-LLM_S.
# Submit via:  qsub-emllm em_llm_passkey_1m_mistral
# Resources:   1 GPU, 26h, 64gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="pk1m-mistral-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=mistral
export VARIANT=s
export EXTENDED_PASSKEY_K=1024
exec bash "$REPO_ROOT/reproduction/scripts/shell/04_run_passkey_extended.sh"
