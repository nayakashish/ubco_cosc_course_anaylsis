"""Build the analysis networks and figures for the COSC 421 project.

Reads the scraped prerequisite data (output/) and the UBC PAIR grade data,
writes networks to output/networks/ and figures to output/figures/.
Descriptive only: no conclusions are drawn here.

Run from the project root:  venv/bin/python build_networks.py
"""

import csv
import math
from collections import defaultdict
from itertools import combinations
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
from matplotlib.lines import Line2D
from networkx.algorithms.link_analysis.pagerank_alg import _pagerank_python

ROOT = Path(__file__).resolve().parent
GRADES = ROOT / "UBC Pair Grade Data"
NET_DIR = ROOT / "output" / "networks"
FIG_DIR = ROOT / "output" / "figures"
NET_DIR.mkdir(parents=True, exist_ok=True)
FIG_DIR.mkdir(parents=True, exist_ok=True)

# Palette (dataviz reference palette, light mode). Three categorical slots max
# where marks can sit next to any other mark.
BLUE, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"
GRAY, INK, INK2, GRID = "#b4b2ab", "#0b0b0b", "#52514e", "#e4e3df"
SURFACE = "#fcfcfb"
SEQ = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]
DIV_NEG, DIV_POS = "#eb6834", "#2a78d6"

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "axes.edgecolor": GRID, "axes.labelcolor": INK2, "axes.titlecolor": INK,
    "xtick.color": INK2, "ytick.color": INK2, "text.color": INK,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
    "axes.axisbelow": True, "font.size": 10, "axes.titlesize": 12,
    "axes.titleweight": "bold", "savefig.dpi": 160, "savefig.bbox": "tight",
})


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def level(code):
    digits = "".join(ch for ch in code.split()[-1] if ch.isdigit())
    return int(digits[0]) if digits else 0


def subject_group(code):
    subj = code.split()[0]
    if subj == "COSC":
        return "COSC"
    if subj in ("MATH", "STAT", "DATA"):
        return "MATH / STAT / DATA"
    return "Other (APSC, PHYS, ...)"


GROUP_COLOR = {"COSC": BLUE, "MATH / STAT / DATA": ORANGE, "Other (APSC, PHYS, ...)": AQUA}


# ---------------------------------------------------------------- load data
courses = read_csv(ROOT / "output" / "courses.csv")
edges = read_csv(ROOT / "output" / "edges.csv")
by_course = {r["Course Code"]: r for r in read_csv(GRADES / "UBC Pair data - ubco_grades_by_course.csv")}
required = read_csv(GRADES / "UBC Pair data - ubco_grades_required.csv.csv")
sections = read_csv(GRADES / "UBC Pair data - ubco_grades_all_sections.csv")

BSC = {r["Course Code"] for r in required if r["In BSc"] == "TRUE"} | {"COSC 270", "ENGL 113"}
BA = {r["Course Code"] for r in required if r["In BA"] == "TRUE"}

titles = {c["code"]: c["title"] for c in courses}


def node_attrs(code):
    g = by_course.get(code, {})
    a = {
        "title": titles.get(code) or g.get("Title", ""),
        "subject": code.split()[0],
        "group": subject_group(code),
        "year_level": level(code),
        "in_bsc": code in BSC,
        "in_ba": code in BA,
        "has_grades": bool(g),
    }
    for key, col in [("avg_grade", "Avg Grade"), ("fail_rate", "Fail Rate %"),
                     ("students", "Students"), ("terms_offered", "Terms_Offered")]:
        v = num(g.get(col))
        if v is not None:
            a[key] = v
    if g:
        a["offered_winter"] = g["Offered_in_Winter"] == "TRUE"
        a["offered_summer"] = g["Offered_in_Summer"] == "TRUE"
    return a


def build(edge_rows, keep_node=lambda c: True, extra_nodes=()):
    G = nx.DiGraph()
    for c in extra_nodes:
        if keep_node(c):
            G.add_node(c)
    for e in edge_rows:
        s, t = e["source"], e["target"]
        if keep_node(s) and keep_node(t):
            G.add_edge(s, t, relation=e["relation"])
    for n in G.nodes:
        G.nodes[n].update(node_attrs(n))
    return G


undergrad = [c["code"] for c in courses if level(c["code"]) <= 4]

# ---------------------------------------------------------------- networks
NETWORKS = {}
NETWORKS["N1_full"] = build(edges, extra_nodes=undergrad)
NETWORKS["N2_prereq_only"] = build([e for e in edges if e["relation"] == "prereq"], extra_nodes=undergrad)
NETWORKS["N3_cosc_only"] = build(edges, keep_node=lambda c: c.startswith("COSC"), extra_nodes=undergrad)

full = NETWORKS["N1_full"]


def degree_subnetwork(req):
    keep = set()
    for c in req:
        keep.add(c)
        if c in full:
            keep |= nx.ancestors(full, c)
    H = full.subgraph(keep).copy()
    H.add_nodes_from(c for c in req if c not in H)
    for n in H.nodes:
        H.nodes[n].update(node_attrs(n))
        H.nodes[n]["required"] = n in req
    return H


NETWORKS["N4_bsc"] = degree_subnetwork(BSC)
NETWORKS["N5_ba"] = degree_subnetwork(BA)
union = nx.compose(NETWORKS["N4_bsc"], NETWORKS["N5_ba"])
for n in union.nodes:
    union.nodes[n].update(node_attrs(n))
    inb, ina = n in NETWORKS["N4_bsc"], n in NETWORKS["N5_ba"]
    union.nodes[n]["membership"] = "both" if inb and ina else ("BSc only" if inb else "BA only")
NETWORKS["N6_bsc_ba_union"] = union

# Grade-weighted copy of the full network. Several edge weights so the team can
# pick one later:
#   w_fail_src : fail rate (0-1) of the prerequisite course
#   w_pass_src : pass rate (0-1) of the prerequisite course
#   w_cost_src : 1 / pass rate, an "expected attempts" cost of the prerequisite
#   w_fail_tgt : fail rate (0-1) of the course being unlocked
# Missing grade data falls back to the median fail rate of graded nodes.
W = full.copy()
fails = [d["fail_rate"] for _, d in W.nodes(data=True) if "fail_rate" in d]
median_fail = float(np.median(fails))
for n, d in W.nodes(data=True):
    d["fail_rate_filled"] = d.get("fail_rate", median_fail)
for s, t, d in W.edges(data=True):
    fs = W.nodes[s]["fail_rate_filled"] / 100
    ft = W.nodes[t]["fail_rate_filled"] / 100
    d.update(w_fail_src=fs, w_pass_src=1 - fs, w_cost_src=1 / (1 - fs), w_fail_tgt=ft)
NETWORKS["N7_grade_weighted"] = W

# Node-removal variants for the top COSC courses by number of downstream courses
# (non-COSC entry prereqs like MATH 125 are "one of" alternatives, so skipped).
desc_count = {n: len(nx.descendants(full, n)) for n in full}
top_removed = sorted((n for n in full if n.startswith("COSC")), key=desc_count.get, reverse=True)[:3]
for c in top_removed:
    H = full.copy()
    H.remove_node(c)
    NETWORKS[f"N8_minus_{c.replace(' ', '')}"] = H

# Networks built purely from grade data -------------------------------------
cosc_sections = [r for r in sections if r["Subject"] == "COSC"]

# N9: professor - course bipartite (COSC sections only)
B = nx.Graph()
for r in cosc_sections:
    prof, course = r["Professor"].strip(), r["Course Code"]
    if not prof:
        continue
    B.add_node(course, bipartite="course", **{k: v for k, v in node_attrs(course).items()})
    B.add_node(prof, bipartite="professor")
    if B.has_edge(prof, course):
        B[prof][course]["sections"] += 1
    else:
        B.add_edge(prof, course, sections=1)
NETWORKS["N9_prof_course_bipartite"] = B

# N10: course - course, weighted by number of shared instructors
course_nodes = [n for n, d in B.nodes(data=True) if d["bipartite"] == "course"]
P = nx.Graph()
P.add_nodes_from((n, B.nodes[n]) for n in course_nodes)
for prof in (n for n, d in B.nodes(data=True) if d["bipartite"] == "professor"):
    for a, b in combinations(sorted(B[prof]), 2):
        if P.has_edge(a, b):
            P[a][b]["shared_instructors"] += 1
        else:
            P.add_edge(a, b, shared_instructors=1)
NETWORKS["N10_shared_instructor"] = P

# N11: course similarity by grade distribution (COSC). Bins summed over all
# sections; hidden (<6) counts are blank and treated as 0. Edge if cosine
# similarity is in each other's top-k.
BINS = ["<50", "50-54", "55-59", "60-63", "64-67", "68-71", "72-75", "76-79", "80-84", "85-89", "90-100"]
hist = defaultdict(lambda: np.zeros(len(BINS)))
for r in cosc_sections:
    hist[r["Course Code"]] += np.array([num(r[b]) or 0 for b in BINS])
hist = {c: h / h.sum() for c, h in hist.items() if h.sum() >= 30}
codes = sorted(hist)
M = np.array([hist[c] for c in codes])
Mn = M / np.linalg.norm(M, axis=1, keepdims=True)
S = Mn @ Mn.T
K = 3
S_ = S.copy()
np.fill_diagonal(S_, -1)
topk = {i: set(np.argsort(-S_[i])[:K]) for i in range(len(codes))}
Gs = nx.Graph()
for c in codes:
    Gs.add_node(c, **node_attrs(c))
for i in range(len(codes)):
    for j in topk[i]:
        Gs.add_edge(codes[i], codes[j], similarity=float(S[i, j]))
NETWORKS["N11_grade_similarity"] = Gs

# Save every network --------------------------------------------------------
def clean_for_graphml(G):
    H = G.copy()
    for _, d in H.nodes(data=True):
        for k, v in list(d.items()):
            if isinstance(v, (np.floating, np.integer)):
                d[k] = v.item()
    return H


for name, G in NETWORKS.items():
    nx.write_graphml(clean_for_graphml(G), NET_DIR / f"{name}.graphml")
    with open(NET_DIR / f"{name}_edges.csv", "w", newline="") as f:
        keys = sorted({k for *_, d in G.edges(data=True) for k in d})
        w = csv.writer(f)
        w.writerow(["source", "target"] + keys)
        for s, t, d in G.edges(data=True):
            w.writerow([s, t] + [d.get(k, "") for k in keys])

# Per-node metrics table (full network) for the team to analyse ---------------
G = full
und = G.to_undirected()
rev = G.reverse()
metrics = {
    "in_degree": dict(G.in_degree()),
    "out_degree": dict(G.out_degree()),
    "betweenness": nx.betweenness_centrality(G),
    "closeness_in": nx.closeness_centrality(G),            # reach from prerequisites
    "closeness_out": nx.closeness_centrality(rev),         # reach to downstream courses
    "descendants": desc_count,
    "ancestors": {n: len(nx.ancestors(G, n)) for n in G},
}

# OR-semantics blocking: add a virtual root pointing at every course with no
# prerequisites; a node X "blocks" Y if every path root->Y goes through X
# (X dominates Y). AND-semantics blocking is just descendants.
R = G.copy()
R.add_edges_from(("__ROOT__", n) for n in G if G.in_degree(n) == 0)
idom = nx.immediate_dominators(R, "__ROOT__")
dom_tree = nx.DiGraph((v, u) for u, v in idom.items() if u != v)
metrics["blocked_or"] = {n: len(nx.descendants(dom_tree, n)) if n in dom_tree else 0 for n in G}

pr_plain = _pagerank_python(rev, weight=None)
rev_w = rev.copy()
for u, v, d in rev_w.edges(data=True):  # u = course, v = its prerequisite
    d["weight"] = W.nodes[v]["fail_rate_filled"] / 100
pr_fail = _pagerank_python(rev_w, weight="weight")
katz_plain = nx.katz_centrality(rev, alpha=0.1, weight=None, max_iter=5000)
katz_fail = nx.katz_centrality(rev_w, alpha=0.1, weight="weight", max_iter=5000)
metrics.update(pagerank_rev=pr_plain, pagerank_rev_failw=pr_fail,
               katz_rev=katz_plain, katz_rev_failw=katz_fail)

DAG = nx.is_directed_acyclic_graph(G)
generation = {}
if DAG:
    for i, gen in enumerate(nx.topological_generations(G)):
        for n in gen:
            generation[n] = i
metrics["topo_generation"] = generation
depth = {}
for n in nx.topological_sort(G):
    preds = list(G.predecessors(n))
    depth[n] = 1 + max(depth[p] for p in preds) if preds else 0
metrics["longest_chain_to_node"] = depth

with open(NET_DIR / "node_metrics_full.csv", "w", newline="") as f:
    w = csv.writer(f)
    cols = list(metrics)
    attrs = ["title", "group", "year_level", "in_bsc", "in_ba", "avg_grade", "fail_rate", "terms_offered"]
    w.writerow(["course"] + attrs + cols)
    for n in sorted(G):
        d = G.nodes[n]
        w.writerow([n] + [d.get(a, "") for a in attrs] + [metrics[c].get(n, "") for c in cols])


# ---------------------------------------------------------------- figures
def save(fig, name):
    fig.savefig(FIG_DIR / name)
    plt.close(fig)


def layered_pos(H, key="generation"):
    """x = topological generation (or year level), nodes spread on y."""
    if key == "generation" and nx.is_directed_acyclic_graph(H):
        gens = {n: i for i, g in enumerate(nx.topological_generations(H)) for n in g}
    else:
        gens = {n: H.nodes[n].get("year_level", 0) for n in H}
    cols = defaultdict(list)
    for n, g in gens.items():
        # courses with no prerequisite links at all get their own column at x = -1
        cols[-1 if H.degree(n) == 0 else g].append(n)
    pos = {}
    for g, ns in cols.items():
        ns.sort(key=lambda n: (H.nodes[n].get("group", ""), n))
        for i, n in enumerate(ns):
            pos[n] = (g, (i - (len(ns) - 1) / 2))
    return pos


def draw_prereq(H, title, fname, color_fn, legend, size_fn=None, pos=None,
                highlight_edges=(), key="generation", figsize=(20, 11), drop_isolates=True):
    if drop_isolates:
        H = H.subgraph([n for n in H if H.degree(n) > 0]).copy()
    pos = pos or layered_pos(H, key)
    tallest = max(sum(1 for p in pos.values() if p[0] == x) for x in {p[0] for p in pos.values()})
    figsize = (figsize[0], max(figsize[1], 0.42 * tallest + 2))
    fig, ax = plt.subplots(figsize=figsize)
    ax.grid(False)
    ax.axis("off")
    pre = [(u, v) for u, v, d in H.edges(data=True) if d.get("relation") != "coreq"]
    co = [(u, v) for u, v, d in H.edges(data=True) if d.get("relation") == "coreq"]
    hl = set(highlight_edges)
    kw = dict(ax=ax, arrows=True, arrowstyle="-|>", arrowsize=9, node_size=700,
              connectionstyle="arc3,rad=0.06")
    nx.draw_networkx_edges(H, pos, edgelist=[e for e in pre if e not in hl], edge_color=GRAY, width=0.8, **kw)
    nx.draw_networkx_edges(H, pos, edgelist=[e for e in co if e not in hl], edge_color=GRAY, width=0.8,
                           style="dashed", **kw)
    if hl:
        nx.draw_networkx_edges(H, pos, edgelist=list(hl), edge_color=INK, width=2.4, **kw)
    sizes = [size_fn(n) for n in H] if size_fn else 700
    nx.draw_networkx_nodes(H, pos, ax=ax, node_color=[color_fn(n) for n in H],
                           node_size=sizes, edgecolors=SURFACE, linewidths=2)
    nx.draw_networkx_labels(H, pos, ax=ax, labels={n: n.replace(" ", "\n") for n in H},
                            font_size=6.5, font_color=INK)
    handles = [Line2D([], [], marker="o", ls="", color=c, markersize=10, label=l) for l, c in legend]
    handles += [Line2D([], [], color=GRAY, label="prerequisite"),
                Line2D([], [], color=GRAY, ls="--", label="corequisite")]
    ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.0, 1.0), frameon=False, fontsize=9)
    xlabel = "topological generation (left = no prerequisites)" if key == "generation" else "year level"
    if any(p[0] == -1 for p in pos.values()):
        xlabel += "; far-left column = courses with no prerequisite links"
    ax.set_title(f"{title}\nx-axis: {xlabel}", loc="left")
    save(fig, fname)


group_legend = list(GROUP_COLOR.items())
by_group = lambda H: (lambda n: GROUP_COLOR[H.nodes[n]["group"]])

draw_prereq(full, "N1 Full prerequisite network (undergrad COSC + external prereqs)",
            "01_full_network_by_generation.png", by_group(full), group_legend)
draw_prereq(full, "N1 Full prerequisite network, arranged by year level",
            "02_full_network_by_year.png", by_group(full), group_legend, key="year")
draw_prereq(NETWORKS["N3_cosc_only"], "N3 COSC-only prerequisite network",
            "03_cosc_only_network.png", by_group(full), group_legend[:1], figsize=(18, 10))

for name, label in [("N4_bsc", "BSc"), ("N5_ba", "BA")]:
    H = NETWORKS[name]
    draw_prereq(H, f"{name} {label} required courses + all their prerequisites",
                f"04_{label.lower()}_network.png",
                lambda n, H=H: BLUE if H.nodes[n]["required"] else GRAY,
                [("required", BLUE), ("prerequisite of a required course", GRAY)],
                figsize=(16, 10), drop_isolates=False)

MEM_COLOR = {"both": BLUE, "BSc only": ORANGE, "BA only": AQUA}
draw_prereq(union, "N6 BSc / BA union, coloured by which degree network the course is in (required or prerequisite)",
            "05_bsc_vs_ba_union.png", lambda n: MEM_COLOR[union.nodes[n]["membership"]],
            list(MEM_COLOR.items()), figsize=(18, 11), drop_isolates=False)

# Longest chain highlighted
lp = nx.dag_longest_path(full)
draw_prereq(full, f"Longest prerequisite chain highlighted ({len(lp) - 1} edges: {' -> '.join(lp)})",
            "06_longest_chain.png", lambda n: BLUE if n in lp else GRAY,
            [("on longest chain", BLUE), ("other", GRAY)],
            highlight_edges=list(zip(lp, lp[1:])))

# Fail-rate sized network
draw_prereq(W, "N7 Grade-weighted network: node size = fail rate, colour = has grade data",
            "07_grade_weighted_network.png",
            lambda n: BLUE if W.nodes[n]["has_grades"] else GRAY,
            [("has PAIR grade data", BLUE), ("no grade data (size = median)", GRAY)],
            size_fn=lambda n: 150 + 90 * W.nodes[n]["fail_rate_filled"])

# Degree distributions
fig, axes = plt.subplots(1, 2, figsize=(11, 4), sharey=True)
for ax, (lab, deg) in zip(axes, [("in-degree", metrics["in_degree"]), ("out-degree", metrics["out_degree"])]):
    vals = [v for n, v in deg.items() if full.degree(n) > 0]
    ax.hist(vals, bins=range(0, max(vals) + 2), color=BLUE, edgecolor=SURFACE, linewidth=2, align="left")
    ax.set_title(f"N1 {lab} distribution", loc="left")
    ax.set_xlabel(lab)
axes[0].set_ylabel("number of courses")
save(fig, "08_degree_distributions.png")


def top_bar(ax, values, title, n=15, color=BLUE, fmt="{:.0f}"):
    items = sorted(values.items(), key=lambda kv: kv[1], reverse=True)[:n][::-1]
    labels, vals = zip(*items)
    bars = ax.barh(labels, vals, color=color, height=0.7)
    ax.set_title(title, loc="left")
    ax.grid(axis="y", visible=False)
    for b, v in zip(bars, vals):
        ax.text(b.get_width(), b.get_y() + b.get_height() / 2, " " + fmt.format(v),
                va="center", fontsize=8, color=INK2)
    ax.tick_params(axis="y", labelsize=8)


# Q1 centrality panels
panels = [("in_degree", "in-degree", "{:.0f}"), ("out_degree", "out-degree", "{:.0f}"),
          ("betweenness", "betweenness", "{:.3f}"), ("closeness_in", "closeness (incoming)", "{:.3f}"),
          ("closeness_out", "closeness (outgoing, on reversed graph)", "{:.3f}"),
          ("descendants", "downstream courses (descendants)", "{:.0f}")]
fig, axes = plt.subplots(2, 3, figsize=(17, 10))
for ax, (k, t, fmt) in zip(axes.flat, panels):
    top_bar(ax, metrics[k], f"Top 15 by {t}", fmt=fmt)
fig.suptitle("N1 centrality measures (Q1)", x=0.01, ha="left", fontweight="bold")
fig.tight_layout()
save(fig, "09_centrality_top15.png")


# Spearman correlation between measures
def ranks(x):
    order = np.argsort(x)
    r = np.empty(len(x))
    r[order] = np.arange(len(x))
    # average ties
    for v in np.unique(x):
        idx = np.where(x == v)[0]
        r[idx] = r[idx].mean()
    return r


active = [n for n in full if full.degree(n) > 0]
corr_keys = ["in_degree", "out_degree", "betweenness", "closeness_in", "closeness_out",
             "descendants", "ancestors", "blocked_or", "pagerank_rev", "katz_rev"]
X = np.array([[metrics[k][n] for n in active] for k in corr_keys], dtype=float)
Rk = np.array([ranks(row) for row in X])
C = np.corrcoef(Rk)
from matplotlib.colors import LinearSegmentedColormap
div = LinearSegmentedColormap.from_list("div", [DIV_NEG, "#f1efe9", DIV_POS])
fig, ax = plt.subplots(figsize=(8.5, 7))
ax.grid(False)
im = ax.imshow(C, cmap=div, vmin=-1, vmax=1)
ax.set_xticks(range(len(corr_keys)), corr_keys, rotation=45, ha="right")
ax.set_yticks(range(len(corr_keys)), corr_keys)
for i in range(len(corr_keys)):
    for j in range(len(corr_keys)):
        ax.text(j, i, f"{C[i, j]:.2f}", ha="center", va="center", fontsize=7.5, color=INK)
fig.colorbar(im, ax=ax, shrink=0.8, label="Spearman rank correlation")
ax.set_title("Rank correlation between node measures (N1, non-isolated courses)", loc="left")
save(fig, "10_measure_correlation.png")

# Q2 removal impact
fig, axes = plt.subplots(1, 2, figsize=(14, 6))
top_bar(axes[0], metrics["descendants"], "Courses blocked if removed - AND reading\n(every downstream course)")
top_bar(axes[1], metrics["blocked_or"], "Courses blocked if removed - OR reading\n(no alternative path left; dominator tree)",
        color=ORANGE)
fig.suptitle("Node removal impact (Q2)", x=0.01, ha="left", fontweight="bold")
fig.tight_layout()
save(fig, "11_removal_impact.png")

# Scatter: centrality vs removal impact
fig, axes = plt.subplots(1, 3, figsize=(16, 5), sharey=True)
for ax, k in zip(axes, ["betweenness", "out_degree", "closeness_out"]):
    xs = [metrics[k][n] for n in active]
    ys = [metrics["descendants"][n] for n in active]
    ax.scatter(xs, ys, s=60, color=BLUE, edgecolors=SURFACE, linewidths=1.5, alpha=0.9)
    for n in sorted(active, key=lambda n: metrics["descendants"][n], reverse=True)[:6]:
        ax.annotate(n, (metrics[k][n], metrics["descendants"][n]), fontsize=8, color=INK2,
                    xytext=(4, 2), textcoords="offset points")
    ax.set_xlabel(k)
axes[0].set_ylabel("downstream courses (removal impact, AND)")
fig.suptitle("Centrality vs removal impact (Q2)", x=0.01, ha="left", fontweight="bold")
save(fig, "12_centrality_vs_removal.png")

# Q3 chain structure
fig, axes = plt.subplots(1, 2, figsize=(13, 4.5))
gen_counts = defaultdict(int)
for n in active:
    gen_counts[generation[n]] += 1
axes[0].bar(list(gen_counts), list(gen_counts.values()), color=BLUE, width=0.7)
axes[0].set_title("Courses per topological generation (N1)", loc="left")
axes[0].set_xlabel("generation (0 = no prerequisites)")
axes[0].set_ylabel("courses")
dep = [depth[n] for n in active]
axes[1].hist(dep, bins=range(0, max(dep) + 2), color=BLUE, edgecolor=SURFACE, linewidth=2, align="left")
axes[1].set_title("Longest prerequisite chain ending at each course", loc="left")
axes[1].set_xlabel("chain length (edges)")
save(fig, "13_chain_structure.png")

# Q3/Q5 chain depth by degree
fig, ax = plt.subplots(figsize=(9, 4.5))
width = 0.38
for off, (lab, name, col) in zip([-width / 2, width / 2], [("BSc", "N4_bsc", BLUE), ("BA", "N5_ba", ORANGE)]):
    H = NETWORKS[name]
    d = {}
    for n in nx.topological_sort(H):
        ps = list(H.predecessors(n))
        d[n] = 1 + max(d[p] for p in ps) if ps else 0
    cnt = defaultdict(int)
    for n in H:
        cnt[d[n]] += 1
    xs = sorted(cnt)
    ax.bar([x + off for x in xs], [cnt[x] for x in xs], width=width - 0.03, color=col, label=lab)
ax.set_xlabel("longest chain ending at course (edges)")
ax.set_ylabel("courses")
ax.legend(frameon=False)
ax.set_title("Chain depth of courses in the BSc vs BA networks", loc="left")
save(fig, "14_chain_depth_bsc_vs_ba.png")


# Q4 sensitivity: edge removal and node removal effects on reachability
def reachable_pairs(H):
    return sum(len(nx.descendants(H, n)) for n in H)


base_pairs = reachable_pairs(full)
base_lp = nx.dag_longest_path_length(full)
edge_effect = {}
for u, v in list(full.edges):
    H = full.copy()
    H.remove_edge(u, v)
    edge_effect[f"{u} -> {v}"] = base_pairs - reachable_pairs(H)
node_lp = {}
for n in active:
    H = full.copy()
    H.remove_node(n)
    node_lp[n] = base_lp - nx.dag_longest_path_length(H)
fig, axes = plt.subplots(1, 2, figsize=(16, 6.5))
top_bar(axes[0], edge_effect, f"Drop in reachable (prereq, course) pairs\nwhen one edge is removed (baseline {base_pairs})", n=20)
top_bar(axes[1], node_lp, f"Drop in longest chain length when a course is removed\n(baseline {base_lp} edges)",
        n=15, color=ORANGE)
fig.suptitle("Sensitivity to single removals (Q4)", x=0.01, ha="left", fontweight="bold")
fig.tight_layout()
save(fig, "15_sensitivity_removals.png")

# Q4 offering data
graded = [n for n in full if "terms_offered" in full.nodes[n]]
fig, ax = plt.subplots(figsize=(10, 6))
pat_color = {"Winter + Summer": BLUE, "Winter only": ORANGE, "Summer only": AQUA}
for pat, col in pat_color.items():
    ns = [n for n in graded if
          {"Winter + Summer": full.nodes[n]["offered_winter"] and full.nodes[n]["offered_summer"],
           "Winter only": full.nodes[n]["offered_winter"] and not full.nodes[n]["offered_summer"],
           "Summer only": full.nodes[n]["offered_summer"] and not full.nodes[n]["offered_winter"]}[pat]]
    if not ns:
        continue
    ax.scatter([full.nodes[n]["terms_offered"] for n in ns], [metrics["descendants"][n] for n in ns],
               s=[30 + 12 * full.nodes[n].get("fail_rate", 0) for n in ns], color=col,
               edgecolors=SURFACE, linewidths=1.5, label=pat, alpha=0.9)
for n in sorted((n for n in graded if n.startswith("COSC")), key=lambda n: metrics["descendants"][n], reverse=True)[:6]:
    ax.annotate(n, (full.nodes[n]["terms_offered"], metrics["descendants"][n]), fontsize=8,
                color=INK2, xytext=(5, 3), textcoords="offset points")
ax.set_xlabel("terms offered, 2021S-2025W (max 10)")
ax.set_ylabel("downstream courses")
ax.legend(frameon=False, title="offered in", loc="upper left")
ax.set_title("Offering frequency vs downstream courses (marker size = fail rate)", loc="left")
save(fig, "16_offering_vs_downstream.png")

# Q5 BSc vs BA metrics (small multiples, one scale per panel)
def summary(H):
    act = [n for n in H]
    return {
        "nodes": H.number_of_nodes(), "edges": H.number_of_edges(),
        "density": nx.density(H), "longest chain": nx.dag_longest_path_length(H),
        "generations": len(list(nx.topological_generations(H))),
        "% no prereqs": 100 * sum(H.in_degree(n) == 0 for n in act) / len(act),
        "required courses": sum(H.nodes[n]["required"] for n in H),
    }


sb, sa = summary(NETWORKS["N4_bsc"]), summary(NETWORKS["N5_ba"])
fig, axes = plt.subplots(1, len(sb), figsize=(17, 3.6))
for ax, k in zip(axes, sb):
    bars = ax.bar(["BSc", "BA"], [sb[k], sa[k]], color=[BLUE, ORANGE], width=0.6)
    ax.set_title(k, loc="left", fontsize=10)
    ax.grid(axis="x", visible=False)
    for b in bars:
        v = b.get_height()
        ax.text(b.get_x() + b.get_width() / 2, v, f"{v:.3f}" if k == "density" else f"{v:.0f}",
                ha="center", va="bottom", fontsize=8, color=INK2)
fig.suptitle("BSc vs BA network summary (Q5)", x=0.01, ha="left", fontweight="bold", y=1.04)
fig.tight_layout()
save(fig, "17_bsc_vs_ba_summary.png")

# Q5 top courses side by side
fig, axes = plt.subplots(1, 2, figsize=(13, 6))
for ax, (lab, name, col) in zip(axes, [("BSc", "N4_bsc", BLUE), ("BA", "N5_ba", ORANGE)]):
    H = NETWORKS[name]
    top_bar(ax, {n: len(nx.descendants(H, n)) for n in H}, f"{lab}: top 15 by downstream courses", color=col)
fig.tight_layout()
save(fig, "18_bsc_vs_ba_top_downstream.png")

# Q6 grade data on required courses
req_rows = sorted([r for r in required if num(r["Fail Rate %"]) is not None], key=lambda r: num(r["Fail Rate %"]))
fig, axes = plt.subplots(1, 2, figsize=(14, 10), sharey=True)
labels = [r["Course Code"] for r in req_rows]
cols = [BLUE if r["Course Code"].startswith("COSC") else GRAY for r in req_rows]
axes[0].barh(labels, [num(r["Fail Rate %"]) for r in req_rows], color=cols, height=0.7)
axes[0].set_title("Fail rate % (required courses)", loc="left")
axes[1].barh(labels, [num(r["Avg Grade"]) for r in req_rows], color=cols, height=0.7)
axes[1].set_xlim(60, 90)
axes[1].set_title("Average grade (axis starts at 60)", loc="left")
for ax in axes:
    ax.grid(axis="y", visible=False)
    ax.tick_params(axis="y", labelsize=8)
axes[0].legend(handles=[Line2D([], [], marker="s", ls="", color=BLUE, label="COSC"),
                        Line2D([], [], marker="s", ls="", color=GRAY, label="other subject")],
               frameon=False, loc="lower right")
save(fig, "19_required_fail_rate_avg_grade.png")


# Q6 unweighted vs fail-weighted rank comparison (slope charts)
def rank_of(d, ns):
    order = sorted(ns, key=lambda n: d[n], reverse=True)
    return {n: i + 1 for i, n in enumerate(order)}


fig, axes = plt.subplots(1, 2, figsize=(13, 8))
for ax, (a, b, t) in zip(axes, [("pagerank_rev", "pagerank_rev_failw", "PageRank"),
                                ("katz_rev", "katz_rev_failw", "Katz")]):
    ra, rb = rank_of(metrics[a], active), rank_of(metrics[b], active)
    show = sorted({n for n in active if ra[n] <= 15 or rb[n] <= 15}, key=lambda n: ra[n])
    ax.grid(False)
    for n in show:
        moved = ra[n] != rb[n]
        ax.plot([0, 1], [ra[n], rb[n]], color=BLUE if moved else GRAY, lw=2, marker="o", markersize=8)
        ax.text(-0.04, ra[n], f"{n} ({ra[n]})", ha="right", va="center", fontsize=8, color=INK2)
        ax.text(1.04, rb[n], f"({rb[n]}) {n}", ha="left", va="center", fontsize=8, color=INK2)
    ax.set_xlim(-0.5, 1.5)
    ax.invert_yaxis()
    ax.set_xticks([0, 1], ["unweighted", "fail-rate weighted"])
    ax.set_yticks([])
    ax.spines["left"].set_visible(False)
    ax.set_title(f"{t} rank on reversed graph\n(courses in top 15 of either)", loc="left")
fig.tight_layout()
save(fig, "20_weighted_vs_unweighted_rank.png")

# Fail rate over terms for required COSC courses (small multiples)
TERMS = sorted({r["Term"] for r in sections})
req_cosc = sorted(c for c in BSC | BA if c.startswith("COSC") and c in by_course)
fig, axes = plt.subplots(math.ceil(len(req_cosc) / 4), 4, figsize=(16, 2.6 * math.ceil(len(req_cosc) / 4)),
                         sharex=True, sharey=True)
for ax, c in zip(axes.flat, req_cosc):
    xs, ys = [], []
    for i, t in enumerate(TERMS):
        rows = [r for r in sections if r["Course Code"] == c and r["Term"] == t]
        reported = sum(num(r["Reported"]) or 0 for r in rows)
        failed = sum(num(r["<50"]) or 0 for r in rows)
        if reported:
            xs.append(i)
            ys.append(100 * failed / reported)
    ax.plot(xs, ys, color=BLUE, lw=2, marker="o", markersize=5)
    ax.set_title(c, loc="left", fontsize=10)
for ax in axes.flat[len(req_cosc):]:
    ax.set_visible(False)
for ax in axes[-1]:
    ax.set_xticks(range(len(TERMS)), TERMS, rotation=60, fontsize=7)
fig.supylabel("fail rate % (hidden <6 counts treated as 0)", color=INK2)
fig.suptitle("Fail rate by term, required COSC courses", x=0.01, ha="left", fontweight="bold")
fig.tight_layout()
save(fig, "21_fail_rate_by_term.png")

# Grade distribution heatmap
order = sorted(codes, key=lambda c: (level(c), c))
fig, ax = plt.subplots(figsize=(9, 0.28 * len(order) + 1.5))
ax.grid(False)
seq = LinearSegmentedColormap.from_list("seq", SEQ)
im = ax.imshow(np.array([hist[c] for c in order]), cmap=seq, aspect="auto")
ax.set_xticks(range(len(BINS)), BINS, rotation=45)
ax.set_yticks(range(len(order)), order, fontsize=8)
fig.colorbar(im, ax=ax, label="share of students")
ax.set_title("Grade distribution per COSC course (all terms pooled)", loc="left")
save(fig, "22_grade_distribution_heatmap.png")


# Grade-data networks
def spring_draw(H, fname, title, color_fn, legend, width_attr=None, label_fn=None, size_fn=None, seed=7):
    isolates = [n for n in H if H.degree(n) == 0]
    H = H.subgraph([n for n in H if H.degree(n) > 0])
    if isolates:
        title += f"\n(not drawn, no links: {', '.join(sorted(isolates))})"
    pos = nx.spring_layout(H, seed=seed, k=1.2 / math.sqrt(max(H.number_of_nodes(), 1)))
    fig, ax = plt.subplots(figsize=(16, 12))
    ax.axis("off")
    widths = [0.5 + 0.8 * d.get(width_attr, 1) for *_, d in H.edges(data=True)] if width_attr else 0.8
    nx.draw_networkx_edges(H, pos, ax=ax, edge_color=GRAY, width=widths, alpha=0.8)
    nx.draw_networkx_nodes(H, pos, ax=ax, node_color=[color_fn(n) for n in H],
                           node_size=[size_fn(n) for n in H] if size_fn else 300,
                           edgecolors=SURFACE, linewidths=1.5)
    labels = {n: label_fn(n) for n in H} if label_fn else {n: n for n in H}
    nx.draw_networkx_labels(H, pos, ax=ax, labels=labels, font_size=6.5, font_color=INK)
    ax.legend(handles=[Line2D([], [], marker="o", ls="", color=c, markersize=10, label=l) for l, c in legend],
              frameon=False, loc="upper left")
    ax.set_title(title, loc="left")
    save(fig, fname)


spring_draw(B, "23_prof_course_bipartite.png",
            "N9 Instructor-course bipartite network (COSC sections, 2021S-2025W)\nedge width = sections taught",
            lambda n: BLUE if B.nodes[n]["bipartite"] == "course" else ORANGE,
            [("course", BLUE), ("instructor", ORANGE)], width_attr="sections",
            label_fn=lambda n: n if B.nodes[n]["bipartite"] == "course" else n.split()[-1],
            size_fn=lambda n: 320 if B.nodes[n]["bipartite"] == "course" else 120)
spring_draw(P, "24_shared_instructor_network.png",
            "N10 Course-course network: edge = shared instructor (width = number shared)\nsize = fail rate",
            lambda n: BLUE if n in BSC | BA else GRAY, [("required (BSc or BA)", BLUE), ("elective / other", GRAY)],
            width_attr="shared_instructors", size_fn=lambda n: 80 + 25 * P.nodes[n].get("fail_rate", 0))
spring_draw(Gs, "25_grade_similarity_network.png",
            f"N11 Grade-distribution similarity network (each course linked to its {K} most similar)\nsize = fail rate",
            lambda n: {2: ORANGE, 3: AQUA}.get(level(n), BLUE) if level(n) in (1, 2, 3) else GRAY,
            [("100-level", BLUE), ("200-level", ORANGE), ("300-level", AQUA), ("400-level and grad (5xx)", GRAY)],
            size_fn=lambda n: 80 + 30 * Gs.nodes[n].get("fail_rate", 0))

# Basic stats per network for the report
with open(NET_DIR / "network_summary.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["network", "directed", "nodes", "edges", "density", "components", "is_dag", "longest_path"])
    for name, H in NETWORKS.items():
        comps = (nx.number_weakly_connected_components(H) if H.is_directed()
                 else nx.number_connected_components(H))
        dag = H.is_directed() and nx.is_directed_acyclic_graph(H)
        w.writerow([name, H.is_directed(), H.number_of_nodes(), H.number_of_edges(),
                    f"{nx.density(H):.4f}", comps, dag, nx.dag_longest_path_length(H) if dag else ""])

print("DAG:", DAG, "| longest path:", lp)
print("removed variants:", top_removed)
print("figures:", len(list(FIG_DIR.glob('*.png'))), "| networks:", len(NETWORKS))
