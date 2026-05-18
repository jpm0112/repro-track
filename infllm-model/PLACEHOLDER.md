# `infllm-model/` placeholder

This directory will hold a vendored copy of the **InfLLM** repository
([thunlp/InfLLM](https://github.com/thunlp/InfLLM)), the baseline EM-LLM is
compared against in the paper's Table 2 (Fountas et al., ICLR 2025).

The directory is intentionally empty in this initial scaffold. To populate it
on a login node (ASAX or local WSL), follow `docs/infllm_setup.md`:

```bash
rm -rf infllm-model
git clone https://github.com/thunlp/InfLLM infllm-model
# then pin the SHA into docs/infllm_commit.md
```

The reproduction wrappers (`reproduction/scripts/shell/06_run_infllm_longbench.sh`,
`07_run_infllm_infinitebench.sh`) expect this directory to contain a
working InfLLM checkout once populated. They will error out clearly if it
remains empty.

This placeholder file is gitignored once you run the clone above; it only
exists so `git clone` of the parent repository can show the directory
without an inscrutable empty-folder state.
