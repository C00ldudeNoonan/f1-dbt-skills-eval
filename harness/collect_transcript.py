"""Find the app session that worked in a run's workspace and pull per-task process metrics.

usage: collect_transcript.py RUN_ID TASK

Claude app sessions: ~/.claude/projects/<encoded workspace path>/*.jsonl
Wizard sessions:     ~/.dbt/wizard/sessions/YYYY/MM/DD/rollout-*.jsonl (matched on session_meta.cwd)

Metrics are sliced to the task's time window from results/RUN_ID/timeline.txt.
Writes results/RUN_ID/logs/session.jsonl (latest copy) and tNN_metrics.json.
"""
import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

from sf import CFG, ROOT

HOME = Path.home()
DBT_CMD = re.compile(r"(^|[;&|\s\"'])dbt\s+(build|run|test|compile|snapshot|seed|parse|show|ls|list|source)\b")


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def window(rdir, task):
    start = end = None
    for line in (rdir / "timeline.txt").read_text().splitlines():
        t, kind, at = line.split()
        if t == str(task) and kind == "start":
            start = int(at)
        if t == str(task) and kind == "end":
            end = int(at)
    nudges = sum(1 for line in (rdir / "timeline.txt").read_text().splitlines()
                 if line.split()[1] == "nudge" and start and end and start <= int(line.split()[2]) <= end)
    return start, end, nudges


def claude_session(proj: Path):
    enc = re.sub(r"[^A-Za-z0-9]", "-", str(proj))
    d = HOME / ".claude" / "projects" / enc
    files = sorted(d.glob("*.jsonl"), key=lambda p: p.stat().st_mtime) if d.exists() else []
    return files[-1] if files else None


def wizard_session(proj: Path):
    root = HOME / ".dbt" / "wizard" / "sessions"
    for f in sorted(root.rglob("rollout-*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)[:200]:
        with f.open() as fh:
            first = json.loads(fh.readline() or "{}")
        cwd = (first.get("payload") or {}).get("cwd", "")
        if cwd and Path(cwd).resolve() == proj.resolve():
            return f
    return None


def claude_metrics(f, start, end):
    m = {"input_tokens": 0, "output_tokens": 0, "tool_calls": 0, "tool_errors": 0,
         "dbt_invocations": 0, "skills_used": [], "assistant_turns": 0}
    seen = set()
    for line in f.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "timestamp" not in ev or not (start <= ts(ev["timestamp"]) <= end):
            continue
        msg = ev.get("message") or {}
        if ev.get("type") == "assistant" and msg.get("id") not in seen:
            seen.add(msg.get("id"))
            m["assistant_turns"] += 1
            u = msg.get("usage") or {}
            m["input_tokens"] += (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                                  + u.get("cache_creation_input_tokens", 0))
            m["output_tokens"] += u.get("output_tokens", 0)
        for b in msg.get("content") or []:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "tool_use":
                m["tool_calls"] += 1
                inp = b.get("input") or {}
                if b.get("name") == "Bash" and DBT_CMD.search(inp.get("command", "")):
                    m["dbt_invocations"] += 1
                if b.get("name") == "Skill":
                    m["skills_used"].append(inp.get("skill"))
                else:  # skills read directly (cat/Read of .claude/skills/<name>/...)
                    for hit in re.findall(r"\.claude/skills/([a-z0-9-]+)", json.dumps(inp)):
                        m["skills_used"].append(f"read:{hit}")
            if b.get("type") == "tool_result" and b.get("is_error"):
                m["tool_errors"] += 1
    return m


def wizard_metrics(f, start, end):
    m = {"input_tokens": 0, "output_tokens": 0, "tool_calls": 0, "tool_errors": 0,
         "dbt_invocations": 0, "skills_used": [], "assistant_turns": 0}
    before = during = None
    for line in f.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = ts(ev["timestamp"]) if "timestamp" in ev else None
        p = ev.get("payload") or {}
        if p.get("type") == "token_count" and (p.get("info") or {}).get("total_token_usage"):
            usage = p["info"]["total_token_usage"]
            if t is not None and t < start:
                before = usage
            elif t is not None and t <= end:
                during = usage
        if t is None or not (start <= t <= end):
            continue
        if p.get("type") in ("function_call", "custom_tool_call"):
            m["tool_calls"] += 1
            if DBT_CMD.search(json.dumps(p.get("arguments") or p.get("input") or "")):
                m["dbt_invocations"] += 1
            if "skill" in (p.get("name") or "").lower():
                m["skills_used"].append(p.get("arguments"))
        if p.get("type") == "agent_message":
            m["assistant_turns"] += 1
    if during:
        b = before or {}
        m["input_tokens"] = during.get("input_tokens", 0) - b.get("input_tokens", 0)
        m["output_tokens"] = during.get("output_tokens", 0) - b.get("output_tokens", 0)
    return m


def main():
    run_id, task = sys.argv[1], int(sys.argv[2])
    arm = run_id.split("_")[0]
    is_claude = bool(re.fullmatch(r"[SH]?[ABC]", arm))
    proj = Path(CFG["RUNS_DIR"]) / run_id / "project"
    rdir = ROOT / "results" / run_id
    start, end, nudges = window(rdir, task)
    f = claude_session(proj) if is_claude else wizard_session(proj)
    if not f:
        print(f"[transcript] no session found for {proj} (is the session open in that exact folder?)")
        return
    shutil.copy(f, rdir / "logs" / "session.jsonl")
    m = (claude_metrics if is_claude else wizard_metrics)(f, start, end)
    # Wall clock = prompt sent -> agent's last transcript event (not when you ran `done`)
    last = start
    for line in f.read_text().splitlines():
        try:
            t = ts(json.loads(line).get("timestamp", ""))
        except (json.JSONDecodeError, ValueError):
            continue
        if start <= t <= end:
            last = max(last, t)
    m.update(wallclock_s=round(last - start), nudges=nudges, session_file=str(f))
    (rdir / "logs" / f"t{task:02d}_metrics.json").write_text(json.dumps(m, indent=2))
    print(f"[transcript] t{task}: {m['tool_calls']} tool calls, {m['dbt_invocations']} dbt calls, "
          f"{m['output_tokens']:,} output tokens, {m['wallclock_s']}s, {nudges} nudges")


if __name__ == "__main__":
    main()
