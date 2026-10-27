# UBCO CS prerequisite network: data files

Last updated: 2026-10-27

## Files

| File | Status | What it is |
|---|---|---|
| `prereq_groups.csv` | UPDATED | Prerequisite logic (AND/OR) for 66 courses: COSC, MATH, STAT, DATA, PHYS, APSC, ENGL, CORH, PHIL. Expands to 160 prerequisite edges over 82 courses; the graph is acyclic. This is the file the networks are built from. |
| `coreq_groups.csv` | NEW | Corequisite logic (same format) for 8 courses: COSC 150, 221, 301, 305, STAT 203, PHYS 111, 121, 122. 13 corequisite edges. Adding them to the prerequisite graph still gives no cycles. |
| `prereq_groups_readable.txt` | UPDATED | The same content as plain-English formulas, each next to the calendar text, for checking against the calendar. Corequisites are in the last section. |
| `degree_requirements.csv` | UPDATED | BSc and BA requirements (120 credits each; both follow last year's plan). |
| `network_basic.png` / `network_basic.svg` | NEW | Basic drawing of all courses in the network (prerequisites solid, corequisites dashed, thick border = course in the BSc or BA plan). Use the SVG to zoom. |
| `network_nodes.csv` | NEW | One row per course in the drawing: role (plan course, offered elective, COSC course never offered, prerequisite only), number of prerequisites and courses it unlocks, and whether it has grade data. |
| `REVIEW_CHECKLIST.md` | NEW | What to check, where and against what. |
| `courses.csv` | unchanged | Scraped calendar text for 79 COSC courses. |
| `edges.csv` | unchanged | Original edge list (104 prereq + 7 coreq). Kept for reference. The network is now built from `prereq_groups.csv` and `coreq_groups.csv`. |
| UBC PAIR grade files (3) | unchanged | `all_sections`, `by_course`, `required`. |

## How to read `prereq_groups.csv` and `coreq_groups.csv`

Columns: `course, route, group, member, note`.

- Members in the same **group** are alternatives (OR).
- Different groups in the same **route** must all be satisfied (AND).
- Different **routes** are alternative ways to unlock the course (OR). Only COSC 111, 304 and 413 have two routes.
- Every member gives an edge `member -> course`, except the special tokens below.
- `HS_ENTRY` (high-school courses) and `STANDING_3` / `STANDING_4` (year standing) are treated as always satisfied and give no edge.
- Calendar wording: "one of A, B, C" (with or without the word "or") means A OR B OR C. "All of" and "and" mean AND.
- In `coreq_groups.csv`, a member can be taken in the same term as the course or earlier. It limits whether a course can be taken, but it does not lengthen prerequisite chains.
- Minimum grades are not modeled (they appear in the `note` column only).
- Courses with no prerequisites have no row; they are roots of the network.

## How to read `degree_requirements.csv`

Columns: `program, req_id, kind, options, pick, credits, note`.

- `mandatory`: the course must be taken.
- `choice`: pick `pick` courses from `options` (separated by `|`).
- `pool`: pick `pick` elective courses from the list. `ANY_COSC_UPPER` means any 300/400-level COSC course.
- `free`: credits without a named course.
- Rows with the same prefix are alternatives to each other (`BSC03_A` / `BSC03_B` for English: two courses or ENGL 109).

## Modeling decisions

1. Offering data uses Winter / Summer (the PAIR data has no Term 1 / Term 2 split).
2. Three networks: the full network, the BSc core (mandatory + choice courses) and the BA core.
3. Courses that never appear in the 2021-2025 section data are assumed not offered. They stay in the network but are excluded from the scheduler's elective pool.
4. Elective baseline: any upper-level COSC course that is offered. The 21 foundational and 12 distribution BA credits are treated as free credits.
5. **BSc requirements follow last year's plan, not the current calendar.** In that plan there is no COSC 210, COSC 270 or DATA 311 requirement, no concentrations (18 credits of upper-level COSC electives instead) and PHYS 111 or 112 replaces the science-course choice. COSC 270 is a new requirement in the current calendar (confirmed) and is not counted. COSC 210, COSC 270 and DATA 311 were deleted from the network (see "Courses removed from the network").
6. **The BSc core is built from `degree_requirements.csv`, not from the `In BSc` flag in `grades_required`.** That flag follows the current calendar: it includes BIOL 116/117, CHEM 121, EESC 111, COSC 210 and DATA 311, which are not in last year's plan, and it misses ENGL 113.
7. **Elective rules (BSc):** the 45 elective credits (`BSC07`, `BSC13`, `BSC21`, `BSC22`) must include at least 12 Science credits. For students who entered before 2024: at least 12 non-science credits (INDG 100 or ENGL 114 strongly encouraged). For students who entered in 2024 or later: at least 9 non-science credits plus 3 credits from INDG 100 or ENGL 114. We use the pre-2024 rule as the baseline. These rules are not enforced row by row.
8. **COSC 445 is excluded.** It appears in the section data but is not a requirement and not in `courses.csv`. COSC 344 is used instead (credit is granted for only one of the two). COSC 344 and the other upper-level COSC courses are electives: only the courses marked `mandatory` or `choice` are required.
9. **Corequisites** are kept in a separate edge type. They count when deciding whether a course can be taken (removing COSC 121 also blocks COSC 221) and in the scheduler (same term allowed), but not in chain length or topological levels.
10. **Deletion rule:** a course that is a requirement in the current calendar but not in last year's plan is deleted from the network. Electives are always kept, even if they appear only in the current calendar's concentration lists.

## Courses removed from the network

| Course | Why | What changed |
|---|---|---|
| COSC 210 | second-year requirement in the current calendar, not in last year's plan | own prerequisite and corequisite rows deleted; removed from the formulas of COSC 310, 344 and 407 |
| COSC 270 | same | own row deleted (it was not a prerequisite of anything) |
| DATA 311 | same | own row deleted; removed from the formula of COSC 412 |
| APSC 254, BIOL 202, PSYO 373 | only existed as alternatives for DATA 311 | disappear with DATA 311 |

BIOL 116/117, CHEM 121 and EESC 111 (current-calendar requirement choices) were never in the network files; they are not in the BSc requirement list and the `In BSc` flag of the PAIR file is ignored.

Effects to check:
- **COSC 310** is now `STANDING_3 AND (COSC 222 OR COSC 223)`: route (a) needed COSC 210 and was dropped.
- **COSC 344** now needs COSC 222 (COSC 210 was an alternative) and **COSC 407** needs only COSC 222, so COSC 222 is the only gate to both.
- **COSC 412** no longer requires DATA 311 (it now needs only COSC 310). COSC 412 was never offered in 2021-2025, so it does not affect results that use offering data.

## Assumptions to verify

- **BA credit table:** the program requirements (48 credits: 12 in years 1-2 and 36 in years 3-4) are identical in the current calendar and last year's plan, so the BA core network does not change. The credit table does: last year's adds a 12-credit distribution requirement and lists 9 credits of any-level electives, but its categories (21 + 12 + 48 + 15 + 9) total 105, not 120. We set the any-level electives (`BA12`) to 24 so the degree totals 120. Please check this number against the calendar.
- **Prerequisites come from the current calendar** while the BSc plan is last year's. They should be spot-checked for the core courses (COSC 111, 121, 123, 211, 221, 222, 304, 310, 320, 341, 499, MATH 100, 101, 103, 221, PHYS 111, 112, STAT 205, 230).
- **Year standing** (`STANDING_3` / `STANDING_4`) is treated as always satisfied; the credit thresholds are not modeled.
- **Formulas changed by the deletions** (COSC 310, 344, 407 and 412): see "Courses removed from the network" and the `note:` line under each course in the readable file.
- **COSC prerequisite formulas** are being reviewed against the calendar.

## Known data issues

- 15 network courses have no grade data: COSC 114, 150, 223, 247, 264, 412, 413, 417, 431, 432, 433, 434, 442, 450, 451. COSC 329 has grades but no fail rate.
- ENGL 113 is in the BSc English list but has no grade data and never appears in the 2021-2025 section data, so it is probably not offered at UBCO.
- BSc core, computer-science side: 19 courses and 30 edges in 4 connected components (PHYS 111, PHYS 112 and STAT 205 have no edge to another core course). Including the English/CORH/APSC 176 and 201 courses from the English choice gives 32 courses and 49 edges in 5 components.
- Fail rates cover only students with fail data (`Students_With_Fail_Data` is below `Students` for 11 of the 43 required courses).
- Courses with no prerequisites: APSC 171, 172, 176, 177, 179, DATA 101, COSC 122, CORH 205 and ENGL 109, 112, 113, 114, 150, 151, 153, 154, 155, 156 (per the calendar and the team).