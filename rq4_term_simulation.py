"""RQ4: how many extra terms does a missed course add to graduation?

Reads prereq_groups.csv, coreq_groups.csv, degree_requirements.csv and
course_offerings.csv, simulates a student moving through the degree term by
term, and writes output/rq4_term_delay.csv.
Descriptive only: no conclusions are drawn here.

Run from the project root:  venv/bin/python rq4_term_simulation.py
"""

import csv
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output" / "rq4_term_delay.csv"

SPECIAL = {"HS_ENTRY"}                      # always satisfied
STANDING = {"STANDING_3": 3, "STANDING_4": 4}  # met from that academic year
UNAVAILABLE = {"COSC 223", "COSC 413", "COSC 417"}  # no sections found 2021-22 to 2025-26
TERMS = ["T1", "T2", "S"]                   # Winter Term 1, Winter Term 2, Summer
LOADS = {"5 courses": 15, "6 courses": 18}  # credits per term (usual load, university maximum)
CREDITS_TO_GRADUATE = 120
KEY_COURSES = ["COSC 111", "COSC 121", "COSC 122", "COSC 123", "COSC 211", "COSC 221",
               "COSC 222", "COSC 304", "COSC 310", "COSC 320", "COSC 341"]


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def read_logic(path):
    """course -> list of routes; route -> list of groups; group -> set of members."""
    tree = defaultdict(lambda: defaultdict(lambda: defaultdict(set)))
    for r in read_csv(path):
        tree[r["course"]][r["route"]][r["group"]].add(r["member"])
    return {c: [list(groups.values()) for groups in routes.values()] for c, routes in tree.items()}


PREREQ = read_logic(ROOT / "prereq_groups.csv")
COREQ = read_logic(ROOT / "coreq_groups.csv")
REQS = read_csv(ROOT / "degree_requirements.csv")

OFFERINGS = defaultdict(dict)               # pattern -> course -> set of terms
for r in read_csv(ROOT / "course_offerings.csv"):
    OFFERINGS[r["pattern"]][r["course"]] = set(r["terms_offered"].split())


def satisfied(routes, done):
    if not routes:
        return True
    return any(all(any(m in SPECIAL or m in done for m in group) for group in route) for route in routes)


def core(program):
    """Requirements (mandatory and choice rows) as lists of options; BSc English left out."""
    return [r["options"].split("|") for r in REQS
            if r["program"] == program and r["kind"] in ("mandatory", "choice")
            and not r["req_id"].startswith("BSC03")]


def credits(course):
    return 6 if course == "COSC 499" else 3


def needed_courses(program):
    """Core options plus everything that can lead to them."""
    need = {o for opts in core(program) for o in opts}
    stack = list(need)
    while stack:
        c = stack.pop()
        for logic in (PREREQ, COREQ):
            for route in logic.get(c, []):
                for group in route:
                    for m in group:
                        if m not in SPECIAL and m not in STANDING and m not in need and m not in UNAVAILABLE:
                            need.add(m)
                            stack.append(m)
    return need


def chain_depth(need):
    """Longest chain of needed courses that depends on each course (used as priority)."""
    unlocks = defaultdict(set)
    for c in need:
        for logic in (PREREQ, COREQ):
            for route in logic.get(c, []):
                for group in route:
                    for m in group:
                        if m in need:
                            unlocks[m].add(c)
    memo = {}

    def depth(c):
        if c not in memo:
            memo[c] = 0
            memo[c] = max((depth(u) + 1 for u in unlocks[c]), default=0)
        return memo[c]
    return {c: depth(c) for c in need}


def terms_to_graduate(program, pattern, summer, load, missed=None):
    """Number of terms attended until the degree is complete.
    Winter terms are always attended; Summer only if `summer` and a degree course is taken.
    `missed`: the course the student fails (or cannot enrol in) on its first attempt."""
    offered = OFFERINGS[pattern] if pattern else {}
    need = needed_courses(program)
    depth = chain_depth(need)
    done, total_credits, attended, first_miss = set(), 0, 0, None
    for t in range(60):
        term, year = TERMS[t % 3], t // 3 + 1
        if term == "S" and not summer:
            continue
        for name, y in STANDING.items():
            if year >= y:
                done.add(name)
        before, taken, used = set(done), [], 0
        while True:
            options = []
            for c in need:
                if c in done or c in UNAVAILABLE:
                    continue
                if c in offered and term not in offered[c]:
                    continue
                if not satisfied(PREREQ.get(c), before) or not satisfied(COREQ.get(c), before | done):
                    continue
                if c == missed and first_miss in (None, t):
                    first_miss = t
                    continue
                if used + credits(c) <= load:
                    options.append(c)
            if not options:
                break
            c = min(options, key=lambda x: (-depth[x], x))
            done.add(c)
            taken.append(c)
            used += credits(c)
            total_credits += credits(c)
        if term != "S":
            total_credits += load - used          # elective credit fills the rest of a Winter term
        if taken or term != "S":
            attended += 1
        if all(any(o in done for o in opts) for opts in core(program)) and total_credits >= CREDITS_TO_GRADUATE:
            return attended
    return None


rows = []
for pattern in ("2025-26", "2022-23"):
    for summer in (False, True):
        for load_name, load in LOADS.items():
            for program in ("BSc", "BA"):
                base = terms_to_graduate(program, pattern, summer, load)
                for course in KEY_COURSES:
                    extra = terms_to_graduate(program, pattern, summer, load, missed=course) - base
                    rows.append({"pattern": pattern, "summer": "yes" if summer else "no", "load": load_name,
                                 "program": program, "terms_to_graduate": base,
                                 "missed_course": course, "extra_terms": extra})

OUT.parent.mkdir(parents=True, exist_ok=True)
with open(OUT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)

# short summary: only courses with a delay
for pattern in ("2025-26", "2022-23"):
    for summer in ("no", "yes"):
        for load_name in LOADS:
            for program in ("BSc", "BA"):
                sel = [r for r in rows if (r["pattern"], r["summer"], r["load"], r["program"]) == (pattern, summer, load_name, program)]
                delays = ", ".join(f"{r['missed_course']} +{r['extra_terms']}" for r in sel if r["extra_terms"])
                print(f"{pattern} | Summer {summer} | {load_name} | {program}: graduate in {sel[0]['terms_to_graduate']} terms | {delays or 'no delay'}")
