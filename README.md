# Bottlenecks and Critical Paths in the UBCO Computer Science Degree

*A prerequisite network analysis for COSC 421 (Network Science), UBC Okanagan*

## About the Project
We model the UBCO Computer Science degree as a **directed network**. Each **node** is a course. Each **edge** points from a prerequisite to a course it unlocks (e.g. `COSC 121 → COSC 222`).

We don't just look for one shortest path to graduation. We study how the structure of the network affects a student's progress through the degree: which courses unlock the most of it, where students can get held back, and what happens when a key course is delayed or removed.

## Why It Matters
Prerequisite networks are a real-world directed network where order matters. Delays are costly: a single course that many others depend on can push back a student's whole degree. As 4th-year CS students, our team has dealt with these course-planning problems first-hand, so we wanted to look at the degree from a network perspective.

What makes this project different is that it combines three data sources:
- **Prerequisites** from the UBCO Academic Calendar
- **How often each course is offered** (every term vs. once a year)
- **Historical grade and fail-rate data** from UBC PAIR

## Research Questions
1. **Central courses:** Which courses are most important, by in/out-degree, betweenness and closeness centrality, and number of downstream courses?
2. **Bottlenecks:** Which courses hold up the most of the degree when they are removed or delayed?
3. **Prerequisite chains:** How long are the longest chains, and how much of the degree can be taken without prerequisites?
4. **Sensitivity:** How does the network change when prerequisites or courses are added, removed or delayed?
5. **BSc vs. BA:** How similar are the two degrees' prerequisite networks?
6. **Course difficulty:** Does weighting courses by historical fail rate (e.g. with PageRank or Katz centrality) change which courses count as bottlenecks?

## What We Hope to Achieve
- A clear map of the CS degree's prerequisite structure for both the BSc and the BA
- A ranked list of the courses that matter most for staying on track
- Evidence of how delays to key courses spread through the rest of the degree
- Insights that could help students plan their courses and help departments spot high-risk bottlenecks

## Team
Ashish, Ivan, Gamu, Muhammad


# ubco_cosc_course_anaylsis

Scrapes the UBC Okanagan COSC course calendar, extracts each course's
prerequisites and corequisites, and builds a directed prerequisite graph.

## Setup

Requires Python 3.10+.

### macOS / Linux

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Windows (PowerShell)

```powershell
py -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

In Command Prompt (cmd), activate with `venv\Scripts\activate.bat` instead.

## Usage

With the venv active:

```bash
python scrape_courses.py              # scrape COSC, write CSVs + GraphML
python scrape_courses.py --plot       # also save a PNG of the graph
python scrape_courses.py --no-external  # drop non-COSC prereqs (MATH, STAT, ...)
python scrape_courses.py --url <subject page> --out <dir>
```

## Output

Files are written to `output/`:

| File | Contents |
| --- | --- |
| `courses.csv` | one row per course, with raw prereq/coreq text |
| `edges.csv` | `source,target,relation` (prereq or coreq) |
| `prereq_graph.graphml` | the graph, for Gephi / Cytoscape / networkx |
| `prereq_graph.png` | graph image (only with `--plot`) |

## UBC Pair Grade Data Collection

### Source
Historical grade data comes from the public [ubc-pair-grade-data](https://github.com/DonneyF/ubc-pair-grade-data) GitHub repository, which collects grade distributions from UBC's official PAIR / Tableau grade dashboard. We used the `tableau-dashboard-v2/UBCO` folder, which covers **UBC Okanagan** terms from **2021 Summer (2021S) to 2025 Winter (2025W)**. The repo stores one CSV per subject per term (e.g. `2024W/UBCO-2024W-COSC.csv`).

### How `combine_grades.py` works
Run it with: `python combine_grades.py PATH/TO/ubc-pair-grade-data`

1. **Selects subjects:** It loads only the subjects that contain a required course in the BSc or BA Computer Science major, as listed in the UBCO Academic Calendar: COSC, MATH, STAT, DATA, PHIL, ENGL, INDG, CORH, APSC, PHYS, BIOL, CHEM and EESC.
2. **Combines files:** It stacks every term's CSV for those subjects into one table, then adds a `Term` column (e.g. `2024W`) and a `Course Code` column (e.g. `COSC 111`).
3. **Summarizes by course:** It groups all sections and terms of a course into one row. The average grade is weighted by the number of students in each section. The fail rate is the share of students graded below 50%.
4. **Filters to required courses:** It keeps only the courses in the `REQUIRED` list (BSc and BA requirements, electives excluded) and marks which degree each belongs to.
5. **Checks coverage:** It prints any required course that has no grade data.

### Output files

| File | One row per | Use |
|---|---|---|
| `ubco_grades_all_sections.csv` | Section, per term (2,880 rows) | Raw combined data, for detailed checks |
| `ubco_grades_by_course.csv` | Course, all courses in the selected subjects (506 rows) | Lookup for any course, including prerequisites outside the required list |
| `ubco_grades_required.csv` | Required course (43 rows) | Main file for weighting nodes in the network (Q6) and comparing degrees (Q5) |

**Key columns in the summary files:**
- `Avg Grade`: average grade, weighted by section size
- `Fail Rate %`: percent of students graded below 50%
- `Students`: total students graded across all terms
- `Terms_Offered`, `Offered_in_Winter`, `Offered_in_Summer`, `First_Term`, `Last_Term`: how often the course was offered
- `In BSc` / `In BA` (required file only): whether each degree requires the course

### Limitations
- **Hidden small counts:** UBC hides grade counts below 6 for privacy, so some sections have no fail count. Those sections are left out of the fail rate. `Students_With_Fail_Data` shows how many students each fail rate is based on.
- **Missing courses:** COSC 270 and ENGL 113 are required (BSc) but have no grade data in the repo. They are still nodes in the network, but have no grade weight.
- **Options counted together:** "One of" requirements (e.g. COSC 111 or COSC 123) list every option as a required course.