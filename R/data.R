# Reading the project data. Courses that were never offered are removed here, so
# no network, table, chart or simulation ever sees them.

GRADES_DIR <- "UBC Pair Grade Data"
SPECIAL <- "HS_ENTRY"                                      # always satisfied
STANDING <- c(STANDING_3 = 3, STANDING_4 = 4)              # year standing
NO_EDGE <- c(SPECIAL, names(STANDING))

read_data <- function(path) {
  read.csv(path, check.names = FALSE, colClasses = "character",
           na.strings = character(0), encoding = "UTF-8")
}

num <- function(x) suppressWarnings(as.numeric(x))

grades_path <- function(which) {
  file.path(GRADES_DIR, paste0("UBC Pair data - ubco_grades_", which, ".csv"))
}

# Never offered = listed in course_offerings.csv with no terms (checked in Workday
# and PAIR). Other courses without grade data are kept.
never_offered_courses <- function() {
  offerings <- read_data("course_offerings.csv")
  sort(unique(offerings$course[trimws(offerings$terms_offered) == ""]), method = "radix")
}

# course -> list of routes; route -> list of groups; group -> member courses.
# Same group = OR, groups in a route = AND, routes = alternatives.
read_logic <- function(path, never) {
  rows <- read_data(path)
  rows <- rows[!rows$course %in% never, ]
  in_order <- function(x) factor(x, levels = unique(x))
  lapply(split(rows, in_order(rows$course)), function(course) {
    unname(lapply(split(course, in_order(course$route)), function(route) {
      unname(lapply(split(route$member, in_order(route$group)), function(members) {
        # A group left empty cannot be met (COSC 247 needs COSC 223), so the
        # course stays in the network but is never takeable.
        unique(setdiff(members, never))
      }))
    }))
  })
}

# Degree requirement rows, with never-offered courses taken out of the options.
read_requirements <- function(never) {
  reqs <- read_data("degree_requirements.csv")
  reqs$options <- vapply(strsplit(reqs$options, "|", fixed = TRUE),
                         function(o) paste(setdiff(o, never), collapse = "|"), character(1))
  reqs
}

options_of <- function(x) strsplit(x, "|", fixed = TRUE)[[1]]

# Mandatory and choice courses of a degree. The BSc English choice (BSC03) is
# kept out of the core, as decided in REVIEW_CHECKLIST.md.
core_requirements <- function(reqs, program) {
  keep <- reqs$program == program & reqs$kind %in% c("mandatory", "choice") &
    !startsWith(reqs$req_id, "BSC03")
  lapply(reqs$options[keep], options_of)
}

load_project_data <- function() {
  never <- never_offered_courses()
  nodes <- read_data("network_nodes.csv")
  list(
    never = never,
    nodes = nodes[!nodes$course %in% never, ],
    prereq = read_logic("prereq_groups.csv", never),
    coreq = read_logic("coreq_groups.csv", never),
    reqs = read_requirements(never),
    titles = read_data("output/courses.csv"),
    by_course = read_data(grades_path("by_course")),
    required = read_data(grades_path("required.csv")),
    sections = read_data(grades_path("all_sections"))
  )
}
