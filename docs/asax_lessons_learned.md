# ASAX lessons learned

Things that bit during EM-LLM bring-up on ASA's *asax* cluster. Captured here
so the next person (or future-you) doesn't re-discover them. Pair with
`docs/asax_setup.md` for the happy-path setup steps.

The fixes are all in `reproduction/scripts/asax/_asax_job_setup.sh`; this
doc is the *why* for what that file does.

## Quick reference

| Symptom | Root cause | Fix location |
|---|---|---|
| Job exits in 0 seconds; PBS `.o` file ends after `nvidia-smi` | Wrapper script crashed before its own logging took over | `_asax_job_setup.sh` step 1 (early `exec >` to `$HOME` log) |
| `source: reproduction/scripts/env/asax.env: No such file or directory` | `run_gpu` copies the .sh to `/scratch-local/...` and runs from there; relative paths break | `_asax_job_setup.sh` step 3 (REPO_ROOT via `PBS_O_WORKDIR`) |
| Job runs the full 15-task default instead of `DATASETS=trec` you set | PBS does not inherit submit-shell env vars | `_asax_job_setup.sh` step 5 (`.job_config` sourcing) |
| `GLIBCXX_3.4.29' not found` on `import transformers` | `cuda/11.8.0` module forces gcc to 9.5; its libstdc++ is too old for Pillow | `_asax_job_setup.sh` step 6 (`LD_LIBRARY_PATH` prepend) |
| `ModuleNotFoundError: No module named 'transformers'` despite `(emllm)` prompt | `conda activate` does not reliably prepend env's `bin/` to PATH after module load | `_asax_job_setup.sh` step 6 (`PATH` prepend) |
| `ValueError: ... but got mistralai/Mistral-7B-Instruct-v0.2` from `load_checkpoint_and_dispatch` | PBS `gpu` queue does not isolate GPU visibility; torch sees both GPUs on the shared node and `pred.py` flips to its multi-GPU branch which can't resolve HF repo IDs | `_asax_job_setup.sh` step 7 (`CUDA_VISIBLE_DEVICES=0`) |
| Sourcing `asax.env` silently aborts with `set -e` | ASA's `/apps/profiles/modules_asax.sh.dyn` uses test commands that legitimately return non-zero | Wrapper uses `set -o pipefail` only, never `set -e` |
| `[[ -n $X ]] && echo ...` at end of a function makes the caller think the function failed | The test's exit code becomes the function's return value; under caller's `set -e` the whole script aborts | `reproduction/scripts/shell/_paper_variants.sh` uses `if/then` + explicit `return 0` |

## Details

### `run_gpu` runs from a per-node scratch dir, not your submit dir

ASA's `run_gpu` wrapper:
1. Copies your submitted `.sh` to `/scratch-local/<user>.<jobname>.<jobid>/`
   on the assigned compute node.
2. Runs `nvidia-smi` for diagnostics (this is what ends up in the PBS `.o`
   file).
3. Execs your script from that scratch dir.

So `BASH_SOURCE[0]` is the *copy* in `/scratch-local`, and any path
resolution like `dirname "${BASH_SOURCE[0]}"/../../..` walks up out of
scratch into `/`. Anything that depends on the script being inside the
repo (sibling files, sourced helpers) breaks.

The fix is to use `PBS_O_WORKDIR`, which PBS sets to the directory `qsub`
was invoked from (= your repo root, since you submitted from there).
Fall back to `$REPRO_ROOT` (works for direct `bash` testing) or
`$HOME/repro-track`.

### PBS does not inherit submit-shell env vars

```bash
MODEL=mistral DATASETS=trec run_gpu reproduction/scripts/asax/longbench.sh
```

This `MODEL=...` only exports into the `run_gpu` process. `run_gpu` calls
`qsub` without `-V` (forward all env) or `-v VAR=val`, so the compute-node
shell starts fresh and `MODEL`/`DATASETS` are unset, defaulting to
`mistral`/`<all 15 LongBench tasks>`. Your "smoke test" silently becomes
a full 14-hour run.

Workaround used in this repo: write per-job overrides to
`~/repro-track/.job_config` before submitting. The wrapper sources that
file inside the compute-node shell.

```bash
cat > ~/repro-track/.job_config <<EOF
export MODEL=mistral
export DATASETS=trec
EOF
run_gpu reproduction/scripts/asax/longbench.sh
```

### `cuda/11.8.0` forces gcc to 9.5; libstdc++ is too old for Pillow

When you `module load cuda/11.8.0`, Lmod reloads:
```
gcc/11.3.0-o2cd4vz => gcc/9.5.0_all
```

The gcc 9.5 `libstdc++.so.6` does not export `GLIBCXX_3.4.29` (introduced
in gcc 11). Pillow's bundled `libLerc.so.4` (a transitive dependency of
transformers via PIL) was compiled against newer libstdc++ and refuses to
load:

```
RuntimeError: Failed to import transformers.models.bart.configuration_bart ...
  /apps/x86-64/apps/gcc_9.5.0_all/lib64/libstdc++.so.6:
    version `GLIBCXX_3.4.29' not found
    (required by /home/.../site-packages/PIL/../../.././libLerc.so.4)
```

Fix: prepend the conda env's `lib/` to `LD_LIBRARY_PATH` after activate.
The conda toolchain ships a newer `libstdc++` that does have the symbol.

```bash
export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:$LD_LIBRARY_PATH"
```

### `conda activate` does not reliably prepend PATH under the anaconda module

After `module load anaconda/3-2025.12`, `/apps/x86-64/apps/anaconda_3-2025.12/bin`
is prepended to PATH. When you then `conda activate emllm`, conda sets
`CONDA_PREFIX` and `CONDA_DEFAULT_ENV` correctly, but does NOT prepend
`$CONDA_PREFIX/bin` ahead of the module's anaconda bin. So `which python`
still resolves to the module's python (base env) even though your prompt
shows `(emllm)`.

That base-env python doesn't have your installed packages, so imports
fail with `ModuleNotFoundError` for things you definitely installed.

Fix: explicitly prepend after `conda activate`:
```bash
source activate emllm    # or `conda activate emllm`
export PATH="$CONDA_PREFIX/bin:$PATH"
```

### PBS `gpu` queue does not isolate GPU visibility

Even when you request `ngpus=1`:
```
qsub -q gpu ... -l select=1:ngpus=1:ncpus=8:mpiprocs=8:mem=32000mb
```

your job lands on a shared node and **all** of that node's GPUs are
visible. `nvidia-smi` from inside the job shows multiple GPUs (often
with other users' processes already using GPU memory).

This breaks upstream EM-LLM's `pred.py` because it auto-flips a config
flag based on `torch.cuda.device_count()`:
```python
if torch.cuda.device_count() > 1:
    conf.model.use_hf_acc = True   # split layers across GPUs
```

The `use_hf_acc=True` path uses `accelerate.load_checkpoint_and_dispatch`,
which requires a local checkpoint path. But `model.path` is the HF repo
ID (e.g. `mistralai/Mistral-7B-Instruct-v0.2`), and accelerate doesn't
auto-resolve repo IDs to local cache paths. The job crashes with:

```
ValueError: `checkpoint` should be the path to a file containing a whole
state dict ... but got mistralai/Mistral-7B-Instruct-v0.2.
```

Fix: cap visibility to one device so torch sees a single-GPU world.
```bash
export CUDA_VISIBLE_DEVICES=0
```

For multi-GPU jobs that legitimately need layer split (e.g. PassKey-10M on
4 GPUs), override on the submit side:
```bash
export CUDA_VISIBLE_DEVICES=0,1,2,3
```

### `set -e` plus sourced system profiles is a footgun

ASA's `/apps/profiles/modules_asax.sh.dyn` uses constructs like:
```bash
dmcnode=$(echo $hostname | grep -c '^dmc')   # grep returns 1 when no match
```

Under `set -e` in the caller, `grep` returning 1 (no match) propagates
as a failure of the assignment, and the source aborts mid-way. The
caller exits silently with no error message — the most painful kind of
failure on a remote compute node where you have no interactive shell.

Use `set -o pipefail` only (catches pipe failures), never `set -e`, in
wrappers that source system profiles. Rely on explicit exit-code checks
for the parts you control.

### Bash function endings with `[[ ... ]] && cmd`

```bash
my_function() {
    do_some_stuff
    [[ -n "$OPTIONAL_VAR" ]] && echo "got: $OPTIONAL_VAR"
}
```

If `OPTIONAL_VAR` is empty, the test returns 1, the `&&` short-circuits,
and **the function's return value is 1**. If the caller has `set -e`,
the whole script aborts.

The first symptom of this we saw: `02_run_longbench.sh` exiting 1
immediately after `[paper-variant] model=mistral variant=sm_c` with no
other output, because `_paper_variants.sh`'s `resolve_paper_variant`
ended on a `[[ -n $MODEL_GAMMA_OVERRIDE ]] && echo ...` line and
`MODEL_GAMMA_OVERRIDE` was empty for Mistral.

Fix: use explicit if/then and `return 0`:
```bash
my_function() {
    do_some_stuff
    if [[ -n "$OPTIONAL_VAR" ]]; then
        echo "got: $OPTIONAL_VAR"
    fi
    return 0
}
```

### `.o<jobid>` PBS file sometimes doesn't capture user-script output

We saw cases where the PBS `mistral-test.o46909` file ended right after
the run_gpu preamble (nvidia-smi output) with no trace of our wrapper
script's output, even though the wrapper definitely ran. The mechanism
isn't fully clear, but it's not reliable.

Workaround: at the very top of every ASAX wrapper, redirect everything
to a known log file in `$HOME` before anything else can fail:

```bash
mkdir -p "$HOME/repro-track/reproduction/results/asax/logs"
exec > "$HOME/repro-track/reproduction/results/asax/logs/${BENCH_TAG}-$(date +%Y%m%d-%H%M%S)-${PBS_JOBID:-local}.log" 2>&1
set -x   # trace each command so we can see exactly where it dies
```

Now even a silent crash leaves a complete trace in a file you can read
from the login node.

## Storage layout

`/home/<user>` — 100 GB hard quota, 90 GB soft. NFS-shared across nodes.
This is your persistent storage. Code, conda env, HF model weights, and
benchmark datasets all live here.

`/scratch-local` — per-compute-node, ephemeral. Wiped between jobs. Good
for transient artifacts (e.g. EM-LLM's PassKey offload, which can hit
hundreds of GB temporarily). `asax.env` points `EMLLM_OFFLOAD_DIR` here.

There is no `/scratch/<user>` directory on asax accounts by default,
despite `/scratch/` existing at the root. Don't put paths there.

## Module versions (verified working as of 2026-05)

```bash
source /apps/profiles/modules_asax.sh.dyn
module load anaconda/3-2025.12
module load cuda/11.8.0
```

If these names change after a maintenance window:
```bash
module avail anaconda cuda gcc
```
then update `reproduction/scripts/env/asax.env`.

## Submission cheatsheet

Per-job resource answers for the `run_gpu` prompts:

| Job | queue | cores | walltime | memory | GPUs |
|-----|-------|------:|---------:|-------:|-----:|
| LongBench smoke (1 task) | gpu | 8 | 02:00:00 | 32gb | 1 |
| LongBench full (15 tasks) | gpu | 8 | 14:00:00 | 128gb | 1 |
| Infinity-Bench full | gpu | 8 | 26:00:00 | 200gb | 1 |
| Passkey 1M | gpu | 8 | 26:00:00 | 64gb | 1 |
| Passkey 10M | gpu | 16 | 48:00:00 | 512gb | 4 |
| InfLLM LongBench | gpu | 8 | 14:00:00 | 128gb | 1 |
| InfLLM ∞-Bench | gpu | 8 | 26:00:00 | 200gb | 1 |

Pair with `.job_config` for per-row overrides — see
`docs/paper_reproduction_runbook.md` for the full submission matrix.
