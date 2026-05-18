#!/bin/bash
# Paper row 10: Infinity-Bench, Llama-3.1-8B-Instruct, EM-LLM_S (Table 1), 4K+4K.
# Submit via:  qsub-emllm em_llm_infinitebench_llama31_s
# Resources:   1 GPU, 26h, 200gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="ib-llama31-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=llama31
export VARIANT=s
exec bash "$REPO_ROOT/reproduction/scripts/shell/03_run_infinitebench.sh"
