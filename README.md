# Bottlenecks and Critical Paths in the UBCO Computer Science Degree

*A prerequisite network analysis for COSC 421 (Network Science), UBC Okanagan*

We model the UBCO Computer Science degree as a **directed network**. Each **node** is a course, and each **edge** points from a prerequisite to the course it unlocks (e.g. `COSC 121 → COSC 222`).

Rather than finding one shortest path to graduation, we study how the structure of the network affects a student's progress: which courses unlock the most of the degree, where students can get held back, and what happens when a key course is removed or delayed.

The project combines three data sources in one network:
- **Prerequisites and degree requirements** from the UBCO Academic Calendar
- **How often each course is offered** (every term vs. once a year)
- **Historical grades and fail rates** from UBC PAIR (2021S–2025W)

## Key findings so far

- **Standard centrality measures and real bottlenecks disagree.** Counting every course reachable by arrows (left) puts first-year MATH courses on top, but each of them is only one of several ways into COSC 111. Reading the AND/OR prerequisite rules (right) gives a different ranking.
- **COSC 121 is the biggest bottleneck.** Without it, 19 courses can no longer be taken and 5 BSc requirements can't be met, because it is the only route into COSC 211 and COSC 222. COSC 222 (15 courses) and COSC 221 (9) come next.
- **COSC 111 delays but doesn't block.** It has the highest betweenness, but removing it blocks no courses. It delays 12, because students can reach COSC 121 through COSC 122 → COSC 123 instead.
- **Prerequisite chains are short.** Taking the shortest option at each step, the longest forced chain is 4 levels (MATH 100 → MATH 101 → COSC 221 → COSC 315 → COSC 417), and every required course can be reached within 3.
- **BSc and BA share their bottlenecks.** 10 of the 12 BA core courses are also BSc requirements, and COSC 121 breaks the most requirements in both degrees.
- **Weighting by fail rate changes rankings only slightly** (Spearman 0.99 for PageRank, 0.96 for Katz). These results are preliminary.

## Research questions

1. **Central courses:** Which courses are most important, by in/out-degree, betweenness and closeness centrality, and number of downstream courses?
2. **Bottlenecks:** Which courses hold up the most of the degree when they are removed or delayed?
3. **Prerequisite chains:** How long are the longest chains, and how much of the degree can be taken without prerequisites?
4. **Sensitivity:** How does the network change when prerequisites or courses are added, removed or delayed?
5. **BSc vs. BA:** How similar are the two degrees' prerequisite networks?
6. **Course difficulty:** Does weighting courses by historical fail rate (with PageRank or Katz centrality) change which courses count as bottlenecks?

## Repository layout

| Path | What it is |
|---|---|
| `scrape_courses.py` | Scrapes the UBCO calendar's COSC course page into `output/courses.csv` |
| `prereq_groups.csv`, `coreq_groups.csv` | Prerequisite and corequisite rules with AND/OR logic, one row per option (the network is built from these) |
| `prereq_groups_readable.txt` | The same rules as plain-English formulas, next to the calendar text, for checking |
| `degree_requirements.csv` | BSc and BA requirements: mandatory courses, choices and elective pools |
| `network_nodes.csv` | Every course in the network, with its role and whether it has grade data |
| `UBC Pair Grade Data/` | Grade data script and the three combined grade files |
| `build_networks.py` | Builds all networks, computes the measures and draws the figures |
| `output/networks/` | Networks (`.graphml` and edge lists), `node_metrics_full.csv` and `network_summary.csv` |
| `output/figures/` | 26 figures used in the report |
| `README_data_files.md` | Detailed guide to the prerequisite and degree data files |
| `REVIEW_CHECKLIST.md` | What still needs checking against the calendar, and modelling decisions to confirm |

## How to run

Requires Python 3.10+.

**1. Set up a virtual environment**

macOS / Linux:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Windows (PowerShell):
```powershell
py -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
```
In Command Prompt (cmd), activate with `venv\Scripts\activate.bat` instead.

**2. Build the networks and figures**
```bash
python build_networks.py
```
This reads the data files above and writes everything to `output/networks/` and `output/figures/` (about 15 seconds).

**3. (Optional) Re-scrape the calendar**
```bash
python scrape_courses.py              # scrape COSC, write output/courses.csv, edges.csv and GraphML
python scrape_courses.py --plot       # also save a PNG of the graph
python scrape_courses.py --no-external  # drop non-COSC prereqs (MATH, STAT, ...)
python scrape_courses.py --url <subject page> --out <dir>
```
The scraper's `edges.csv` treats every "one of" option as required, so it is kept for reference only. The analysis uses the hand-checked AND/OR rules in `prereq_groups.csv`.

## Data

### Prerequisites and degree requirements
Prerequisites were scraped from the [UBCO calendar](https://okanagan.calendar.ubc.ca/course-descriptions/subject/cosco) for 79 COSC courses and then rewritten as AND/OR rules for 66 courses across COSC, MATH, STAT, DATA, PHYS, APSC, ENGL, CORH and PHIL. In `prereq_groups.csv`:
- courses in the same **group** are alternatives (OR)
- every group in a **route** must be satisfied (AND)
- different **routes** are alternative ways into a course (only COSC 111, 304 and 413 have two)

The full network has **92 courses, 160 prerequisite links and 13 corequisite links**, with no cycles. See `README_data_files.md` for the full format.

### Grade data (UBC PAIR)
Historical grades come from the public [ubc-pair-grade-data](https://github.com/DonneyF/ubc-pair-grade-data) repository, which collects grade distributions from UBC's PAIR grade dashboard. We used the `tableau-dashboard-v2/UBCO` folder, covering **2021 Summer (2021S) to 2025 Winter (2025W)**. The repository stores one CSV per subject per term (e.g. `2024W/UBCO-2024W-COSC.csv`).

The script in `UBC Pair Grade Data/` (run with `python pair_grade_script.py PATH/TO/ubc-pair-grade-data`):
1. **Selects subjects:** loads only the subjects that contain a required BSc or BA course: COSC, MATH, STAT, DATA, PHIL, ENGL, INDG, CORH, APSC, PHYS, BIOL, CHEM and EESC.
2. **Combines files:** stacks every term's CSV into one table and adds `Term` (e.g. `2024W`) and `Course Code` (e.g. `COSC 111`) columns.
3. **Summarizes by course:** groups all sections and terms of a course into one row. The average grade is weighted by section size, and the fail rate is the share of students graded below 50%.
4. **Filters to required courses** and marks which degree each belongs to.
5. **Checks coverage:** prints any required course with no grade data.

| File | One row per | Use |
|---|---|---|
| `UBC Pair data - ubco_grades_all_sections.csv` | Section, per term (2,880 rows) | Raw combined data |
| `UBC Pair data - ubco_grades_by_course.csv` | Course (506 rows) | Grade lookup for any course in the network |
| `UBC Pair data - ubco_grades_required.csv.csv` | Required course (43 rows) | Grade summary for the required courses |

Key columns: `Avg Grade`, `Fail Rate %`, `Students`, `Students_With_Fail_Data`, and the offering columns `Terms_Offered`, `Offered_in_Winter`, `Offered_in_Summer`, `First_Term`, `Last_Term`.

## Outputs

**Networks** (`output/networks/`):

| Network | What it contains |
|---|---|
| N1 `full` | All 92 courses, prerequisite and corequisite links |
| N2 `prereq_only` | N1 without corequisites |
| N3 `cosc_only` | COSC courses only |
| N4 `bsc`, N5 `ba` | Core networks of each degree (20 and 12 courses) |
| N6 `bsc_ba_union` | N4 and N5 combined, labelled by degree |
| N7 `grade_weighted` | N1 with edges weighted by the prerequisite's fail rate |
| N8 `minus_COSC121/221/222` | N1 with one of the top bottleneck courses removed |
| N9–N11 | Networks built from grade data: instructor–course, shared instructors, and grade-distribution similarity |

**Measures per course** (`output/networks/node_metrics_full.csv`): in/out-degree, betweenness, closeness, downstream courses, PageRank and Katz centrality (plain and fail-rate weighted), plus these measures, which follow the AND/OR rules:

| Column | Meaning |
|---|---|
| `blocked_if_removed` | courses that can no longer be taken at all if this course did not exist (alternatives are respected) |
| `delayed_if_removed` | courses that are still possible without it, but only through a longer chain |
| `bsc_reqs_broken`, `ba_reqs_broken` | degree requirements that can no longer be met without this course |
| `min_levels` | fewest prerequisite levels needed before a course, taking the shortest alternative each time (0 = no prerequisites; corequisites do not count) |
| `descendants`, `longest_chain_to_node` | plain graph measures that follow every arrow; upper bounds that ignore alternatives |

**BSc and BA networks** (N4, N5) are the core networks defined in `REVIEW_CHECKLIST.md`: the mandatory and choice courses of each degree (BSc English choice left out) and the links between them.

## Modelling decisions and limitations

- **Historical plan:** the BSc requirements follow last year's plan, not the current calendar, because we only use historical data. COSC 210, COSC 270 and DATA 311 (new requirements in the current calendar) are left out.
- **Always satisfied:** high-school entry and year-standing requirements are treated as met. Minimum grades are not modelled.
- **Corequisites** decide whether a course can be taken, but don't add to chain length.
- **Hidden small counts:** UBC hides grade counts below 6 students, so some sections have no fail count and are left out of the fail rate.
- **Missing fail rates:** 17 of the 92 courses have no fail rate (not offered in 2021–2025, or counts hidden). They currently use the median fail rate (see `REVIEW_CHECKLIST.md`, decision 6).
- **Offering data** only distinguishes Winter and Summer sessions; courses never offered in 2021–2025 are assumed not to run.
- **Still being checked:** the prerequisite formulas are being reviewed against the calendar (see `REVIEW_CHECKLIST.md`). Any fix means re-running `build_networks.py`.

## Status

| Proposal timeline | Status |
|---|---|
| Weeks 1–2 (Oct 19–30): collect and clean data, build BSc and BA networks | Done |
| Weeks 3–4 (Nov 2–13): centrality, chains, bottlenecks, RQ4 simulations | Mostly done; term-offering delay estimates still to do |
| Weeks 5–6 (Nov 16–27): BSc vs. BA comparison, grade-weighted analysis | Started; results to be analysed |
| Weeks 7–8 (Nov 30–Dec 8): video presentation (Dec 3) and final report (Dec 8) | Not started |

## Team

Ashish Nayak, Ivan Medellin, Gamuchirai Mhere and Muhammad Aliyan

## Sources

- University of British Columbia. *Okanagan Academic Calendar: Computer Science (BSc and BA)*. Accessed October 2026.
- DonneyF. *ubc-pair-grade-data*. GitHub, https://github.com/DonneyF/ubc-pair-grade-data. Accessed October 2026.
