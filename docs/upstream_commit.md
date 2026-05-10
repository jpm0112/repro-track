# Upstream commit

The `em-llm-model/` directory contains a vendored copy of
[`em-llm/EM-LLM-model`](https://github.com/em-llm/EM-LLM-model) at the
following pinned commit:

| field | value |
|-------|-------|
| Repository | `em-llm/EM-LLM-model` |
| Commit | `edb2e4a6988c0c2a15637d380e81f04f1a1a531a` |
| Cloned on | 2026-05-10 |

## Verifying integrity

From the repository root:

```bash
cd em-llm-model
git rev-parse HEAD                    # must print edb2e4a6988c0c2a15637d380e81f04f1a1a531a
git diff HEAD                         # must be empty
cd ..
git diff em-llm-model/                # must be empty (post-commit)
```

If any of those produce output, the upstream copy has been modified. The
reproduction-fidelity invariant requires all three checks to pass before
results are published.

## Why a vendored copy and not a submodule

Submodule was preferred during planning, but at implementation time the
upstream clone was already in-place from earlier interactive work, and
re-cloning via `git submodule add` would have re-pulled ~100 MB without any
information gain (the SHA is recorded in this file). The vendored layout
preserves the same guarantee — bit-identity at the recorded SHA — and is
simpler for cloners (`git clone` instead of `git clone --recursive`).

To convert to a submodule later (e.g. before TMLR submission for cleaner
review of `.gitmodules`), the steps are:

```bash
rm -rf em-llm-model
git submodule add https://github.com/em-llm/EM-LLM-model em-llm-model
git -C em-llm-model checkout edb2e4a6988c0c2a15637d380e81f04f1a1a531a
```
