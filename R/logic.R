# Measures that read the AND/OR prerequisite rules instead of following every arrow.

satisfied <- function(routes, done) {
  if (!length(routes)) return(TRUE)
  any(vapply(routes, function(route) {
    all(vapply(route, function(group) any(group %in% SPECIAL | group %in% done), logical(1)))
  }, logical(1)))
}

# Every course a student could still eventually take if `removed` did not exist.
# Corequisites count (they can be taken in the same term).
takeable <- function(courses, prereq, coreq, removed = character(0)) {
  done <- character(0)
  repeat {
    before <- length(done)
    for (course in setdiff(courses, c(done, removed))) {
      if (satisfied(prereq[[course]], c(done, NO_EDGE[-1])) &&
          satisfied(coreq[[course]], c(done, NO_EDGE[-1]))) {
        done <- c(done, course)
      }
    }
    if (length(done) == before) return(done)
  }
}

# Fewest prerequisite levels before each course, taking the shortest alternative
# every time (0 = no prerequisites). `order` is a topological order.
min_levels <- function(order, prereq, removed = character(0)) {
  levels <- c()
  option_levels <- function(group) {
    usable <- group[group %in% NO_EDGE | group %in% names(levels)]
    vapply(usable, function(m) if (m %in% NO_EDGE) 0 else levels[[m]] + 1, numeric(1))
  }
  for (course in setdiff(order, removed)) {
    routes <- prereq[[course]]
    if (!length(routes)) {
      levels[course] <- 0
      next
    }
    per_route <- vapply(routes, function(route) {
      needs <- vapply(route, function(group) {
        opts <- option_levels(group)
        if (length(opts)) min(opts) else Inf
      }, numeric(1))
      max(needs)
    }, numeric(1))
    if (is.finite(min(per_route))) levels[course] <- min(per_route)
  }
  levels
}

# The shortest chain a student is forced through to reach a course.
critical_chain <- function(course, prereq, levels, in_degree_plan) {
  routes <- prereq[[course]]
  if (!length(routes) || levels[[course]] == 0) return(course)
  level_via <- function(m) if (m %in% NO_EDGE) 0 else levels[[m]] + 1
  for (route in routes) {
    groups <- lapply(route, function(g) g[g %in% NO_EDGE | g %in% names(levels)])
    if (!all(lengths(groups) > 0)) next
    needs <- vapply(groups, function(g) min(vapply(g, level_via, numeric(1))), numeric(1))
    if (max(needs) != levels[[course]]) next
    options <- setdiff(groups[[which.max(needs)]], NO_EDGE)
    pick <- options[order(levels[options], !options %in% in_degree_plan, options, method = "radix")][1]
    return(c(critical_chain(pick, prereq, levels, in_degree_plan), course))
  }
  course
}

# Degree requirements (mandatory/choice rows) that can no longer be met.
requirements_broken <- function(reqs, program, available) {
  rows <- reqs[reqs$program == program & reqs$kind %in% c("mandatory", "choice"), ]
  met <- vapply(rows$options, function(o) sum(options_of(o) %in% available), numeric(1))
  broken <- rows$req_id[met < as.integer(rows$pick)]
  english <- c("BSC03_A", "BSC03_B")   # either row satisfies the English requirement
  c(setdiff(broken, english), if (all(english %in% broken)) "BSC03")
}
