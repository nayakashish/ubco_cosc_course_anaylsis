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
