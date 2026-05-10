# Analysis

Comparison artifacts produced from `reproduction/results/`. Notebooks here
load JSONL outputs from the per-system results trees and emit:

- `results_table.md` — your numbers (local + ASAX) vs. paper Table X
- `cross_system_consistency.md` — local vs. ASAX agreement on shared benchmarks
- `per_task_diff.csv` — task-level absolute deltas
- `plots.ipynb` — figures for the manuscript

Notebooks load results paths via the `RESULTS_ROOT` env var so they work
without hardcoding either system's paths:

```python
import os, json
from pathlib import Path
local = Path(os.environ.get("REPRO_ROOT", ".")) / "reproduction/results/local"
asax  = Path(os.environ.get("REPRO_ROOT", ".")) / "reproduction/results/asax"
```
