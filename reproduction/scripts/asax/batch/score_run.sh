#!/usr/bin/env bash
# Run eval.py + make_summary.py on a wrapper's shared output directory.
# Use this after all per-task pred jobs (submitted with --per-task) have
# finished writing their .jsonl files.
#
# Usage (from repo root on the ASAX login node):
#   bash reproduction/scripts/asax/batch/score_run.sh em_llm_infinitebench_mistral
#   bash reproduction/scripts/asax/batch/score_run.sh em_llm_longbench_mistral
#
# The script:
#   1. Sources asax.env for REPRO_ROOT / EMLLM_ROOT / RESULTS_ROOT.
#   2. Extracts MODEL and VARIANT from the wrapper script itself (parses
#      the `export MODEL=` / `export VARIANT=` lines via grep).
#   3. Sources _paper_variants.sh to confirm/resolve the variant.
#   4. Resolves OUT_DIR the same way the shell runners do:
#        $RESULTS_ROOT/<bench>/<model>_<variant>/
#   5. Runs eval.py then make_summary.py (soft-fail on summary).
#
# This script intentionally does not submit a PBS job — scoring is fast
# (seconds to minutes) and is safe to run directly on the login node.

set -euo pipefail

BATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BATCH_DIR/../../../.." && pwd)"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <wrapper-name>"
    echo "  Example: $0 em_llm_infinitebench_mistral"
    exit 1
fi

name="$1"
wrapper="$BATCH_DIR/${name}.sh"

if [[ ! -f "$wrapper" ]]; then
    echo "ERROR: wrapper not found: $wrapper" >&2
    exit 1
fi

# Source asax.env to get REPRO_ROOT, EMLLM_ROOT, RESULTS_ROOT.
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/env/asax.env"

# Extract MODEL and VARIANT from the wrapper's export lines.
# The wrappers contain lines like:
#   export MODEL=mistral
#   export VARIANT=sm_c
MODEL="$(grep -E '^export MODEL=' "$wrapper" | head -1 | sed 's/^export MODEL=//')"
VARIANT="$(grep -E '^export VARIANT=' "$wrapper" | head -1 | sed 's/^export VARIANT=//')"

if [[ -z "$MODEL" ]]; then
    echo "ERROR: could not parse MODEL from $wrapper" >&2
    exit 1
fi
if [[ -z "$VARIANT" ]]; then
    echo "ERROR: could not parse VARIANT from $wrapper" >&2
    exit 1
fi

export MODEL
export VARIANT

# Confirm/resolve variant overrides (sets VARIANT, VARIANT_OVERRIDES,
# MODEL_GAMMA_OVERRIDE). We only need VARIANT here for the dir path; the
# rest are unused since we don't run pred.py.
# shellcheck disable=SC1091
source "$REPO_ROOT/reproduction/scripts/shell/_paper_variants.sh"
resolve_paper_variant "$MODEL" "$VARIANT"

# Determine benchmark directory name from wrapper prefix.
if [[ "$name" == em_llm_longbench_* ]]; then
    bench_dir="longbench"
elif [[ "$name" == em_llm_infinitebench_* ]]; then
    bench_dir="infinitebench"
else
    echo "ERROR: cannot determine bench dir for '$name'." >&2
    echo "  Expected prefix: em_llm_longbench_* or em_llm_infinitebench_*" >&2
    exit 1
fi

OUT_DIR="$RESULTS_ROOT/${bench_dir}/${MODEL}_${VARIANT}"

if [[ ! -d "$OUT_DIR" ]]; then
    echo "ERROR: output directory not found: $OUT_DIR" >&2
    echo "  Has the per-task pred job run yet?" >&2
    exit 1
fi

echo "[score_run] Scoring: $OUT_DIR"
echo "[score_run] Running eval.py ..."

cd "$EMLLM_ROOT"
python benchmark/eval.py --dir_path "$OUT_DIR"

echo "[score_run] Running make_summary.py ..."
python "$REPO_ROOT/reproduction/analysis/make_summary.py" "$OUT_DIR" \
    || echo "[score_run] warning: summary generation failed; result.json is still valid"

echo "[score_run] Done."
echo "[score_run] Results:    $OUT_DIR/result.json"
echo "[score_run] Side-by-side: $OUT_DIR/summary.md"
