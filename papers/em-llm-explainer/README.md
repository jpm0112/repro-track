# EM-LLM Reader's Companion

A LaTeX-built PDF that walks through the EM-LLM paper (Fountas et al., ICLR 2025) and the vendored implementation under `../../em-llm-model/`. Intended as study material for the MLRC 2026 reproduction.

## Build

From this directory:

```
latexmk -pdf main.tex
```

Requires a TeX distribution with `latexmk`, `pdflatex`, `biber`, and the packages listed in `preamble.tex` (all standard in TeX Live and MiKTeX). The compiled artifact is `main.pdf`.

Clean intermediate files with `latexmk -C`.
