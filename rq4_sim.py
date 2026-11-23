"""RQ4 term-offering simulation (scratch copy; reads the repo CSVs, writes nothing there)."""
import csv, sys, itertools
from collections import defaultdict
from pathlib import Path
ROOT = Path(sys.argv[1])
SPECIAL = {"HS_ENTRY"}
STAND = {"STANDING_3","STANDING_4"}
def read_csv(p): return list(csv.DictReader(open(p, encoding="utf-8")))
def read_logic(p):
    t = defaultdict(lambda: defaultdict(lambda: defaultdict(set)))
    for r in read_csv(p): t[r["course"]][r["route"]][r["group"]].add(r["member"])
    return {c: [list(g.values()) for g in rs.values()] for c, rs in t.items()}
PRE, CO = read_logic(ROOT/"prereq_groups.csv"), read_logic(ROOT/"coreq_groups.csv")
REQ = read_csv(ROOT/"degree_requirements.csv")
def core(prog):
    return [(r["req_id"], r["options"].split("|")) for r in REQ if r["program"]==prog
            and r["kind"] in ("mandatory","choice") and not r["req_id"].startswith("BSC03")]
UNAVAIL = {"COSC 223","COSC 413","COSC 417"}
# offering: course -> set of terms offered among W1,W2,S ; unlisted courses = every term
Y = lambda *a: set(a)
REF = {  # 2025-26 (+ Summer 2025 from PAIR)
 "COSC 111":Y("W1","W2","S"),"COSC 121":Y("W1","W2","S"),"COSC 122":Y("W1"),"COSC 123":Y("W2"),
 "COSC 211":Y("W1"),"COSC 221":Y("W1","W2"),"COSC 222":Y("W1","W2","S"),"COSC 304":Y("W1","S"),
 "COSC 310":Y("W1","W2"),"COSC 315":Y("W2"),"COSC 320":Y("W2"),"COSC 341":Y("W1","W2"),"COSC 499":Y("W1","S")}
OLD = dict(REF)  # 2022-23 (winter terms from Workday; summer as reference)
OLD.update({"COSC 111":Y("W1","W2","S"),"COSC 121":Y("W2","S"),"COSC 122":Y("W1"),"COSC 123":Y("W2"),
 "COSC 211":Y("W2"),"COSC 221":Y("W1","W2"),"COSC 222":Y("W1","S"),"COSC 304":Y("W1","S"),
 "COSC 310":Y("W2"),"COSC 315":Y("W2"),"COSC 320":Y("W2"),"COSC 341":Y("W2"),"COSC 499":Y("W1","S")})
def sat(routes, done, now=None):
    if not routes: return True
    ok = lambda m: m in SPECIAL or m in done
    return any(all(any(ok(m) for m in g) for g in r) for r in routes)
def simulate(offer, cycle, skip=None, horizon=40):
    """Greedy earliest schedule, no course-load cap. skip=(course) -> first eligible attempt is failed/missed.
    Returns (finish term index per course dict, taken-term list)."""
    done, fin, missed = set(), {}, False
    skipped = {}
    allc = set(PRE)|set(CO)|{o for p in("BSc","BA") for _,opts in core(p) for o in opts}
    allc |= {m for rs in list(PRE.values())+list(CO.values()) for r in rs for g in r for m in g}
    for t in range(horizon):
        term = cycle[t % len(cycle)]
        year = sum(1 for u in range(t+1) if cycle[u % len(cycle)]=="W1")  # academic year number (1-based)
        for k,y in (("STANDING_3",3),("STANDING_4",4)):
            if year >= y: done.add(k)
        done_before = set(done)
        changed = True
        while changed:
            changed = False
            for c in sorted(allc):
                if c in done or c in UNAVAIL or c in SPECIAL or c in STAND: continue
                if c in offer and term not in offer[c]: continue
                if not sat(PRE.get(c), done_before): continue
                if not sat(CO.get(c), done_before|done): continue
                if c == skip:
                    if c not in skipped: skipped[c] = t
                    if skipped[c] == t: continue
                done.add(c); fin[c] = t; changed = True
    return fin
def finish(fin, prog):
    t = 0
    for rid, opts in core(prog):
        times = [fin[o] for o in opts if o in fin]
        if not times: return None
        t = max(t, min(times))
    return t
def years(n): return n
PATTERNS = {"2025-26": REF, "2022-23": OLD}
CYCLES = {"no Summer": ["W1","W2"], "with Summer": ["W1","W2","S"]}
CANDS = ["COSC 111","COSC 121","COSC 122","COSC 123","COSC 211","COSC 221","COSC 222","COSC 304","COSC 310","COSC 320","COSC 341"]
if __name__ == "__main__":
    for pname, pat in PATTERNS.items():
        for cname, cyc in CYCLES.items():
            ideal = simulate({}, cyc)
            print(f"\n=== offering {pname} | {cname} ===")
            for prog in ("BSc","BA"):
                ib, rb = finish(ideal, prog), finish(simulate(pat, cyc), prog)
                print(f"{prog}: min terms to finish core (ideal, all offered every term) = {ib+1}; with real offerings = {rb+1}  (+{rb-ib})")
            base = simulate(pat, cyc)
            for prog in ("BSc","BA"):
                print(f"--- {prog}: extra terms vs the same schedule if the course is missed/failed once")
                rows=[]
                for c in CANDS:
                    if not any(c in o for _,o in core(prog)) and c not in ("COSC 122",): pass
                    r = finish(simulate(pat, cyc, skip=c), prog); i = finish(simulate({}, cyc, skip=c), prog)
                    rows.append((c, r-finish(base,prog), i-finish(ideal,prog)))
                for c,e,ie in sorted(rows,key=lambda x:-x[1]):
                    print(f"  {c}: +{e} terms (real offerings)   +{ie} (if offered every term)")
