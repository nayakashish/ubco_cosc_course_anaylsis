# RQ4: how many extra terms does a missed course add to graduation?
# Simulates a student moving through the degree term by term and writes
# output/rq4_term_delay.csv and rq4_results.txt.
# Run from the project root: source("rq4_term_simulation.R")

source("R/data.R")
source("R/logic.R")

rq4 <- new.env()
local(envir = rq4, {
  TERMS <- c("T1", "T2", "S")                # Winter Term 1, Winter Term 2, Summer
  LOADS <- c("5 courses" = 15, "6 courses" = 18)   # credits per term
  CREDITS_TO_GRADUATE <- 120
  KEY_COURSES <- paste("COSC", c(111, 121, 122, 123, 211, 221, 222, 304, 310, 320, 341))

  never <- never_offered_courses()
  prereq <- read_logic("prereq_groups.csv", never)
  coreq <- read_logic("coreq_groups.csv", never)
  reqs <- read_requirements(never)
  offerings <- read_data("course_offerings.csv")

  credits <- function(course) if (course == "COSC 499") 6 else 3
  members <- function(course) unlist(c(prereq[[course]], coreq[[course]]))

  # Core options plus everything that can lead to them.
  needed_courses <- function(program) {
    need <- character(0)
    stack <- unique(unlist(core_requirements(reqs, program)))
    while (length(stack)) {
      course <- stack[1]
      need <- c(need, course)
      stack <- unique(c(stack[-1], setdiff(members(course), c(need, NO_EDGE))))
    }
    need
  }

  # Longest chain of needed courses depending on each course (used as priority).
  chain_depth <- function(need) {
    unlocks <- setNames(lapply(need, function(m) need[vapply(need, function(c) m %in% members(c), logical(1))]), need)
    depth <- c()
    visit <- function(course) {
      if (!course %in% names(depth)) {
        depth[course] <<- 0
        below <- vapply(unlocks[[course]], visit, numeric(1))
        depth[course] <<- if (length(below)) max(below) + 1 else 0
      }
      depth[[course]]
    }
    vapply(need, visit, numeric(1))
  }

  # Terms attended until the degree is complete. Winter terms are always
  # attended; Summer only if `summer` and a degree course is taken.
  # `missed`: course the student fails (or cannot enrol in) on the first attempt.
  terms_to_graduate <- function(program, pattern, summer, load, missed = "") {
    rows <- offerings[offerings$pattern == pattern, ]
    offered <- setNames(strsplit(rows$terms_offered, " "), rows$course)
    need <- needed_courses(program)
    depth <- chain_depth(need)
    core <- core_requirements(reqs, program)
    done <- character(0)
    total <- 0
    attended <- 0
    first_miss <- 0
    for (t in 1:60) {
      term <- TERMS[(t - 1) %% 3 + 1]
      year <- (t - 1) %/% 3 + 1
      if (term == "S" && !summer) next
      done <- union(done, names(STANDING)[year >= STANDING])
      before <- done
      taken <- 0
      used <- 0
      repeat {
        options <- character(0)
        for (course in need) {
          if (course %in% done) next
          if (course %in% names(offered) && !term %in% offered[[course]]) next
          if (!satisfied(prereq[[course]], before) || !satisfied(coreq[[course]], union(before, done))) next
          if (course == missed && first_miss %in% c(0, t)) {
            first_miss <- t
            next
          }
          if (used + credits(course) <= load) options <- c(options, course)
        }
        if (!length(options)) break
        course <- options[order(-depth[options], options, method = "radix")][1]
        done <- c(done, course)
        taken <- taken + 1
        used <- used + credits(course)
        total <- total + credits(course)
      }
      if (term != "S") total <- total + load - used      # electives fill a Winter term
      if (taken > 0 || term != "S") attended <- attended + 1
      complete <- all(vapply(core, function(opts) any(opts %in% done), logical(1)))
      if (complete && total >= CREDITS_TO_GRADUATE) return(attended)
    }
    NA
  }

  grid <- expand.grid(program = c("BSc", "BA"), load = names(LOADS), summer = c("no", "yes"),
                      pattern = c("2025-26", "2022-23"), stringsAsFactors = FALSE)
  results <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    run <- function(missed = "") {
      terms_to_graduate(g$program, g$pattern, g$summer == "yes", LOADS[[g$load]], missed)
    }
    base <- run()
    data.frame(pattern = g$pattern, summer = g$summer, load = g$load, program = g$program,
               terms_to_graduate = base, missed_course = KEY_COURSES,
               extra_terms = vapply(KEY_COURSES, function(c) run(c) - base, numeric(1), USE.NAMES = FALSE))
  }))
  write.csv(results, "output/rq4_term_delay.csv", row.names = FALSE)

  summary_lines <- vapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    sel <- results[results$pattern == g$pattern & results$summer == g$summer &
                     results$load == g$load & results$program == g$program, ]
    late <- sel[sel$extra_terms != 0, ]
    delays <- if (nrow(late)) paste(sprintf("%s +%d", late$missed_course, late$extra_terms), collapse = ", ") else "no delay"
    sprintf("%s | Summer %s | %s | %s: graduate in %d terms | %s",
            g$pattern, g$summer, g$load, g$program, sel$terms_to_graduate[1], delays)
  }, character(1))
  writeLines(c(
    "RQ4 term simulation: terms to graduate and extra terms if one course is missed once.",
    "Load: 5 courses (15 credits) = usual, 6 courses (18 credits) = university maximum. 'Terms' = terms attended.",
    "Winter-only rows (Summer no) are the main result. Summer rows are exploratory: the simulated Summer student is not optimal (see report limitations).",
    "", summary_lines), "rq4_results.txt")
  cat(summary_lines, sep = "\n")
})
