"""Flatten every run's grades and metrics into CSVs for the dbt Charts dashboard.

usage: publish_results.py   (step.sh runs it after every `done`)

Writes dashboard/data/{grades,checks,metrics,flags}.csv. Local files only, so grades never
land in the warehouse where an agent could find them.
"""
import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"
OUT = ROOT / "dashboard" / "data"

MODELS = {"": ("Opus", 1), "S": ("Sonnet", 2), "H": ("Haiku", 3)}
SKILLS = {"A": ("none", 1), "B": ("available", 2), "C": ("forced", 3)}


def describe(run_id):
    arm = run_id.split("_")[0]
    suite = "v2" if "_v2_" in run_id.lower() else "v1"
    m = re.fullmatch(r"([SH]?)([ABC])", arm)
    if m:
        (model, mo), (skills, so) = MODELS[m.group(1)], SKILLS[m.group(2)]
    else:  # Wizard arms
        model, mo, skills, so = ("Wizard" if arm == "W" else "Wizard + Claude"), 4, "built-in", 4
    return {"run_id": run_id, "run_label": f"{model} · {skills} ({run_id})", "model": model,
            "model_order": mo, "skills": skills, "skills_order": so, "suite": suite}


def write(name, rows, fields):
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / f"{name}.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main():
    grades, checks, metrics, flags = [], [], [], []
    for rdir in sorted(p for p in RES.iterdir() if (p / "grades").is_dir()):
        d = describe(rdir.name)
        for g_path in sorted((rdir / "grades").glob("t*_*.json")):
            if not re.fullmatch(r"t\d\d_(agent|rebuild)\.json", g_path.name):
                continue
            g = json.loads(g_path.read_text())
            dc = g.get("data_checks", {})
            passed, total = sum(1 for c in dc.values() if c.get("ok")), len(dc)
            build = g.get("harness_build")
            graded_at = datetime.fromtimestamp(g_path.stat().st_mtime, timezone.utc).isoformat()
            grades.append({**d, "task": g["task"], "phase": g["phase"], "passed": passed, "total": total,
                           "score": round(passed / total, 4) if total else None,
                           "build_ok": "" if build is None else int(build.get("exit_code") == 0),
                           "graded_at": graded_at})
            for name, c in dc.items():
                mism = c.get("column_mismatches") or {}
                checks.append({**d, "task": g["task"], "phase": g["phase"], "check": name, "ok": int(bool(c.get("ok"))),
                               "detail": c.get("error") or ", ".join(f"{k} ({v})" for k, v in mism.items())
                               or ", ".join(f"{k}={c.get(k)}" for k in ("missing_rows", "extra_rows", "duplicate_keys")
                                            if c.get(k))})
            if g["phase"] != "rebuild":
                continue
            s = g.get("structural", {})
            extra = {k: v for k, v in s.items() if isinstance(v, (bool, int, float, str)) and k != "counts"}
            extra.update({f"count_{k}": v for k, v in (s.get("counts") or {}).items()})
            if g.get("telemetry_cost"):
                extra["telemetry_scan_ratio"] = g["telemetry_cost"].get("scan_ratio")
            if g.get("ci_probe"):
                extra["ci_probe_ok"] = g["ci_probe"].get("ok")
            for k, v in extra.items():
                flags.append({**d, "task": g["task"], "flag": k, "value": v})
        for m_path in sorted((rdir / "logs").glob("t*_metrics.json")):
            m = json.loads(m_path.read_text())
            metrics.append({**d, "task": int(m_path.name[1:3]), **{k: m.get(k) for k in (
                "output_tokens", "input_tokens", "tool_calls", "tool_errors", "dbt_invocations",
                "wallclock_s", "nudges")}, "skill_reads": len(m.get("skills_used") or []),
                "skills_used": "; ".join(sorted(set(m.get("skills_used") or [])))})
    base = list(describe("A_1"))
    write("grades", grades, base + ["task", "phase", "passed", "total", "score", "build_ok", "graded_at"])
    write("checks", checks, base + ["task", "phase", "check", "ok", "detail"])
    write("metrics", metrics, base + ["task", "output_tokens", "input_tokens", "tool_calls", "tool_errors",
                                      "dbt_invocations", "wallclock_s", "nudges", "skill_reads", "skills_used"])
    write("flags", flags, base + ["task", "flag", "value"])
    print(f"[publish] {len(grades)} grades, {len(checks)} checks, {len(metrics)} metric rows -> {OUT}")


if __name__ == "__main__":
    main()
