# Review checklist: what to check, where, and against what

Last updated: 2026-10-27. Read `README_data_files.md` first for how each file is organized.

## 1. Prerequisite formulas: `prereq_groups_readable.txt` (66 courses)

For each course, compare the formula line (`COSC 320 = ...`) with the `calendar:` line under it. Does the formula say the same thing?

Rules used: "one of A, B, C" (with or without the word "or") = A OR B OR C. "All of" / "and" = AND. "(a) ... or (b) ..." = two routes, written `[ ... ] || [ ... ]`.

| Part of the file | Courses | Calendar text comes from | Status |
|---|---|---|---|
| Top of file | 40 COSC courses | `courses.csv` (scraped) | 10 reviewed so far |
| NEW SECTION 1 | MATH, STAT, DATA, PHYS, APSC, COSC 114 | text pasted by the team | not reviewed |
| NEW SECTION 2 | ENGL 203, CORH 203, APSC 201, PHIL 331 | text pasted by the team | not reviewed |
| NEW SECTION 3 | corequisites (9 courses) | `courses.csv` and pasted text | not reviewed |

Worth reading closely (mixed AND/OR): COSC 223, 303, 304, 310, 320, 329, 335, 341, 344, 406, 414, 421. The four courses with two routes: COSC 111, 304, 310, 413.

Specific points:
- **Formulas changed by the deletions of COSC 210, COSC 270 and DATA 311:** COSC 310, 344, 407 and 412. Read the `note:` line under each one and confirm the result is acceptable (COSC 222 becomes the only gate to COSC 344 and 407).
- **MATH 200:** modeled as MATH 101 OR MATH 103 (the 65% minimum in MATH 103 is not modeled).
- **Not needed:** whether the 70% in COSC 111 applies to the MATH 100/101/103/116 route (minimum grades are not modeled).

## 2. Last year's calendar vs the current calendar

The prerequisites come from the current calendar, but the BSc plan is last year's. If your team can see last year's version of these entries (archived calendar or Workday history), check that the prerequisites did not change:

COSC 111, 121, 123, 211, 221, 222, 304, 310, 320, 341, 499, MATH 100, 101, 103, 221, PHYS 111, 112, STAT 205, 230.

## 3. Degree requirements: `degree_requirements.csv`

- **BSc (rows BSC01-BSC22):** compare with last year's plan. Credits: year 1 = 30, year 2 = 30, years 3-4 = 60 (total 120). The 45 elective credits are BSC07 (9), BSC13 (15), BSC21 (3) and BSC22 (18). English: two courses from the list OR ENGL 109 (`BSC03_A` / `BSC03_B`).
- **BA (rows BA01-BA14):** the 48 program credits match last year's plan. Please check the **any-level electives** number (`BA12`): the pasted table says 9, but its categories then total 105, not 120. We set it to 24. Also confirm whether the 21 foundational and 12 distribution credits can overlap with program courses (affects how many free credits remain).

## 4. Decisions to confirm

1. **BSc core network** = the computer-science side only (19 courses, 30 edges); the English/CORH/APSC 176 and 201 courses stay out of the centrality and bottleneck metrics. Including them would give 32 courses and 49 edges.
2. **COSC 210, COSC 270 and DATA 311 are deleted** from the network (requirements in the current calendar but not in last year's plan). Electives are always kept, including COSC 412, 442 and the others that only appear in the current calendar's concentration lists.
3. **COSC 445** is excluded; COSC 344 is used instead.
4. **Corequisites** are a separate edge type: they affect whether a course can be taken and the scheduler, but not chain length.
5. **Offering data: Winter / Summer only.** Courses never offered 2021-2025 are assumed not offered.
6. **Missing grades:** fill with the mean of same-level COSC courses and flag them (no neighboring years exist for those courses).
7. **Elective rules:** we use the pre-2024 rule (12 non-science credits). Confirm which entry cohort the project models.

## 5. Checks already done (no need to repeat)

- Every original prerequisite edge is in `prereq_groups.csv` (except those that involve the deleted courses), and every member has an edge (no extra, no missing).
- 66 courses, 183 rows, no duplicate rows. The formulas in the readable file match the CSV exactly.
- Prerequisite graph: 82 courses, 160 edges, no cycles. Adding the 13 corequisite edges (85 courses in total) still gives no cycles.
- No trace of COSC 210, COSC 270, DATA 311, APSC 254, BIOL 202 or PSYO 373 is left in the network.
- Every course in the BSc plan has prerequisite data, and so does everything behind it.
- BSc and BA credit totals: 120 each. Core networks: BSc 19 courses and 30 edges; BA 10 courses and 17 edges.

## 6. Still not modeled or missing

- Year-standing thresholds (credits needed for 3rd and 4th year): treated as always satisfied.
- Minimum grades and "credit for only one of" rules (for example MATH 100 / 116).
- 15 network courses have no grade data (list in the README).
