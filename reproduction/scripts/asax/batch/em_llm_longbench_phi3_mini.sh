#!/bin/bash
# Paper row 5: LongBench, Phi-3-mini-128k-instruct, EM-LLM_S, 1K+3K.
# Submit via:  qsub-emllm em_llm_longbench_phi3_mini
# Resources:   1 GPU, 14h, 128gb.

REPO_ROOT="${PBS_O_WORKDIR:-$HOME/repro-track}"
BENCH_TAG="lb-phi3mini-s"
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/asax/_asax_job_setup.sh"

export MODEL=phi3_mini
export VARIANT=s
exec bash "$REPO_ROOT/reproduction/scripts/shell/02_run_longbench.sh"
