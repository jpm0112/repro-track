#!/bin/bash
# Paper row 2: LongBench, Llama-3-8B-Instruct, EM-LLM_S, 4K+4K, gamma=2.
# Submit via:  qsub-emllm em_llm_longbench_llama3
# Resources:   1 GPU, 14h, 128gb.
# Pre-req: Llama-3 weights downloaded
# (MODELS="meta-llama/Meta-Llama-3-8B-Instruct" bash 00b_login_node_prep.sh)

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="lb-llama3-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=llama3
export VARIANT=s
exec bash "$REPO_ROOT/reproduction/scripts/shell/02_run_longbench.sh"
