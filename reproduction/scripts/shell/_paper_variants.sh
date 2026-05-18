# Paper-variant override helper, sourced by 02/03/04_run_*.sh and 05_score.sh.
#
# The upstream em-llm-model/config/<model>.yaml files all default to variant S
# (surprise threshold only, no refinement, no contiguity buffer). But the EM-LLM
# paper (Fountas et al., ICLR 2025) reports different variants per base model
# in its main tables, so a faithful reproduction needs to override the right
# knobs per run.
#
# Variant flag legend (paper terminology):
#   S    surprise threshold only
#   SM   surprise + similarity refinement (modularity)
#   S+C  surprise + contiguity buffer
#   SM+C surprise + refinement + contiguity buffer
#
# Per-model paper Table 2 variant (the default we apply when VARIANT is unset):
#   mistral     -> sm_c  (Table 2 row: EM-LLM_SM+C, 4K+2K)
#   llama3      -> s     (Table 2 row: EM-LLM_S,    4K+4K, gamma=2)
#   llama31     -> sm    (Table 2 row: EM-LLM_SM,   4K+4K)
#   phi3_mini   -> s     (Table 2 row: EM-LLM_S,    1K+3K)
#   phi35_mini  -> s     (Table 2 row: EM-LLM_S,    1K+3K)
#
# Paper Table 1 (LLaMA-3.1-8B only) reports EM-LLM_S separately. To reproduce
# that row, submit llama31 with VARIANT=s explicitly.
#
# Usage:
#   source reproduction/scripts/shell/_paper_variants.sh
#   resolve_paper_variant "$MODEL" "${VARIANT:-}"     # sets VARIANT, VARIANT_OVERRIDES, MODEL_GAMMA_OVERRIDE

# Print the default paper variant tag for a given model name.
# Input:  model name (mistral|llama3|llama31|phi3_mini|phi35_mini)
# Output: variant tag on stdout (s|sm|s_c|sm_c)
default_paper_variant() {
    case "$1" in
        mistral)              echo "sm_c" ;;
        llama3)               echo "s" ;;
        llama31)              echo "sm" ;;
        phi3_mini|phi35_mini) echo "s" ;;
        *) echo "" ;;
    esac
}

# Print the OmegaConf override string for a variant tag.
# Input:  variant tag (s|sm|s_c|sm_c)
# Output: space-separated OmegaConf "key=value" pairs on stdout
variant_overrides() {
    case "$1" in
        s)
            echo "model.similarity_refinement_kwargs.similarity_refinement=false model.contiguity_buffer_kwargs.use_contiguity_buffer=false"
            ;;
        sm)
            echo "model.similarity_refinement_kwargs.similarity_refinement=true model.contiguity_buffer_kwargs.use_contiguity_buffer=false"
            ;;
        s_c)
            echo "model.similarity_refinement_kwargs.similarity_refinement=false model.contiguity_buffer_kwargs.use_contiguity_buffer=true"
            ;;
        sm_c)
            echo "model.similarity_refinement_kwargs.similarity_refinement=true model.contiguity_buffer_kwargs.use_contiguity_buffer=true"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Print the model-specific surprisal_threshold_gamma override if it differs
# from upstream's default of 1.0. From paper Appendix (gamma per base model):
# gamma = 1, 2, 1, 1, 1 for Mistral, LLaMa-3, LLaMa-3.1, Phi-3, Phi-3.5.
# Input:  model name
# Output: OmegaConf "key=value" string or empty
model_gamma_override() {
    case "$1" in
        llama3) echo "model.surprisal_threshold_gamma=2" ;;
        *)      echo "" ;;
    esac
}

# Resolve the full set of paper-faithful overrides for (model, variant) and
# export them via VARIANT, VARIANT_OVERRIDES, MODEL_GAMMA_OVERRIDE.
# Input:
#   $1 = MODEL (required)
#   $2 = VARIANT (optional; defaults to paper Table 2 variant for the model)
# Output (exported env vars):
#   VARIANT              the resolved variant tag (e.g. "sm_c")
#   VARIANT_OVERRIDES    OmegaConf string for refinement/contiguity flags
#   MODEL_GAMMA_OVERRIDE OmegaConf string for surprisal gamma if non-default
resolve_paper_variant() {
    local model="$1"
    local variant="${2:-}"

    if [[ -z "$variant" ]]; then
        variant="$(default_paper_variant "$model")"
        if [[ -z "$variant" ]]; then
            echo "[paper-variant] WARNING: unknown model '$model'; no variant overrides will be applied" >&2
            export VARIANT="custom"
            export VARIANT_OVERRIDES=""
            export MODEL_GAMMA_OVERRIDE=""
            return 0
        fi
    fi

    export VARIANT="$variant"
    export VARIANT_OVERRIDES="$(variant_overrides "$variant")"
    export MODEL_GAMMA_OVERRIDE="$(model_gamma_override "$model")"
    echo "[paper-variant] model=$model variant=$variant"
    [[ -n "$MODEL_GAMMA_OVERRIDE" ]] && echo "[paper-variant] extra: $MODEL_GAMMA_OVERRIDE"
}
