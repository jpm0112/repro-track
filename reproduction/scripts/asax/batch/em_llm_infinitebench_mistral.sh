#!/bin/bash
# Paper row 7: Infinity-Bench, Mistral-7B-Instruct-v0.2, EM-LLM_SM+C, 4K+2K.
# Submit via:  qsub-emllm em_llm_infinitebench_mistral
# Resources:   1 GPU, 26h, 200gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="ib-mistral-smc"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=mistral
export VARIANT=sm_c
exec bash "$REPO_ROOT/reproduction/scripts/shell/03_run_infinitebench.sh"
