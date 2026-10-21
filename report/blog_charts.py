"""Render the blog post's charts from results/report_data.json.

usage: uv run --with matplotlib python report/blog_charts.py OUT_DIR
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
DATA = json.loads((ROOT / "results" / "report_data.json").read_text())

INK, INK2, MUTED, GRID, BG = "#121417", "#4a5058", "#737a83", "#eceef1", "#ffffff"
ARM = {"none": "#2a78d6", "available": "#eb6834", "forced": "#1baf7a"}
ARM_LABEL = {"none": "No skills", "available": "Skills available", "forced": "Skills forced"}
MODELS = ["Opus", "Sonnet", "Haiku"]
ROUND = {"v1": "Round 1 (7 tickets)", "v2": "Round 2 (12 tickets)"}

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11, "axes.edgecolor": GRID,
                     "axes.labelcolor": INK2, "xtick.color": MUTED, "ytick.color": INK,
                     "figure.facecolor": BG, "axes.facecolor": BG, "savefig.facecolor": BG})


def dot_panels(key, lo, hi, ticks, fmt, title, fname, note=None):
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4), sharex=True)
    for ax, suite in zip(axes, ["v1", "v2"]):
        y, yt, yl = 0, [], []
        for m in MODELS:
            pts = [d for a in ARM for d in DATA if d["suite"] == suite and d["model"] == m and d["skills"] == a]
            for i, d in enumerate(pts):
                yy = y - i * 0.32
                v = d[key]
                ax.plot([lo, v], [yy, yy], color=ARM[d["skills"]], alpha=.3, lw=2, solid_capstyle="round", zorder=1)
                ax.scatter([v], [yy], s=70, color=ARM[d["skills"]], edgecolor=BG, linewidth=1.5, zorder=3)
                ax.text(v + (hi - lo) * .015, yy, fmt(v), va="center", fontsize=9, color=INK, fontweight="bold")
            yt.append(y - (len(pts) - 1) * .16)
            yl.append(m)
            y -= len(pts) * .32 + .45
        ax.set_yticks(yt, yl, fontweight="bold")
        ax.set_xlim(lo, hi + (hi - lo) * .1)
        ax.set_xticks(ticks, [fmt(t) for t in ticks])
        ax.grid(axis="x", color=GRID)
        ax.set_axisbelow(True)
        for s in ("top", "right", "left"):
            ax.spines[s].set_visible(False)
        ax.tick_params(axis="y", length=0)
        ax.set_title(ROUND[suite], loc="left", fontsize=12, color=INK, fontweight="bold")
    handles = [plt.Line2D([], [], marker="o", ls="", color=ARM[a], markersize=8, label=ARM_LABEL[a]) for a in ARM]
    fig.legend(handles=handles, loc="upper right", ncol=3, frameon=False, fontsize=10, bbox_to_anchor=(.99, .99))
    fig.suptitle(title, x=.01, y=.97, ha="left", fontsize=14, color=INK, fontweight="bold")
    if note:
        fig.text(.01, .01, note, fontsize=9, color=MUTED)
    fig.tight_layout(rect=(0, .04 if note else 0, 1, .93))
    fig.savefig(OUT / fname, dpi=180)
    plt.close(fig)


dot_panels("pct", 50, 100, [50, 60, 70, 80, 90, 100], lambda v: f"{v:.0f}%",
           "Answer-key checks passed, by model and skills arm", "correctness-by-arm.png",
           "Each check compares a required model row by row with an answer key, after the harness injects new data and rebuilds.")
dot_panels("judge", 3, 5, [3, 3.5, 4, 4.5, 5], lambda v: f"{v:.2f}".rstrip("0").rstrip(".") if v % 1 else f"{v:.0f}",
           "Blind code-review score (1–5), by model and skills arm", "review-score-by-arm.png",
           "Reviewing the same project twice gave 4.00 and 4.22, so gaps under ~0.2 are noise.")

# Skill usage: files opened per run across the whole suite (skills arms only)
fig, ax = plt.subplots(figsize=(11, 3.9))
rows = [d for d in DATA if d["skills"] != "none"]
rows.sort(key=lambda d: (d["suite"], MODELS.index(d["model"]), list(ARM).index(d["skills"])))
labels = [f'{ROUND[d["suite"]].split(" (")[0]} · {d["model"]}' for d in rows]
xs = range(len(rows))
ax.bar(xs, [d["reads"] for d in rows], color=[ARM[d["skills"]] for d in rows], width=.62, zorder=2)
for x, d in zip(xs, rows):
    ax.text(x, d["reads"] + .25, str(d["reads"]), ha="center", fontsize=10, color=INK, fontweight="bold")
ax.set_xticks(list(xs), labels, rotation=30, ha="right", fontsize=9)
ax.set_ylabel("Skill files opened (whole suite)")
ax.grid(axis="y", color=GRID, zorder=0)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)
handles = [plt.Rectangle((0, 0), 1, 1, color=ARM[a], label=ARM_LABEL[a]) for a in ("available", "forced")]
ax.legend(handles=handles, frameon=False, loc="upper left")
ax.set_title("Agents rarely opened the skills unless told to", loc="left", fontsize=14, color=INK, fontweight="bold")
fig.tight_layout()
fig.savefig(OUT / "skill-usage.png", dpi=180)
plt.close(fig)

# What actually went wrong: defect types by arm
defects = [("Hard-coded test broke on new data", {"none": 3, "available": 3, "forced": 3}),
           ("Missed a spec detail", {"none": 0, "available": 1, "forced": 2}),
           ("Restored a stale backup", {"none": 0, "available": 1, "forced": 0}),
           ("Guardrail made builds ~10× slower", {"none": 0, "available": 1, "forced": 1}),
           ("Wrong late-data handling", {"none": 1, "available": 0, "forced": 0})]
fig, ax = plt.subplots(figsize=(11, 4.2))
h = .24
for i, (name, counts) in enumerate(defects):
    for j, a in enumerate(ARM):
        y = i + (j - 1) * h
        ax.barh(y, counts[a], height=h * .88, color=ARM[a], zorder=2)
        if counts[a]:
            ax.text(counts[a] + .05, y, str(counts[a]), va="center", fontsize=9, color=INK, fontweight="bold")
ax.set_yticks(range(len(defects)), [d[0] for d in defects])
ax.invert_yaxis()
ax.set_xlabel("Runs")
ax.set_xticks(range(0, 4))
ax.grid(axis="x", color=GRID, zorder=0)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.tick_params(axis="y", length=0)
handles = [plt.Rectangle((0, 0), 1, 1, color=ARM[a], label=ARM_LABEL[a]) for a in ARM]
ax.legend(handles=handles, frameon=False, loc="lower right")
ax.set_title("What actually went wrong, across all 17 runs", loc="left", fontsize=14, color=INK, fontweight="bold")
fig.tight_layout()
fig.savefig(OUT / "defects-by-arm.png", dpi=180)
plt.close(fig)

# The eval loop diagram
fig, ax = plt.subplots(figsize=(12, 4))
ax.set_xlim(0, 12.2)
ax.set_ylim(-0.4, 3.0)
ax.axis("off")
steps = [("Ticket", "harness sends the\nnext task prompt"), ("Agent", "builds or changes\nthe dbt project"),
         ("Inject", "new races, corrections,\nvendor drift, bugs"), ("Rebuild", "harness runs dbt build\n(no full refresh)"),
         ("Grade", "models vs answer keys\nplus structural checks")]
bw, step = 2.0, 2.45
for i, (t, sub) in enumerate(steps):
    x = .1 + i * step
    ax.add_patch(FancyBboxPatch((x, 1.3), bw, 1.45, boxstyle="round,pad=0.02,rounding_size=0.12",
                                fc="#f3f5f7", ec="#c9ced4", lw=1.2))
    ax.text(x + bw / 2, 2.35, t, ha="center", fontsize=13, fontweight="bold", color=INK)
    ax.text(x + bw / 2, 1.62, sub, ha="center", fontsize=9, color=INK2, linespacing=1.45)
    if i < len(steps) - 1:
        ax.annotate("", xy=(x + step - .02, 2.02), xytext=(x + bw + .05, 2.02),
                    arrowprops=dict(arrowstyle="-|>", color=MUTED, lw=1.5))
ax.annotate("", xy=(.1 + bw / 2, 1.27), xytext=(.1 + 4 * step + bw / 2, 1.27),
            arrowprops=dict(arrowstyle="-|>", color="#c1121f", lw=1.5, connectionstyle="arc3,rad=-0.18"))
ax.text(6.1, -0.3, "Repeat for every ticket. Later tickets re-check every earlier model, so regressions show up.",
        ha="center", fontsize=10, color="#c1121f")
fig.savefig(OUT / "eval-loop.png", dpi=180, bbox_inches="tight")
plt.close(fig)
print("wrote", sorted(p.name for p in OUT.glob("*.png")))
