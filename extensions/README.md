# Extensions

Each subfolder here is a self-contained "added value" contribution beyond
faithful verification, as required by TMLR's
[Reproducibility Certification](https://jmlr.org/tmlr/editorial-policies.html):

> "Beyond simple verification, the paper must contribute significant added
> value through additional baselines, analysis, ablations, or insights."

Layout convention per extension:

```
extensions/<name>/
├── README.md            # what, why, results
├── configs/             # OmegaConf overrides specific to this extension
├── scripts/             # any code unique to this extension
├── results/             # outputs (not committed if large; .gitignore'd)
└── analysis/            # plots, tables, notebooks
```

Each extension should not modify `em-llm-model/` either — the same invariant
applies. New code lives entirely under the extension's folder.

## Candidate extensions

(populate as the reproduction progresses; treat the list below as scratch)

- ablation: surprisal threshold γ sweep on LongBench
- ablation: similarity-refinement on/off comparison with disagreement analysis
- baseline: comparison vs. full-context RAG with a modern dense retriever
- insight: event-segmentation alignment to human-annotated narrative events
