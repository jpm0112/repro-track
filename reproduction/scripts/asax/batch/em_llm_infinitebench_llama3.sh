#!/bin/bash
# Paper row 8: Infinity-Bench, Llama-3-8B-Instruct, EM-LLM_S, 4K+4K, gamma=2.
# Submit via:  qsub-emllm em_llm_infinitebench_llama3
# Resources:   1 GPU, 26h, 200gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="ib-llama3-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=llama3
export VARIANT=s
export EXTRA_OVERRIDES="model.min_free_cpu_memory=8 model.disk_offload_threshold=100000 model.vector_offload_threshold=30000"
exec bash "$REPO_ROOT/reproduction/scripts/shell/03_run_infinitebench.sh"
