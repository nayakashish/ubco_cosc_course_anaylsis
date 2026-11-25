# Bottlenecks and Critical Paths in the UBCO Computer Science Degree

*A prerequisite network analysis for COSC 421 (Network Science), UBC Okanagan*

We model the UBCO Computer Science degree as a **directed network**. Each **node** is a course, and each **edge** points from a prerequisite to the course it unlocks (e.g. `COSC 121 → COSC 222`).

Rather than finding one shortest path to graduation, we study how the structure of the network affects a student's progress: which courses unlock the most of the degree, where students can get held back, and what happens when a key course is removed or delayed.

The project combines three data sources in one network:
- **Prerequisites and degree requirements** from the UBCO Academic Calendar
- **How often each course is offered** (every term vs. once a year), from Workday
- **Historical grades and fail rates** from UBC PAIR (2021S–2025W)

A **bottleneck** here is a course whose removal, failure or delay blocks other courses, after accounting for alternative prerequisite routes.

## Key findings

- **Standard centrality measures and real bottlenecks disagree.** Measures that follow every arrow (downstream courses, out-degree, PageRank, Katz) put first-year MATH courses on top, but each of them is only one of several ways into COSC 111 and blocks almost nothing. Reading the AND/OR prerequisite rules gives a different ranking (Spearman ρ = 0.57 between courses blocked and betweenness, 0.40 with downstream courses).
- **COSC 121 is the biggest bottleneck.** Without it, 19 courses can no longer be taken and 5 BSc requirements can't be met, because it is the only route into COSC 211 and COSC 222. COSC 222 (15 courses), COSC 221 (9) and COSC 304 (7) come next.
- **COSC 111 delays but doesn't block.** It has the highest betweenness, but removing it blocks no courses. It delays 12, because students can reach COSC 121 through COSC 122 → COSC 123 instead.
- **A few links matter more than most courses.** Removing only the link COSC 121 → COSC 222 makes 16 courses impossible, while 112 of the 160 prerequisite links can be removed without blocking anything.
- **Prerequisite chains are short.** Taking the shortest option at each step, the longest forced chain is 4 levels (MATH 100 → MATH 101 → COSC 221 → COSC 315 → COSC 417), and every required course can be reached within 3.
- **Courses offered once a year cause the delays.** In a term-by-term simulation (2025-26 offerings, no Summer), a student graduates in 8 terms at 5 courses per term or 7 terms at 6. Missing COSC 304, which runs in only one Winter term, adds 1–2 terms. Missing COSC 121 adds none, because it runs every term. Under the 2022-23 offerings, COSC 310 and COSC 341 also caused delays.
- **BSc and BA share their bottlenecks.** 10 of the 12 BA core courses are also BSc requirements, and COSC 121 breaks the most requirements in both degrees.
- **Weighting by fail rate barely changes the rankings** (Spearman 0.99 for PageRank, 0.96 for Katz).

## Research questions

1. **Central courses:** Which courses are the most central, measured by in-degree, out-degree, betweenness centrality, closeness centrality and the number of downstream courses?
2. **Bottlenecks:** Which courses act as bottlenecks, and do the most central courses also have the largest effect when they are removed or delayed?
3. **Prerequisite chains:** How do prerequisite chains shape the order of the degree, in terms of the longest chains, the number of prerequisite levels, and how much of the degree can be taken independently?
4. **Sensitivity:** How sensitive is the network to changes such as removing a prerequisite, removing a highly connected course, or delaying a bottleneck course, and how many extra terms could a delay add to graduation?
5. **BSc vs. BA:** How similar are the BSc and BA Computer Science networks in size, chain length, central courses and bottlenecks?
6. **Course difficulty:** Does weighting courses by historical difficulty, using PageRank or Katz centrality, change which courses are identified as bottlenecks?

## Report

The final report (Springer format) presents the full methods and results for each research question, with a discussion and conclusion. Section and figure numbers below refer to it.

## Repository layout

| Path | What it is |
|---|---|
| `scrape_courses.py` | Scrapes the UBCO calendar's COSC course page into `output/courses.csv` |
| `prereq_groups.csv`, `coreq_groups.csv` | Prerequisite and corequisite rules with AND/OR logic, one row per option (the network is built from these) |
| `prereq_groups_readable.txt` | The same rules as plain-English formulas, next to the calendar text, for checking |
| `degree_requirements.csv` | BSc and BA requirements: mandatory courses, choices and elective pools |
| `network_nodes.csv` | Every course in the network, with its role and whether it has grade data |
| `course_offerings.csv` | Terms (T1, T2, Summer) in which each key COSC course ran, for the 2025-26 and 2022-23 patterns; COSC 223, 413 and 417 have no sections found |
| `UBC Pair Grade Data/` | `pair_grade_script.py` and the three combined grade files |
| `build_networks.py` | Builds all networks, computes the measures and draws figures 01–25 |
| `rq4_term_simulation.py`, `rq4_term_simulation.java` | RQ4 term-by-term simulation: terms to graduate and extra terms if one course is missed once (same rules and output in both) |
| `rq4_chart.py` | Draws `output/figures/26_rq4_term_delay.png` from the RQ4 results |
| `rq4_results.txt`, `output/rq4_term_delay.csv` | Summary and full results of the RQ4 simulation |
| `output/networks/` | Networks (`.graphml` and edge lists), `node_metrics_full.csv` and `network_summary.csv` |
| `output/figures/` | 27 figures used in the report |
| `README_data_files.md` | Detailed guide to the prerequisite and degree data files |
| `REVIEW_CHECKLIST.md` | Calendar checks and modelling decisions made during the project |

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

**3. Run the RQ4 term simulation and draw its chart**
```bash
python rq4_term_simulation.py       # or: java rq4_term_simulation.java
python rq4_chart.py                 # writes output/figures/26_rq4_term_delay.png
```
The simulation reads the CSV files in the project root and writes `output/rq4_term_delay.csv`; the chart is drawn from that file.

**4. (Optional) Re-scrape the calendar**
```bash
python scrape_courses.py              # scrape COSC, write output/courses.csv, edges.csv and GraphML
python scrape_courses.py --plot       # also save a PNG of the graph
python scrape_courses.py --no-external  # drop non-COSC prereqs (MATH, STAT, ...)
python scrape_courses.py --url <subject page> --out <dir>
```
The scraper's `edges.csv` treats every "one of" option as required, so it is kept for reference only. The analysis uses the hand-checked AND/OR rules in `prereq_groups.csv`.

## Data

All data was collected in October 2026.

### Prerequisites and degree requirements
Prerequisites were scraped from the [UBCO calendar](https://okanagan.calendar.ubc.ca/course-descriptions/subject/cosco) for 79 COSC courses and then rewritten as AND/OR rules for 66 courses across COSC, MATH, STAT, DATA, PHYS, APSC, ENGL, CORH and PHIL. In `prereq_groups.csv`:
- courses in the same **group** are alternatives (OR)
- every group in a **route** must be satisfied (AND)
- different **routes** are alternative ways into a course (only COSC 111, 304 and 413 have two)

The rules were checked manually against the calendar. The full network has **92 courses, 160 prerequisite links and 13 corequisite links**, with no cycles. See `README_data_files.md` for the full format.

### Course offerings (Workday)
We used Workday to verify upper-year prerequisites and to record in which terms (Winter Term 1, Winter Term 2, Summer) 16 key COSC courses ran from 2021-22 to 2025-26, with Summer offerings taken from the PAIR data. 7 of the 16 courses moved term at least once. `course_offerings.csv` stores the two patterns used in RQ4: 2025-26 and the more restrictive 2022-23.

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

**Measures per course** (`output/networks/node_metrics_full.csv`): in/out-degree, betweenness, closeness, downstream courses, PageRank and Katz centrality (plain and fail-rate weighted, computed on the reversed network), plus these measures, which follow the AND/OR rules:

| Column | Meaning |
|---|---|
| `blocked_if_removed` | courses that can no longer be taken at all if this course did not exist (alternatives are respected) |
| `delayed_if_removed` | courses that are still possible without it, but only through a longer chain |
| `bsc_reqs_broken`, `ba_reqs_broken` | degree requirements that can no longer be met without this course |
| `min_levels` | fewest prerequisite levels needed before a course, taking the shortest alternative each time (0 = no prerequisites; corequisites do not count) |
| `descendants`, `longest_chain_to_node` | plain graph measures that follow every arrow; upper bounds that ignore alternatives |

**RQ4 term simulation** (`output/rq4_term_delay.csv`): for each offering pattern (2025-26, 2022-23), with and without Summer, each load (5 or 6 courses per term) and each degree, the terms to graduate and the extra terms if one of 11 key COSC courses is missed once. The Winter-only runs are the main result; the Summer runs are exploratory.

**BSc and BA networks** (N4, N5) are the core networks defined in `REVIEW_CHECKLIST.md`: the mandatory and choice courses of each degree (BSc English choice left out) and the links between them.

## Modelling decisions and limitations

- **Historical plan:** the BSc requirements follow last year's plan, not the current calendar, because we only use historical data. COSC 210, COSC 270 and DATA 311 (new requirements in the current calendar) are left out.
- **Always satisfied:** high-school entry and year-standing requirements are treated as met. Minimum grades are not modelled.
- **Corequisites** decide whether a course can be taken, but don't add to chain length.
- **Never-offered courses:** COSC 223, 413 and 417 have no sections in Workday or PAIR for 2021-22 to 2025-26. They stay in the network because the calendar lists them, but the RQ4 simulation treats them as unavailable.
- **Hidden small counts:** UBC hides grade counts below 6 students, so some sections have no fail count and are left out of the fail rate.
- **Missing fail rates:** 17 of the 92 courses have no fail rate (not offered in 2021–2025, or counts hidden). They use the median fail rate, which affects the weighted rankings in RQ6.
- **Term simulation:** uses a simple scheduling rule (longest dependent chain first, up to 5 or 6 courses per term, 120 credits to graduate) and two offering patterns. Courses without offering data are assumed to run every term. Summer runs are not reported because the simulated student does not choose an optimal Summer schedule.
- **PageRank and Katz** follow every edge, so the RQ6 rankings share the downstream measure's problem with alternative prerequisites.

## Future work

- Combine fail rates with the AND/OR removal measure, e.g. weight each blocked course by the chance of failing the course that blocks it.
- Extend the term simulation with an optimal Summer schedule, more offering patterns, and simulations that add new prerequisites.
- Apply the approach to the current calendar and to other UBCO degree programs.

## Status

| Proposal timeline | Status |
|---|---|
| Weeks 1–2 (Oct 19–30): collect and clean data, build BSc and BA networks | Done |
| Weeks 3–4 (Nov 2–13): centrality, chains, bottlenecks, RQ4 simulations | Done |
| Weeks 5–6 (Nov 16–27): BSc vs. BA comparison, grade-weighted analysis | Done |
| Weeks 7–8 (Nov 30–Dec 8): video presentation (Dec 3) and final report (Dec 8) | In progress |

## Team

Ashish Nayak, Ivan Medellin, Gamuchirai Mhere and Muhammad Aliyan

## Sources

- DonneyF (2026) *ubc-pair-grade-data: UBC PAIR grade distribution data*. GitHub. https://github.com/DonneyF/ubc-pair-grade-data. Accessed 19 Oct 2026.
- Slim A, Kozlick J, Heileman GL, Wigdahl J, Abdallah CT (2014) Network analysis of university courses. In: *Proceedings of the 23rd International Conference on World Wide Web*. ACM, New York, pp 713–718. https://doi.org/10.1145/2567948.2579360
- Stavrinides P, Zuev KM (2023) Course-prerequisite networks for analyzing and understanding academic curricula. *Appl Netw Sci* 8(1):19. https://doi.org/10.1007/s41109-023-00543-w
- University of British Columbia (2026) *Okanagan Academic Calendar: Computer Science (BA and BSc)*. Accessed 19 Oct 2026.
- University of South Carolina (n.d.) *Curricular analytics: academic advising*. https://sc.edu/about/offices_and_divisions/advising/university_advising_center/curricular_analytics/. Accessed 25 Nov 2026.
- Zuev KM, Stavrinides P (2025) Breadth, depth, and flux of course-prerequisite networks. *Netw Sci* 13:e17. https://doi.org/10.1017/nws.2025.10013
