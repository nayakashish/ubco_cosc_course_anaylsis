"""RQ4 chart: extra terms to graduate when one course is missed once.

Reads output/rq4_term_delay.csv (written by rq4_term_simulation.py) and saves
output/figures/26_rq4_term_delay.png. Shows the BSc, Winter-only runs.

Run from the project root: python rq4_chart.py
"""
import csv, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
SRC = ROOT / "output" / "rq4_term_delay.csv"
OUT = ROOT / "output" / "figures" / "26_rq4_term_delay.png"
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
rows = list(csv.DictReader(open(SRC, newline="", encoding="utf-8")))
courses = ["COSC 111","COSC 121","COSC 122","COSC 123","COSC 211","COSC 221","COSC 222","COSC 304","COSC 310","COSC 320","COSC 341"]
def get(pat, load):
    d = {r["missed_course"]: int(r["extra_terms"]) for r in rows
         if r["pattern"]==pat and r["summer"]=="no" and r["load"]==load and r["program"]=="BSc"}
    return [d[c] for c in courses]
C5, C6, TXT, TXT2, GRID = "#257de0", "#f47230", "#191919", "#666666", "#e5e5e5"
plt.rcParams.update({"font.family":"DejaVu Sans","font.size":11})
fig, axes = plt.subplots(1, 2, figsize=(12, 5.6), sharey=True)
y = range(len(courses)); h = 0.38
for ax, pat, base in zip(axes, ["2025-26","2022-23"], [("8","7")]*2):
    a, b = get(pat,"5 courses"), get(pat,"6 courses")
    ax.barh([i-h/2-0.01 for i in y], a, h, color=C5, label="5 courses per term (graduate in 8 terms)")
    ax.barh([i+h/2+0.01 for i in y], b, h, color=C6, label="6 courses per term (graduate in 7 terms)")
    for i,(va,vb) in enumerate(zip(a,b)):
        if va: ax.text(va+0.04, i-h/2, f"+{va}", va="center", color=TXT, fontsize=10)
        if vb: ax.text(vb+0.04, i+h/2, f"+{vb}", va="center", color=TXT, fontsize=10)
        if not va and not vb: ax.text(0.04, i, "no delay", va="center", color=TXT2, fontsize=9)
    ax.set_title(f"{pat} course offerings", loc="left", color=TXT, fontsize=13, fontweight="bold")
    ax.set_xlim(0, 2.5); ax.set_xticks([0,1,2])
    ax.set_xlabel("Extra terms to graduate", color=TXT2)
    ax.xaxis.grid(True, color=GRID); ax.set_axisbelow(True)
    for s in ["top","right","left"]: ax.spines[s].set_visible(False)
    ax.spines["bottom"].set_color(GRID); ax.tick_params(colors=TXT2, length=0)
axes[0].set_yticks(list(y)); axes[0].set_yticklabels(courses, color=TXT); axes[0].invert_yaxis()
fig.suptitle("Extra terms to graduate when one course is missed once (BSc, no summer terms)", x=0.01, ha="left", fontsize=14, color=TXT)
fig.legend(*axes[0].get_legend_handles_labels(), loc="upper left", bbox_to_anchor=(0.01, 0.93), ncol=2, frameon=False, fontsize=10.5)
fig.text(0.01, 0.01, "BA results are the same, except missing COSC 222 adds no terms in 2022-23. Source: rq4_term_simulation.py", color=TXT2, fontsize=9)
fig.tight_layout(rect=[0,0.03,1,0.9])
OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=200)
print("saved", OUT.relative_to(ROOT))
