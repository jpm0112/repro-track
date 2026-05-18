# Analysis

Two layers of artifacts live here:

## Per-run summaries (auto-generated next to result.json)

Every reproduction run emits, alongside upstream's `result.json`:

- `summary.md` -- paper-mirroring side-by-side table for a single
  (benchmark, base model) pair: paper EM-LLM number, paper baseline
  (Full-Context for Llama-3.1, InfLLM for other models), our number,
  and the delta.
- `summary.csv` -- same row data for downstream notebooks.

Both files are written by `make_summary.py`, called automatically from each
of the run wrappers (`02_run_longbench.sh`, `03_run_infinitebench.sh`,
`04_run_passkey_extended.sh`) immediately after upstream's `eval.py`. The
call is soft-failing so a summary error never invalidates a real result.

Re-run a summary by hand (e.g. after updating paper numbers):

```bash
python reproduction/analysis/make_summary.py \
    reproduction/results/local/longbench/mistral
```

### Paper numbers

`paper_baselines.py` holds the paper's Tables 1 and 2 as Python constants,
sourced from `em-llm-model/benchmark/further_results.md`. Edit that file to
adjust any baseline and every future summary updates automatically.

## Cross-system aggregation (manual)

Notebooks in this directory load summaries from both
`reproduction/results/local/` and `reproduction/results/asax/` and emit:

- `results_table.md` -- combined view of local + ASAX numbers vs. paper Table X
- `cross_system_consistency.md` -- local vs. ASAX agreement on shared benchmarks
- `per_task_diff.csv` -- task-level absolute deltas
- `plots.ipynb` -- figures for the manuscript

Notebooks load results paths via the `REPRO_ROOT` env var so they work
without hardcoding either system's paths:

```python
import os, json
from pathlib import Path
local = Path(os.environ.get("REPRO_ROOT", ".")) / "reproduction/results/local"
asax  = Path(os.environ.get("REPRO_ROOT", ".")) / "reproduction/results/asax"
```
