# InfLLM upstream commit

The `infllm-model/` directory will contain a vendored copy of
[`thunlp/InfLLM`](https://github.com/thunlp/InfLLM) — the baseline EM-LLM is
compared against in paper Table 2. Until populated, the directory holds only
`PLACEHOLDER.md`.

| field | value |
|-------|-------|
| Repository | `thunlp/InfLLM` |
| Commit | _pinned after first clone — paste the SHA here_ |
| Cloned on | _yyyy-mm-dd_ |

## Populating the directory

Run from the repo root, on a login node with internet access:

```bash
# Drop the placeholder, clone fresh, pin the SHA.
rm -rf infllm-model
git clone https://github.com/thunlp/InfLLM infllm-model
cd infllm-model
git rev-parse HEAD                # paste this into the table above
cd ..
```

After cloning, edit this file with the actual commit hash and date so future
runs can verify they're using the same upstream code.

## Verifying integrity

Same convention as `docs/upstream_commit.md`:

```bash
cd infllm-model
git rev-parse HEAD                # must match the table above
git diff HEAD                     # must be empty
cd ..
git diff infllm-model/            # must be empty (post-commit)
```

## Why a vendored copy and not a live submodule

Same reason as `em-llm-model/` — see `docs/upstream_commit.md`. The SHA
recorded here is the single source of truth; the `.gitmodules` entry exists
only to document the upstream URL.
