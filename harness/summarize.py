"""Summarize one run (summarize.py RUN_ID) or all runs (summarize.py) into results/.

Per task: data checks passed as the agent left it, data checks passed after the harness
injected new data and rebuilt, whether that rebuild succeeded, plus process metrics pulled
from the app session transcript (tokens, turns, dbt invocations, nudges, wall clock).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"
def summarize(run_id: str):
    rdir = RES / run_id
    arm = run_id.split("_")[0]
    rows = []
    for t in range(1, 8):
        g = {}
        for phase in ("agent", "rebuild"):
            f = rdir / "grades" / f"t{t:02d}_{phase}.json"
            g[phase] = json.loads(f.read_text()) if f.exists() else None
        if not g["agent"]:
            continue
        mf = rdir / "logs" / f"t{t:02d}_metrics.json"
        metrics = json.loads(mf.read_text()) if mf.exists() else {}
        metrics.pop("session_file", None)
        reb = g["rebuild"] or {}
        rows.append({
            "run_id": run_id, "arm": arm, "task": t,
            "data_agent": g["agent"]["data_score"],
            "data_rebuild": reb.get("data_score"),
            "rebuild_ok": (reb.get("harness_build") or {}).get("exit_code") == 0,
            "structural": reb.get("structural") or g["agent"].get("structural"),
            "failed_checks": {k: v for k, v in (reb.get("data_checks") or {}).items() if not v.get("ok")},
            **{k: v for k, v in metrics.items()},
        })
    (rdir / "summary.json").write_text(json.dumps(rows, indent=2, default=str))
    return rows


def frac(s):
    if not s:
        return 0.0
    a, b = s.split("/")
    return int(a) / int(b) if int(b) else 0.0


def main():
    run_ids = sys.argv[1:] or sorted(p.name for p in RES.iterdir() if (p / "grades").exists())
    all_rows = [r for rid in run_ids for r in summarize(rid)]
    lines = ["| run | task | data (agent) | data (rebuild) | rebuild ok | out tokens | tool calls | dbt calls | nudges | wall s |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for r in all_rows:
        lines.append(f"| {r['run_id']} | {r['task']} | {r['data_agent']} | {r['data_rebuild']} | "
                     f"{'yes' if r['rebuild_ok'] else 'NO'} | {r.get('output_tokens') or 0:,} | "
                     f"{r.get('tool_calls', '-')} | {r.get('dbt_invocations', '-')} | {r.get('nudges', '-')} | "
                     f"{r.get('wallclock_s', '-')} |")
    by_arm = {}
    for r in all_rows:
        by_arm.setdefault(r["arm"], []).append(r)
    lines += ["", "| arm | runs | mean data score (rebuild) | rebuilds ok | output tokens | nudges |", "|---|---|---|---|---|---|"]
    for arm, rs in sorted(by_arm.items()):
        runs = len({r["run_id"] for r in rs})
        mean = sum(frac(r["data_rebuild"]) for r in rs) / len(rs)
        ok = sum(r["rebuild_ok"] for r in rs)
        toks = sum(r.get("output_tokens") or 0 for r in rs)
        nudges = sum(r.get("nudges") or 0 for r in rs)
        lines.append(f"| {arm} | {runs} | {mean:.0%} | {ok}/{len(rs)} | {toks:,} | {nudges} |")
    out = "\n".join(lines)
    (RES / ("summary.md" if not sys.argv[1:] else f"{run_ids[0]}/summary.md")).write_text(out)
    print(out)


if __name__ == "__main__":
    main()
