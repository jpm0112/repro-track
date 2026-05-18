# InfLLM context-budget helper, sourced by 06_run_infllm_longbench.sh
# and 07_run_infllm_infinitebench.sh.
#
# Each base model has exactly one paper-faithful InfLLM budget (n_local + n_mem),
# taken from Table 2's footer in the EM-LLM paper:
#   Mistral-7B-v2  -> 4096 + 2048   (4k+2k)
#   Llama-3-8B     -> 4096 + 4096   (4k+4k)
#   Llama-3.1-8B   -> 4096 + 4096   (4k+4k)
#   Phi-3-mini     -> 1024 + 3072   (1k+3k)
#   Phi-3.5-mini   -> 1024 + 3072   (1k+3k)
#
# Usage:
#   source reproduction/scripts/shell/_infllm_budgets.sh
#   resolve_infllm_budget "$MODEL"
# Side-effects: sets BUDGET_TAG, BUDGET_OVERRIDES.

# Print "<n_local>_<n_mem>" tag for a model, in 'k' units rounded to whole.
# Input:  model name (mistral|llama3|llama31|phi3_mini|phi35_mini)
# Output: budget tag on stdout (e.g., "4k_2k", "1k_3k")
infllm_budget_tag() {
    case "$1" in
        mistral)              echo "4k_2k" ;;
        llama3|llama31)       echo "4k_4k" ;;
        phi3_mini|phi35_mini) echo "1k_3k" ;;
        *)                    echo "" ;;
    esac
}

# Print OmegaConf overrides that force the paper-faithful (n_local, n_mem) for
# the given model. Independent of whatever defaults InfLLM's stock config has.
# Input:  model name
# Output: OmegaConf "key=value" string(s) on stdout
infllm_budget_overrides() {
    case "$1" in
        mistral)              echo "model.n_local=4096 model.n_mem=2048" ;;
        llama3|llama31)       echo "model.n_local=4096 model.n_mem=4096" ;;
        phi3_mini|phi35_mini) echo "model.n_local=1024 model.n_mem=3072" ;;
        *)                    echo "" ;;
    esac
}

# Resolve budget tag + overrides for a model and export them.
# Input:  $1 = MODEL (required)
# Output (exported env vars):
#   BUDGET_TAG          string like "4k_2k", used as suffix in OUT_DIR
#   BUDGET_OVERRIDES    OmegaConf string for n_local / n_mem
resolve_infllm_budget() {
    local model="$1"
    local tag
    tag="$(infllm_budget_tag "$model")"
    if [[ -z "$tag" ]]; then
        echo "[infllm-budget] ERROR: unknown model '$model'" >&2
        return 1
    fi
    export BUDGET_TAG="$tag"
    export BUDGET_OVERRIDES="$(infllm_budget_overrides "$model")"
    echo "[infllm-budget] model=$model budget=$tag"
    echo "[infllm-budget] overrides: $BUDGET_OVERRIDES"
}
