#!/usr/bin/env python3
"""
Scrape a UBC Okanagan calendar subject page, extract each course and its
prerequisites/corequisites, and build a directed graph (prereq -> course).

Usage:
    pip install requests beautifulsoup4 networkx matplotlib
    python scrape_courses.py
    python scrape_courses.py --url <other subject page> --plot --no-external
    python scrape_courses.py --out <dir>

Outputs (in output/ by default):
    courses.csv           one row per course, with raw prereq/coreq text
    edges.csv             source,target,relation
    prereq_graph.graphml  open in Gephi / Cytoscape / networkx
    prereq_graph.png      only with --plot
"""

import argparse
import csv
import re
from pathlib import Path

import networkx as nx
import requests
from bs4 import BeautifulSoup, Comment, Tag

DEFAULT_URL = "https://okanagan.calendar.ubc.ca/course-descriptions/subject/cosco"

# "COSC_O 101 (3) Digital Citizenship"  ->  subject, number, credits, title
HEADING_RE = re.compile(
    r"^\s*([A-Z]{2,5})(?:_[A-Z])?\s+(\d{3}[A-Z]?)\s*\(([^)]*)\)\s*(.*)$"
)

# Section labels that appear inside a course's description text
SECTION_RE = re.compile(r"\b(Prerequisite|Corequisite|Equivalency)s?:\s*")

# A full course code (optionally with the _O campus suffix, even with a stray
# space before the underscore), or a bare 3-digit number that may belong to a
# shorthand list like "MATH_O 100, 101, 103".
TOKEN_RE = re.compile(
    r"(?P<code>\b(?P<subj>[A-Z]{2,5})(?:\s*_\s*[A-Z])?\s+(?P<num>\d{3}[A-Z]?)\b)"
    r"|(?P<bare>\b\d{3}[A-Z]?\b)"
)
LIST_GAP_RE = re.compile(r"\s*(,|,?\s*and|,?\s*or|/)\s*")


def extract_codes(text):
    """Return normalized course codes ('COSC 111') found in text, in order, deduped."""
    codes = []
    last_subj = None
    last_end = None
    for m in TOKEN_RE.finditer(text):
        if m.group("code"):
            last_subj = m.group("subj")
            codes.append(f"{last_subj} {m.group('num')}")
            last_end = m.end()
        else:
            gap = text[last_end:m.start()] if last_end is not None else None
            if last_subj and gap is not None and LIST_GAP_RE.fullmatch(gap):
                codes.append(f"{last_subj} {m.group('bare')}")
                last_end = m.end()
            else:
                last_subj = None
    seen = set()
    return [c for c in codes if not (c in seen or seen.add(c))]


def split_sections(body):
    """Split a course body into description, prerequisite text, corequisite text."""
    body = " ".join(body.split())
    labels = list(SECTION_RE.finditer(body))
    description = body[: labels[0].start()].strip() if labels else body
    out = {"prereq": "", "coreq": ""}
    for i, m in enumerate(labels):
        end = labels[i + 1].start() if i + 1 < len(labels) else len(body)
        chunk = body[m.end():end].strip()
        key = {"Prerequisite": "prereq", "Corequisite": "coreq"}.get(m.group(1))
        if key:
            out[key] = f"{out[key]} {chunk}".strip()
    return description, out["prereq"], out["coreq"]


def fetch_courses(url):
    resp = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=30)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    root = soup.find("main") or soup.body or soup

    # Structure-agnostic walk: every course starts at an <h3> matching the
    # heading pattern; all text until the next such <h3> is its body.
    courses, current = [], None
    for node in root.descendants:
        if isinstance(node, Tag):
            if node.name == "h3":
                heading = " ".join(node.get_text(" ", strip=True).split())
                m = HEADING_RE.match(heading)
                if m:
                    current = {
                        "code": f"{m.group(1)} {m.group(2)}",
                        "credits": m.group(3),
                        "title": m.group(4),
                        "_body": [],
                    }
                    courses.append(current)
                else:
                    current = None
            elif node.name == "h2" and courses:
                current = None  # past the course list
            continue
        if current is None or isinstance(node, Comment):
            continue
        if node.find_parent(["h3", "script", "style"]):
            continue
        current["_body"].append(str(node))

    for c in courses:
        desc, prereq, coreq = split_sections(" ".join(c.pop("_body")))
        c["description"] = desc
        c["prereq_text"] = prereq
        c["coreq_text"] = coreq
    return courses


def level_of(code):
    return int(code.split()[1][0]) * 100


def build_graph(courses, include_external=True):
    G = nx.DiGraph()
    for c in courses:
        G.add_node(
            c["code"],
            title=c["title"],
            credits=c["credits"],
            level=level_of(c["code"]),
            external=False,
        )
    for c in courses:
        for relation, field in (("prereq", "prereq_text"), ("coreq", "coreq_text")):
            for dep in extract_codes(c[field]):
                if dep == c["code"]:
                    continue
                if dep not in G:
                    if not include_external:
                        continue
                    G.add_node(dep, title="", credits="", level=level_of(dep), external=True)
                G.add_edge(dep, c["code"], relation=relation)
    return G


def write_outputs(courses, G, out_dir):
    with open(out_dir / "courses.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["code", "title", "credits", "prereq_text", "coreq_text", "description"],
        )
        w.writeheader()
        w.writerows(courses)

    with open(out_dir / "edges.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["source", "target", "relation"])
        for u, v, d in G.edges(data=True):
            w.writerow([u, v, d["relation"]])

    nx.write_graphml(G, out_dir / "prereq_graph.graphml")


def plot_graph(G, path):
    import matplotlib.pyplot as plt

    pos = nx.multipartite_layout(G, subset_key="level", align="vertical")
    colors = ["#bbbbbb" if G.nodes[n]["external"] else "#4c8bf5" for n in G]
    styles = ["dashed" if d["relation"] == "coreq" else "solid" for _, _, d in G.edges(data=True)]
    plt.figure(figsize=(22, 14))
    nx.draw_networkx_nodes(G, pos, node_color=colors, node_size=220)
    nx.draw_networkx_edges(G, pos, style=styles, arrows=True, arrowsize=8, alpha=0.5)
    nx.draw_networkx_labels(G, pos, font_size=6)
    plt.axis("off")
    plt.tight_layout()
    plt.savefig(path, dpi=200)
    plt.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--no-external", action="store_true",
                    help="drop prerequisite courses from other subjects (MATH, STAT, ...)")
    ap.add_argument("--plot", action="store_true", help="also save a quick PNG")
    ap.add_argument("--out", type=Path, default=Path("output"), help="output directory")
    args = ap.parse_args()

    courses = fetch_courses(args.url)
    if not courses:
        raise SystemExit(
            "No courses found. The page structure may have changed; "
            "check that course headings are <h3> elements like 'COSC_O 101 (3) Title'."
        )

    G = build_graph(courses, include_external=not args.no_external)
    args.out.mkdir(parents=True, exist_ok=True)
    write_outputs(courses, G, args.out)
    if args.plot:
        plot_graph(G, args.out / "prereq_graph.png")

    with_prereq = sum(1 for c in courses if c["prereq_text"] or c["coreq_text"])
    print(f"{len(courses)} courses parsed, {with_prereq} with prereq/coreq text")
    print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")


if __name__ == "__main__":
    main()