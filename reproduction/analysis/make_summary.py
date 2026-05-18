"""Write a paper-mirroring side-by-side summary alongside upstream's result.json.

Reads result.json from a reproduction/results/<system>/<benchmark>/<model>_<variant>/
directory and emits two new files in the same directory:

  - summary.md   markdown table for human/manuscript consumption
  - summary.csv  same data for downstream analysis

Each row carries (paper EM-LLM number for the matching variant, paper
baseline number, our number, delta) so the user can put their reproduction
side-by-side with the paper table.

Usage:
  python reproduction/analysis/make_summary.py <results_dir>

The benchmark, model and EM-LLM variant are inferred from <results_dir>:
  .../longbench/mistral_sm_c          -> benchmark=longbench,    model=mistral, variant=sm_c
  .../infinitebench/llama31_sm        -> benchmark=infinitebench, model=llama31, variant=sm
  .../passkey_10240k/mistral_s        -> benchmark=passkey,       model=mistral, variant=s
  .../longbench/mistral               -> legacy layout; falls back to default paper variant

Paper numbers are sourced from paper_baselines.py (a sibling module).
"""

import argparse
import csv
import json
import sys
from pathlib import Path

import paper_baselines as pb


def detect_benchmark_and_method(results_dir):
    """Infer (benchmark, method) from the second-to-last path component.

    The method ('em_llm' or 'infllm') is encoded as a parent-dir suffix:
       .../longbench/<dir>          -> em_llm
       .../longbench_infllm/<dir>   -> infllm
       .../infinitebench_infllm/<dir> -> infllm
       .../passkey_<N>k/<dir>       -> em_llm (paper has no passkey InfLLM baseline)

    Returns a (benchmark, method) tuple where benchmark is one of
    {"longbench", "infinitebench", "passkey"} and method is one of
    {"em_llm", "infllm"}.
    """
    parent = results_dir.parent.name
    if parent.endswith("_infllm"):
        method = "infllm"
        base = parent[: -len("_infllm")]
    else:
        method = "em_llm"
        base = parent
    if base == "longbench":
        return "longbench", method
    if base == "infinitebench":
        return "infinitebench", method
    if base.startswith("passkey_"):
        return "passkey", method
    raise ValueError(
        f"Could not infer benchmark from path '{results_dir}'. Expected "
        f"the parent dir to be one of: longbench[_infllm], "
        f"infinitebench[_infllm], passkey_<N>k."
    )


def detect_model_and_variant(results_dir, method):
    """Infer (model, variant_or_budget) from the last path component.

    For EM-LLM runs the leaf encodes <model>_<variant>; empty variant
    backfills to the paper Table 2 default for the model.
    For InfLLM runs the leaf encodes <model>_<budget_tag>; the budget is
    treated as the variant slot for path-parsing only.
    """
    model, variant = pb.split_model_variant(results_dir.name)
    if not variant:
        if method == "em_llm":
            variant = pb.PAPER_DEFAULT_VARIANT.get(model, "")
        else:
            variant = pb.INFLLM_BUDGET_TAG.get(model, "")
    return model, variant


def load_our_scores(results_dir):
    """Parse result.json into a flat {task: score} dict on the 0-100 scale.

    LongBench-E uses dict scores per length bin; we collapse to mean.
    """
    path = results_dir / "result.json"
    if not path.exists():
        raise FileNotFoundError(f"result.json not found in {results_dir}")
    with path.open() as f:
        raw = json.load(f)

    flat = {}
    for task, payload in raw.items():
        score = payload.get("score") if isinstance(payload, dict) else payload
        if isinstance(score, dict):
            present = [v for v in score.values() if v is not None]
            score = sum(present) / len(present) if present else None
        flat[task.replace("__long", "")] = score
    return flat


def build_longbench_rows(our_scores, model, variant, method):
    """Build LongBench side-by-side rows.

    For method='em_llm':
      - Per-task rows (Table 1 vs Full-Context) only for llama31 + S
      - Grouped rows (Table 2 vs InfLLM) for the model's paper variant
      - Avg row uses Table 2 Avg, or Table 1 Avg as fallback for llama31+S

    For method='infllm':
      - The "Paper EM-LLM" column shows the paper's InfLLM number (so
        the user sees "our InfLLM vs paper InfLLM" on a single axis)
      - The "Paper baseline" column shows the paper's EM-LLM number for
        context, so the InfLLM-vs-EM-LLM gap our reproduction shows can
        be compared to the gap the paper shows.
    """
    rows = []

    if method == "infllm":
        # InfLLM lives in the same Table 2 row as the EM-LLM variant the paper
        # highlights for the model. Pull both columns from that row.
        var_key = pb.paper_infllm_variant_key(model)
        table2 = pb.LONGBENCH_TABLE2_GROUPED.get(model, {}).get(var_key, {})
        em_label = f"EM-LLM (paper, {var_key.upper()})"

        # No per-task InfLLM column in paper for LongBench; skip per-task rows.
        for group_name, task_list in pb.LONGBENCH_GROUPS.items():
            present = [our_scores[t] for t in task_list
                       if t in our_scores and our_scores[t] is not None]
            ours_avg = round(sum(present) / len(present), 2) if present else None
            paper_infllm = table2.get(group_name, {}).get("infllm")
            paper_em = table2.get(group_name, {}).get("em_llm")
            rows.append(_row(f"_group_{group_name}", f"[Group] {group_name}",
                             paper_infllm, paper_em, em_label, ours_avg))

        actual = [v for v in our_scores.values() if v is not None]
        avg_ours = round(sum(actual) / len(actual), 2) if actual else None
        n_total = len(pb.LONGBENCH_TASK_DISPLAY)
        label = f"**Average ({len(actual)}/{n_total} tasks)**"
        paper_infllm = table2.get("Avg", {}).get("infllm")
        paper_em = table2.get("Avg", {}).get("em_llm")
        rows.append(_row("_avg", label, paper_infllm, paper_em, em_label, avg_ours))
        return rows

    # method == "em_llm": original logic.
    show_per_task = (model == "llama31" and variant == "s")
    table1 = pb.LONGBENCH_TABLE1_LLAMA31 if show_per_task else {}

    for task, display in pb.LONGBENCH_TASK_DISPLAY.items():
        if task not in our_scores:
            continue
        ours = our_scores[task]
        paper_em = table1.get(task, {}).get("em_llm")
        paper_baseline = table1.get(task, {}).get("full_context")
        baseline_label = "Full-Context (paper)" if paper_baseline is not None else ""
        rows.append(_row(task, display, paper_em, paper_baseline,
                         baseline_label, ours))

    table2 = pb.LONGBENCH_TABLE2_GROUPED.get(model, {}).get(variant, {})
    variant_inf = table2.get("variant_infllm", "")
    inf_label = (f"InfLLM (paper, {variant_inf})" if variant_inf
                 else "InfLLM (paper)")

    for group_name, task_list in pb.LONGBENCH_GROUPS.items():
        present = [our_scores[t] for t in task_list
                   if t in our_scores and our_scores[t] is not None]
        ours_avg = round(sum(present) / len(present), 2) if present else None
        paper_em = table2.get(group_name, {}).get("em_llm")
        paper_baseline = table2.get(group_name, {}).get("infllm")
        rows.append(_row(f"_group_{group_name}", f"[Group] {group_name}",
                         paper_em, paper_baseline, inf_label, ours_avg))

    actual = [v for v in our_scores.values() if v is not None]
    avg_ours = round(sum(actual) / len(actual), 2) if actual else None
    n_total = len(pb.LONGBENCH_TASK_DISPLAY)
    label = f"**Average ({len(actual)}/{n_total} tasks)**"
    paper_em = table2.get("Avg", {}).get("em_llm")
    paper_baseline = table2.get("Avg", {}).get("infllm")
    avg_baseline_label = inf_label
    if paper_em is None and show_per_task:
        paper_em = pb.LONGBENCH_TABLE1_LLAMA31_AVG["em_llm"]
        paper_baseline = pb.LONGBENCH_TABLE1_LLAMA31_AVG["full_context"]
        avg_baseline_label = "Full-Context (paper)"
    rows.append(_row("_avg", label, paper_em, paper_baseline,
                     avg_baseline_label, avg_ours))

    return rows


def build_infbench_rows(our_scores, model, variant, method):
    """Build ∞-Bench side-by-side rows: per-task + overall average.

    method='em_llm': ours vs paper EM-LLM (Table 2 per-task), with InfLLM
    (or Full-Context for llama31+S) as the comparator baseline.

    method='infllm': ours InfLLM vs paper InfLLM, with paper EM-LLM as the
    context column.
    """
    rows = []

    if method == "infllm":
        var_key = pb.paper_infllm_variant_key(model)
        table2 = pb.INFBENCH_TABLE2_PER_TASK.get(model, {}).get(var_key, {})
        em_label = f"EM-LLM (paper, {var_key.upper()})"

        for task, display in pb.INFBENCH_TASK_DISPLAY.items():
            if task not in our_scores:
                continue
            ours = our_scores[task]
            paper_infllm = table2.get(task, {}).get("infllm")
            paper_em = table2.get(task, {}).get("em_llm")
            rows.append(_row(task, display, paper_infllm, paper_em,
                             em_label, ours))

        actual = [v for v in our_scores.values() if v is not None]
        avg_ours = round(sum(actual) / len(actual), 2) if actual else None
        n_total = len(pb.INFBENCH_TASK_DISPLAY)
        label = f"**Average ({len(actual)}/{n_total} tasks)**"
        rows.append(_row("_avg", label, None, None, "", avg_ours))
        return rows

    # method == "em_llm": original logic.
    table2 = pb.INFBENCH_TABLE2_PER_TASK.get(model, {}).get(variant, {})
    table1 = (pb.INFBENCH_TABLE1_LLAMA31
              if model == "llama31" and variant == "s" else {})

    variant_inf = table2.get("variant_infllm", "")
    inf_label = (f"InfLLM (paper, {variant_inf})" if variant_inf
                 else "InfLLM (paper)")

    for task, display in pb.INFBENCH_TASK_DISPLAY.items():
        if task not in our_scores:
            continue
        ours = our_scores[task]
        if task in table2:
            paper_em = table2[task].get("em_llm")
            paper_baseline = table2[task].get("infllm")
            baseline_label = inf_label
        else:
            paper_em = table1.get(task, {}).get("em_llm")
            paper_baseline = table1.get(task, {}).get("full_context")
            baseline_label = ("Full-Context (paper)"
                              if paper_baseline is not None else "")
        rows.append(_row(task, display, paper_em, paper_baseline,
                         baseline_label, ours))

    actual = [v for v in our_scores.values() if v is not None]
    avg_ours = round(sum(actual) / len(actual), 2) if actual else None
    n_total = len(pb.INFBENCH_TASK_DISPLAY)
    label = f"**Average ({len(actual)}/{n_total} tasks)**"
    paper_em = None
    paper_baseline = None
    avg_baseline_label = ""
    # Table 1 fallback: llama31 + S has its overall ∞-Bench Avg in Table 1.
    if table1:
        paper_em = pb.INFBENCH_TABLE1_LLAMA31_AVG["em_llm"]
        paper_baseline = pb.INFBENCH_TABLE1_LLAMA31_AVG["full_context"]
        avg_baseline_label = "Full-Context (paper)"
    rows.append(_row("_avg", label, paper_em, paper_baseline,
                     avg_baseline_label, avg_ours))
    return rows


def build_passkey_rows(our_scores, model, variant, method):
    """Build extended-PassKey rows. Paper Figure 2 (right) anchors EM-LLM_S
    on Mistral at 100% for 10M tokens; no per-length-bin paper table.
    """
    rows = []
    anchor = pb.PASSKEY_HEADLINE.get(model, {}).get("em_llm_at_10m")
    for task, score in our_scores.items():
        label = ("Paper Fig. 2 anchor (Mistral, 10M)"
                 if anchor is not None else "")
        rows.append(_row(task, "Passkey (extended)", anchor, None,
                         label, score))
    return rows


def _row(task, display, paper_em, paper_baseline, baseline_label, ours):
    """Assemble one row dict with a computed delta."""
    delta = (round(ours - paper_em, 2)
             if (ours is not None and paper_em is not None) else None)
    return {
        "task": task,
        "display": display,
        "paper_em_llm": paper_em,
        "paper_baseline": paper_baseline,
        "baseline_label": baseline_label,
        "ours": ours,
        "delta_vs_em_llm": delta,
    }


def fmt(value):
    """Format a score on the 0-100 scale as 'NN.NN', or 'n/a' if missing."""
    return "n/a" if value is None else f"{value:.2f}"


def fmt_delta(value):
    """Format a signed delta as '+N.NN' / '-N.NN', or 'n/a' if missing."""
    return "n/a" if value is None else f"{value:+.2f}"


def render_markdown(rows, benchmark, model, variant, method, results_dir):
    """Render rows into a markdown table mirroring the paper's layout."""
    if method == "infllm":
        method_display = f"InfLLM ({variant})"
        paper_col = "Paper InfLLM"
        baseline_col = "Paper EM-LLM (context)"
        delta_col = "Δ (ours − paper InfLLM)"
    else:
        method_display = f"EM-LLM_{variant.upper()}"
        paper_col = "Paper EM-LLM"
        baseline_col = "Paper baseline"
        delta_col = "Δ (ours − paper EM-LLM)"

    title = (f"# {benchmark.capitalize()} -- {model} ({method_display}) "
             f"-- side-by-side summary")
    intro = (
        f"Source: `{results_dir.name}/result.json`. Paper numbers from "
        f"`em-llm-model/benchmark/further_results.md` (Tables 1 and 2). "
        f"Edit `reproduction/analysis/paper_baselines.py` to adjust them."
    )
    header = f"| Task | {paper_col} | {baseline_col} | Ours | {delta_col} |"
    align = "|------|-------------:|---------------:|-----:|------------------------:|"

    lines = [title, "", intro, "", header, align]
    for r in rows:
        if r["paper_baseline"] is not None and r["baseline_label"]:
            baseline_cell = f"{fmt(r['paper_baseline'])} _({r['baseline_label']})_"
        else:
            baseline_cell = fmt(r["paper_baseline"])
        lines.append(
            f"| {r['display']} "
            f"| {fmt(r['paper_em_llm'])} "
            f"| {baseline_cell} "
            f"| {fmt(r['ours'])} "
            f"| {fmt_delta(r['delta_vs_em_llm'])} |"
        )

    if method == "infllm":
        footer = ("A negative Δ means our InfLLM scores below the paper's "
                  "InfLLM for the same task and model. The 'Paper EM-LLM' "
                  "column is for context — it shows how big the EM-LLM-vs-"
                  "InfLLM gap is in the paper, so you can compare our "
                  "reproduction's gap to theirs.")
    else:
        footer = ("A negative Δ means we score below the paper for the same "
                  "task and base model + variant. The repo's README treats "
                  "±1.5 points per task as a clean reproduction at this scale.")
    lines += ["", footer]
    return "\n".join(lines) + "\n"


def write_csv(rows, out_path):
    """Persist rows as CSV for downstream notebooks/analysis."""
    cols = ["task", "display", "paper_em_llm", "paper_baseline",
            "baseline_label", "ours", "delta_vs_em_llm"]
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=cols)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_dir", type=Path,
                        help="Directory containing result.json")
    args = parser.parse_args(argv)

    results_dir = args.results_dir.resolve()
    if not results_dir.is_dir():
        sys.exit(f"Not a directory: {results_dir}")

    benchmark, method = detect_benchmark_and_method(results_dir)
    model, variant = detect_model_and_variant(results_dir, method)
    our_scores = load_our_scores(results_dir)

    if benchmark == "longbench":
        rows = build_longbench_rows(our_scores, model, variant, method)
    elif benchmark == "infinitebench":
        rows = build_infbench_rows(our_scores, model, variant, method)
    else:
        rows = build_passkey_rows(our_scores, model, variant, method)

    md = render_markdown(rows, benchmark, model, variant, method, results_dir)
    (results_dir / "summary.md").write_text(md, encoding="utf-8")
    write_csv(rows, results_dir / "summary.csv")
    print(f"[summary] wrote {results_dir / 'summary.md'}")
    print(f"[summary] wrote {results_dir / 'summary.csv'}")


if __name__ == "__main__":
    main()
