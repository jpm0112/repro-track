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
# ASA gpu queue caps at 120gb RAM (vs paper's ~200gb usage on long ∞-Bench
# tasks). Force disk offload sooner so the long contexts don't OOM the host.
export EXTRA_OVERRIDES="model.min_free_cpu_memory=8 model.disk_offload_threshold=100000 model.vector_offload_threshold=30000"
exec bash "$REPO_ROOT/reproduction/scripts/shell/03_run_infinitebench.sh"
