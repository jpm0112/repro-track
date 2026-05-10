# Reproduction notes

Running log of decisions, deviations, and observations during the EM-LLM
reproduction. Append-only; do not delete entries even if superseded — the
audit trail is part of what reviewers read.

## Status snapshot

| date | system | benchmark | model | status | notes |
|------|--------|-----------|-------|--------|-------|
| 2026-05-10 | — | — | — | scaffolded | repo structure created; no runs yet |

## Decisions

### Vendored upstream copy (not submodule)

Recorded in [`upstream_commit.md`](upstream_commit.md). Rationale: the clone
already existed at planning time and the SHA is documented; submodule conversion
buys nothing functional. May convert pre-submission for review legibility.

### Wrapper scripts bypass `em-llm-model/scripts/run.sh`

`run.sh` hardcodes `output_dir_path="${base_dir}/benchmark/results/..."` which
would write outputs *inside* `em-llm-model/`. To keep outputs in our
`reproduction/results/<system>/` tree without editing upstream, the wrappers
in `reproduction/scripts/shell/` invoke `python benchmark/pred.py` directly
and pass `--output_dir_path` explicitly. The orchestration logic in `run.sh`
(multi-rank GPU partitioning) is not needed for the single-rank-multi-GPU
case used by ∞-Bench / 10M-passkey on ASAX (accelerate auto-splits the model
when `torch.cuda.device_count() > 1`).

### Default `world_size=1` in wrappers

Upstream's `run.sh` data-parallelizes by spawning `world_size/num_gpus_per_job`
ranks each consuming `data[rank::world_size]`. For headline reproductions on
ASAX we instead model-parallelize a single rank across multiple GPUs (the path
the paper uses for the 10M-token claim). Data-parallel runs can be added later
as `*_parallel.sh` variants.

## Deviations from paper

(none yet — fill in as runs reveal them)

## Open questions

- Exact ASAX module names for `cuda/*` and `anaconda/*` — placeholders in
  `reproduction/scripts/env/asax.env` are last-known-good and need to be
  verified after first login. Update there directly when known.
- ASAX GPU partition name — set as `ampere` in all sbatch files. Verify with
  `sinfo -p ampere` and update if different. Update in all three sbatch files.
