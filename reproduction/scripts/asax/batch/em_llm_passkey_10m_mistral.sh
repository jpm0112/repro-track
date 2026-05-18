#!/bin/bash
# Paper row 12: Extended PassKey 10M, Mistral-7B-Instruct-v0.2, EM-LLM_S.
# Headline figure 2 result. Multi-GPU layer split.
# Submit via:  qsub-emllm em_llm_passkey_10m_mistral
# Resources:   4 GPUs, 48h, 512gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="pk10m-mistral-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

# Multi-GPU split for the 10M context length.
export CUDA_VISIBLE_DEVICES=0,1,2,3
export MODEL=mistral
export VARIANT=s
export EXTENDED_PASSKEY_K=10240
exec bash "$REPO_ROOT/reproduction/scripts/shell/04_run_passkey_extended.sh"
