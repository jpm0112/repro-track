#!/bin/bash
# Paper row 3: LongBench, Llama-3.1-8B-Instruct, EM-LLM_SM (Table 2), 4K+4K.
# Submit via:  qsub-emllm em_llm_longbench_llama31_sm
# Resources:   1 GPU, 14h, 128gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="lb-llama31-sm"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=llama31
export VARIANT=sm
exec bash "$REPO_ROOT/reproduction/scripts/shell/02_run_longbench.sh"
