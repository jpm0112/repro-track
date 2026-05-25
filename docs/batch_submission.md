# Batch submission for unattended runs

When you can't sit at the terminal answering `run_gpu`'s prompts (e.g.,
traveling), use the **batch wrappers** + `submit_batch.sh`. They bake the
paper-row settings (MODEL, VARIANT, DATASETS, EXTENDED_PASSKEY_K, multi-GPU
visibility) into per-row scripts and submit each via direct `qsub`, which
takes resource flags as CLI args instead of prompting.

## One-time prep

The batch wrappers source `reproduction/scripts/asax/_asax_job_setup.sh`
which expects the conda env, weights, and benchmark data already in place
(per `docs/asax_setup.md`). For each model you plan to run, pre-download
the weights on the login node first:

```bash
# Replace MODELS for whichever you need this cycle
MODELS="mistralai/Mistral-7B-Instruct-v0.2" \
    bash reproduction/scripts/shell/00b_login_node_prep.sh
```

Quota math: each 7-8B model is ~14-16 GB cached. Your home is capped at
100 GB hard. Keep only the models for the rows you're about to submit.

## Submit the batch

```bash
cd ~/repro-track
chmod +x reproduction/scripts/asax/batch/*.sh

# Mistral coverage you can fire-and-forget right now:
bash reproduction/scripts/asax/batch/submit_batch.sh \
    em_llm_longbench_mistral \
    em_llm_infinitebench_mistral \
    em_llm_passkey_1m_mistral
```

This `qsub`s 3 jobs and returns immediately. PBS queues them and runs as
GPU slots free up.

Confirm what got queued:
```bash
qstat -u $USER
```

To see what would be submitted without actually doing it:
```bash
bash reproduction/scripts/asax/batch/submit_batch.sh --dry-run em_llm_longbench_mistral
```

## Available wrappers (one per paper row)

| Wrapper name | Paper row | Walltime | Memory | GPUs |
|---|---|---:|---:|---:|
| `em_llm_longbench_mistral` | 1 | 26h | 120gb | 1 |
| `em_llm_longbench_llama3` | 2 | 26h | 120gb | 1 |
| `em_llm_longbench_llama31_sm` | 3 (Table 2) | 26h | 120gb | 1 |
| `em_llm_longbench_llama31_s` | 4 (Table 1) | 26h | 120gb | 1 |
| `em_llm_longbench_phi3_mini` | 5 | 26h | 120gb | 1 |
| `em_llm_longbench_phi35_mini` | 6 | 26h | 120gb | 1 |
| `em_llm_infinitebench_mistral` | 7 | 26h | 120gb | 1 |
| `em_llm_infinitebench_llama3` | 8 | 26h | 120gb | 1 |
| `em_llm_infinitebench_llama31_sm` | 9 (Table 2) | 26h | 120gb | 1 |
| `em_llm_infinitebench_llama31_s` | 10 (Table 1) | 26h | 120gb | 1 |
| `em_llm_passkey_1m_mistral` | 11 | 26h | 120gb | 1 |
| `em_llm_passkey_10m_mistral` | 12 (headline) | 48h | 512gb | 4 |

> Resources revised 2026-05-24. LongBench's original 14h hit the wall at
> 7/16 tasks → walltime bumped to 26h. Attempted bumping IB/pk1m memory
> from 120gb to 200gb to address suspected OOM, but qsub rejected
> ("violates queue and/or server resource limits") — the gpu queue caps
> memory at 120gb. To compensate for tight memory on long-context runs,
> pass `EXTRA_OVERRIDES="model.min_free_cpu_memory=20
> model.disk_offload_threshold=150000"` at submit time. See
> submit_batch.sh history comment for full details.

InfLLM-baseline wrappers (rows 13-20) will be added once `infllm-model/`
is populated. See `docs/infllm_setup.md`.

## Recommended sequence for ~48h unattended

**Hour 0** (pre-leave):
```bash
# Already have: Mistral weights, benchmarks downloaded
bash reproduction/scripts/asax/batch/submit_batch.sh \
    em_llm_longbench_mistral \
    em_llm_infinitebench_mistral \
    em_llm_passkey_1m_mistral
```

That's ~66 GPU-hours of work, runnable in parallel if ASA has slots. Wall
clock for all 3 to finish: ~26h (the longest is ∞-Bench Mistral at 26h).

**Skip `em_llm_passkey_10m_mistral` for unattended runs** — it asks for 4
GPUs and 48h, which is a tall scheduling order and risks not even starting
within the window. Submit it once you're back and can babysit.

**If you want more coverage** before leaving and Llama-3 weights fit in
quota (they will once Mistral runs start consuming disk for offload):
1. Pre-download Llama-3 (`MODELS=meta-llama/Meta-Llama-3-8B-Instruct ...`).
2. Submit row 2 + 8 (Llama-3 LongBench + ∞-Bench).
3. Quota will be tight; monitor with `du -sh ~/.cache/huggingface/hub`.

## Checking results while away

Log into a phone SSH client (Termux, Blink) or a laptop:
```bash
ssh aubjpm001@asaxlogin1
qstat -u $USER                                        # what's still running
ls -la ~/repro-track/reproduction/results/asax/*/    # what's finished
cat ~/repro-track/reproduction/results/asax/longbench/mistral_sm_c/summary.md
```

Each finished run will have a `result.json` and `summary.md` in
`reproduction/results/asax/<benchmark>/<model>_<variant>/`.

## If a job fails

PBS writes the captured stdout/stderr to `<jobname>.o<jobid>` in the
directory you submitted from (`~/repro-track/`). The wrapper also tees a
full trace to `~/repro-track/reproduction/results/asax/logs/<bench>-*.log`
which survives even when PBS's capture is partial.

Common failure modes (and where they're documented in case you hit a new
one):

- Job exits in 0 seconds with no useful log: PBS env-var inheritance
  problem. Should not happen with batch wrappers since they bake the
  vars in, but double-check the `cat` of the debug log.
- `GLIBCXX_3.4.29 not found`: handled by `_asax_job_setup.sh`'s
  LD_LIBRARY_PATH prepend.
- `ValueError: ... but got mistralai/...`: too many GPUs visible;
  handled by `_asax_job_setup.sh`'s `CUDA_VISIBLE_DEVICES=0` default
  (overridden to `0,1,2,3` only for the passkey 10M wrapper).
