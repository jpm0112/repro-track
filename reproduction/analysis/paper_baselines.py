"""Paper baseline scores from Fountas et al. (ICLR 2025), Tables 1 and 2.

All scores are on a 0 to 100 scale, matching upstream em-llm-model/benchmark/
eval.py output. Source of truth: em-llm-model/benchmark/further_results.md,
which is the paper's Tables 1 and 2 expanded.

Schema
------
LONGBENCH_TASK_DISPLAY / INFBENCH_TASK_DISPLAY
    Map internal task names (as found in result.json keys) to the display
    names the paper uses (NarrativeQA, Retrieve.KV, ...).

LONGBENCH_GROUPS
    Paper's LongBench grouping for Table 2: SQA (single-doc QA), MQA
    (multi-doc QA), Sum, FSL, Ret, Cod. Each group maps to its tasks.

PAPER_DEFAULT_VARIANT
    Per-model paper Table 2 variant. Used by make_summary.py to decide which
    baseline dict to read when the variant isn't encoded in the result path.

LONGBENCH_TABLE1_LLAMA31 / INFBENCH_TABLE1_LLAMA31
    Per-task numbers from paper Table 1. Only Llama-3.1-8B is reported,
    EM-LLM_S variant (4K local + 4K retrieved). Compared against RAG
    (NV-Embed-v2 retriever) and Full-Context.

LONGBENCH_TABLE2_GROUPED[model][variant]
    Per-model-and-variant grouped LongBench scores from Table 2. Variant tag
    is one of "s", "sm", "s_c", "sm_c"; only the variant the paper actually
    reports for each model is populated.

INFBENCH_TABLE2_PER_TASK[model][variant]
    Same shape but per-task ∞-Bench scores from Table 2. Only 7-8B models
    (mistral, llama3, llama31) are reported by the paper for ∞-Bench.

PASSKEY_HEADLINE
    Figure 2 (right) anchor: EM-LLM_S on Mistral reaches 100% at 10M tokens.
"""

# Internal task name to paper display name (LongBench).
LONGBENCH_TASK_DISPLAY = {
    "narrativeqa":          "NarrativeQA",
    "qasper":               "Qasper",
    "multifieldqa_en":      "MultiFieldQA",
    "hotpotqa":             "HotpotQA",
    "2wikimqa":             "2WikiMQA",
    "musique":              "Musique",
    "gov_report":           "GovReport",
    "qmsum":                "QMSum",
    "multi_news":           "MultiNews",
    "trec":                 "TREC",
    "triviaqa":             "TriviaQA",
    "samsum":               "SAMSum",
    "passage_retrieval_en": "PassageRetrieval",
    "lcc":                  "LCC",
    "repobench-p":          "RepoBench-P",
}

INFBENCH_TASK_DISPLAY = {
    "code_debug":          "Code.Debug",
    "math_find":           "Math.Find",
    "kv_retrieval":        "Retrieve.KV",
    "longbook_choice_eng": "En.MC",
    "passkey":             "Retrieve.PassKey",
    "number_string":       "Retrieve.Number",
}

LONGBENCH_GROUPS = {
    "SQA": ["narrativeqa", "qasper", "multifieldqa_en"],
    "MQA": ["hotpotqa", "2wikimqa", "musique"],
    "Sum": ["gov_report", "qmsum", "multi_news"],
    "FSL": ["trec", "triviaqa", "samsum"],
    "Ret": ["passage_retrieval_en"],
    "Cod": ["lcc", "repobench-p"],
}

# Default paper variant per base model (Table 2). Used as fallback when the
# results dir does not carry a variant suffix in its name.
PAPER_DEFAULT_VARIANT = {
    "mistral":    "sm_c",
    "llama3":     "s",
    "llama31":    "sm",
    "phi3_mini":  "s",
    "phi35_mini": "s",
}

# Each base model has exactly one paper-faithful InfLLM context budget
# (Table 2 footer). The InfLLM column lives in the same Table 2 row as the
# EM-LLM column for the model, so to read paper InfLLM numbers from
# LONGBENCH_TABLE2_GROUPED / INFBENCH_TABLE2_PER_TASK we use the same outer
# variant key as PAPER_DEFAULT_VARIANT. This helper makes that explicit.
INFLLM_BUDGET_TAG = {
    "mistral":    "4k_2k",
    "llama3":     "4k_4k",
    "llama31":    "4k_4k",
    "phi3_mini":  "1k_3k",
    "phi35_mini": "1k_3k",
}


def paper_infllm_variant_key(model):
    """Return the outer-dict variant key under which the paper's InfLLM
    column for `model` lives in LONGBENCH_TABLE2_GROUPED /
    INFBENCH_TABLE2_PER_TASK.

    The paper reports InfLLM in the same Table 2 row as the EM-LLM variant
    the paper highlights for that model, so this just returns the default
    EM-LLM variant key.
    """
    return PAPER_DEFAULT_VARIANT.get(model, "")

# Known model names ordered by length (longest first) so a "<model>_<variant>"
# directory like "phi3_mini_s" parses correctly without splitting on the wrong
# underscore. make_summary.py uses this.
MODEL_NAMES = ["phi35_mini", "phi3_mini", "llama31", "llama3", "mistral"]


# ---------------------------------------------------------------------------
# Paper Table 1: per-task numbers, LLaMA-3.1-8B only, EM-LLM_S (4K+4K).
# ---------------------------------------------------------------------------
LONGBENCH_TABLE1_LLAMA31 = {
    "narrativeqa":          {"em_llm": 26.05, "rag": 22.54, "full_context": 29.14},
    "qasper":               {"em_llm": 44.41, "rag": 45.45, "full_context": 45.34},
    "multifieldqa_en":      {"em_llm": 52.52, "rag": 51.67, "full_context": 54.98},
    "hotpotqa":             {"em_llm": 54.02, "rag": 55.93, "full_context": 54.01},
    "2wikimqa":             {"em_llm": 45.72, "rag": 42.93, "full_context": 45.95},
    "musique":              {"em_llm": 25.37, "rag": 30.90, "full_context": 33.52},
    "gov_report":           {"em_llm": 35.04, "rag": 29.91, "full_context": 34.49},
    "qmsum":                {"em_llm": 24.31, "rag": 24.97, "full_context": 25.14},
    "multi_news":           {"em_llm": 27.76, "rag": 26.77, "full_context": 27.00},
    "trec":                 {"em_llm": 71.50, "rag": 22.50, "full_context": 4.50},
    "triviaqa":             {"em_llm": 92.34, "rag": 88.11, "full_context": 89.07},
    "samsum":               {"em_llm": 43.31, "rag": 7.56,  "full_context": 8.68},
    "passage_retrieval_en": {"em_llm": 99.50, "rag": 65.50, "full_context": 100.00},
    "lcc":                  {"em_llm": 67.45, "rag": 13.16, "full_context": 19.30},
    "repobench-p":          {"em_llm": 64.33, "rag": 18.66, "full_context": 18.33},
}

INFBENCH_TABLE1_LLAMA31 = {
    "code_debug":          {"em_llm":  22.59, "rag":  22.59, "full_context":  21.70},
    "math_find":           {"em_llm":  36.00, "rag":  35.43, "full_context":  26.29},
    "kv_retrieval":        {"em_llm":  96.80, "rag":  31.80, "full_context":  92.60},
    "longbook_choice_eng": {"em_llm":  44.54, "rag":  64.19, "full_context":  58.07},
    "passkey":             {"em_llm": 100.00, "rag": 100.00, "full_context": 100.00},
    "number_string":       {"em_llm": 100.00, "rag":  99.83, "full_context":  99.32},
}

# Paper Table 1 overall averages (last row of each section).
LONGBENCH_TABLE1_LLAMA31_AVG = {"em_llm": 51.58, "rag": 36.44, "full_context": 39.30}
INFBENCH_TABLE1_LLAMA31_AVG  = {"em_llm": 66.66, "rag": 58.97, "full_context": 66.33}


# ---------------------------------------------------------------------------
# Paper Table 2: grouped LongBench + per-task ∞-Bench, per (model, variant).
# Only the variant the paper actually reports for each model is populated.
# ---------------------------------------------------------------------------
LONGBENCH_TABLE2_GROUPED = {
    "mistral": {
        "sm_c": {
            "variant_infllm": "4k+2k",
            "SQA": {"em_llm": 32.9, "infllm": 33.0},
            "MQA": {"em_llm": 27.0, "infllm": 25.5},
            "Sum": {"em_llm": 27.2, "infllm": 27.1},
            "FSL": {"em_llm": 66.8, "infllm": 66.1},
            "Ret": {"em_llm": 84.1, "infllm": 64.0},
            "Cod": {"em_llm": 54.8, "infllm": 54.8},
            "Avg": {"em_llm": 43.7, "infllm": 41.9},
        },
    },
    "llama3": {
        "s": {
            "variant_infllm": "4k+4k",
            "SQA": {"em_llm": 39.3, "infllm": 38.5},
            "MQA": {"em_llm": 37.7, "infllm": 36.9},
            "Sum": {"em_llm": 27.0, "infllm": 27.0},
            "FSL": {"em_llm": 69.2, "infllm": 69.0},
            "Ret": {"em_llm": 87.5, "infllm": 84.0},
            "Cod": {"em_llm": 50.3, "infllm": 53.2},
            "Avg": {"em_llm": 47.2, "infllm": 47.0},
        },
    },
    "llama31": {
        "sm": {
            "variant_infllm": "4k+4k",
            "SQA": {"em_llm": 41.2, "infllm": 41.4},
            "MQA": {"em_llm": 41.3, "infllm": 40.7},
            "Sum": {"em_llm": 29.2, "infllm": 29.0},
            "FSL": {"em_llm": 69.1, "infllm": 69.0},
            "Ret": {"em_llm": 98.5, "infllm": 97.0},
            "Cod": {"em_llm": 64.1, "infllm": 64.2},
            "Avg": {"em_llm": 51.3, "infllm": 51.1},
        },
        # No Table 2 row for llama31 variant 's' — Table 1 covers that case
        # via LONGBENCH_TABLE1_LLAMA31 (per-task with Full-Context baseline).
    },
    "phi3_mini": {
        "s": {
            "variant_infllm": "1k+3k",
            "SQA": {"em_llm": 29.2, "infllm": 28.4},
            "MQA": {"em_llm": 27.1, "infllm": 24.9},
            "Sum": {"em_llm": 25.9, "infllm": 25.6},
            "FSL": {"em_llm": 53.5, "infllm": 52.9},
            "Ret": {"em_llm": 10.0, "infllm":  7.5},
            "Cod": {"em_llm": 57.0, "infllm": 57.0},
            "Avg": {"em_llm": 35.4, "infllm": 34.5},
        },
    },
    "phi35_mini": {
        "s": {
            "variant_infllm": "1k+3k",
            "SQA": {"em_llm": 31.8, "infllm": 31.7},
            "MQA": {"em_llm": 31.9, "infllm": 28.5},
            "Sum": {"em_llm": 24.5, "infllm": 23.9},
            "FSL": {"em_llm": 55.5, "infllm": 56.3},
            "Ret": {"em_llm": 13.0, "infllm": 11.5},
            "Cod": {"em_llm": 39.5, "infllm": 40.3},
            "Avg": {"em_llm": 34.9, "infllm": 34.2},
        },
    },
}

INFBENCH_TABLE2_PER_TASK = {
    "mistral": {
        "sm_c": {
            "variant_infllm": "4k+2k",
            "code_debug":          {"em_llm":  28.2, "infllm":  29.4},
            "math_find":           {"em_llm":  27.1, "infllm":  26.6},
            "longbook_choice_eng": {"em_llm":  42.8, "infllm":  43.2},
            "kv_retrieval":        {"em_llm":  99.0, "infllm":  95.6},
            "passkey":             {"em_llm": 100.0, "infllm": 100.0},
            "number_string":       {"em_llm":  99.8, "infllm":  99.8},
        },
    },
    "llama3": {
        "s": {
            "variant_infllm": "4k+4k",
            "code_debug":          {"em_llm":  31.7, "infllm":  30.5},
            "math_find":           {"em_llm":  16.9, "infllm":  23.7},
            "longbook_choice_eng": {"em_llm":  40.6, "infllm":  43.7},
            "kv_retrieval":        {"em_llm":   4.2, "infllm":   5.0},
            "passkey":             {"em_llm": 100.0, "infllm": 100.0},
            "number_string":       {"em_llm":  99.6, "infllm":  99.0},
        },
    },
    "llama31": {
        "sm": {
            "variant_infllm": "4k+4k",
            "code_debug":          {"em_llm":  22.6, "infllm":  22.6},
            "math_find":           {"em_llm":  34.0, "infllm":  33.7},
            "longbook_choice_eng": {"em_llm":  47.6, "infllm":  46.7},
            "kv_retrieval":        {"em_llm":  90.2, "infllm":  81.0},
            "passkey":             {"em_llm": 100.0, "infllm": 100.0},
            "number_string":       {"em_llm": 100.0, "infllm": 100.0},
        },
        # 's' variant for llama31 ∞-Bench → use Table 1 (LONGBENCH_/INFBENCH_TABLE1_LLAMA31).
    },
    # Phi-3 / Phi-3.5: paper does not report ∞-Bench numbers.
}

# Figure 2 (right) anchor: extended passkey at 10M tokens, EM-LLM_S on Mistral.
PASSKEY_HEADLINE = {
    "mistral":    {"em_llm_at_10m": 100.0},
    "llama3":     {"em_llm_at_10m": None},
    "llama31":    {"em_llm_at_10m": None},
    "phi3_mini":  {"em_llm_at_10m": None},
    "phi35_mini": {"em_llm_at_10m": None},
}


def split_model_variant(dir_name):
    """Split a results dir name like 'mistral_sm_c' into ('mistral', 'sm_c').

    Falls back to (dir_name, '') if no known model name prefix matches.
    Tries longest model names first so 'phi3_mini_s' parses as
    ('phi3_mini', 's'), not ('phi3', 'mini_s').

    Input:  dir_name (str)
    Output: (model_name, variant_tag) tuple
    """
    for name in MODEL_NAMES:
        if dir_name == name:
            return (name, "")
        if dir_name.startswith(name + "_"):
            return (name, dir_name[len(name) + 1:])
    return (dir_name, "")
