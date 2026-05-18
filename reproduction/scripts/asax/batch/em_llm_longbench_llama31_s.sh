#!/bin/bash
# Paper row 4: LongBench, Llama-3.1-8B-Instruct, EM-LLM_S (Table 1), 4K+4K.
# Same model as row 3 but variant S (Table 1's per-task row).
# Submit via:  qsub-emllm em_llm_longbench_llama31_s
# Resources:   1 GPU, 14h, 128gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="lb-llama31-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=llama31
export VARIANT=s
exec bash "$REPO_ROOT/reproduction/scripts/shell/02_run_longbench.sh"
