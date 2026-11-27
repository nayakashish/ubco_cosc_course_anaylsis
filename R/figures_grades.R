# Figures 16 and 19-25: offering, grade and instructor data.

figure_grades <- function(data, metrics, active, plan) {
  graded <- intersect(names(metrics$blocked_if_removed), data$by_course[["Course Code"]])
  g <- data$by_course[match(graded, data$by_course[["Course Code"]]), ]
  winter <- g$Offered_in_Winter == "TRUE"
  summer <- g$Offered_in_Summer == "TRUE"
  d <- data.frame(
    name = graded, terms = num(g$Terms_Offered), blocked = metrics$blocked_if_removed[graded],
    fail = num(g[["Fail Rate %"]]),
    pattern = ifelse(winter & summer, "Winter + Summer", ifelse(winter, "Winter only", "Summer only")))
  d$fail[is.na(d$fail)] <- 0
  cosc <- d[startsWith(d$name, "COSC"), ]
  cosc <- head(cosc[order(-cosc$blocked), ], 6)
  p <- ggplot(d, aes(terms, blocked)) +
    geom_point(aes(colour = pattern, size = fail), alpha = 0.85) +
    geom_text(data = cosc, aes(label = name), size = 2.8, colour = INK2, hjust = -0.15, vjust = -0.5,
              check_overlap = TRUE) +
    scale_colour_manual(values = c("Winter + Summer" = BLUE, "Winter only" = ORANGE, "Summer only" = AQUA),
                        name = "offered in") +
    scale_size_continuous(range = c(1.8, 7), name = "fail rate %") +
    scale_x_continuous(expand = expansion(mult = c(0.05, 0.1))) +
    labs(title = "Offering frequency vs courses blocked if removed",
         x = "terms offered, 2021S-2025W (max 10)", y = "courses blocked if removed") +
    theme_project()
  save_figure(p, "16_offering_vs_downstream.png", 10, 6)

  req <- data$required[!is.na(num(data$required[["Fail Rate %"]])), ]
  req <- req[order(num(req[["Fail Rate %"]])), ]
  req$course <- factor(req[["Course Code"]], levels = req[["Course Code"]])
  req$subject <- ifelse(startsWith(req[["Course Code"]], "COSC"), "COSC", "other subject")
  bar <- function(column, title) {
    req$v <- num(req[[column]])
    ggplot(req, aes(v, course, fill = subject)) +
      geom_col(width = 0.7) +
      scale_fill_manual(values = c("COSC" = BLUE, "other subject" = GRAY), name = NULL) +
      labs(title = title, x = NULL, y = NULL) +
      theme_project() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
  }
  save_panels(list(bar("Fail Rate %", "Fail rate % (required courses)"),
                   bar("Avg Grade", "Average grade (axis starts at 60)") + coord_cartesian(xlim = c(60, 90))),
              "19_required_fail_rate_avg_grade.png", 2, 14, 10)

  rank_of <- function(v) setNames(rank(-v, ties.method = "first"), names(v))
  slope <- function(a, b, title) {
    ra <- rank_of(metrics[[a]][active])
    rb <- rank_of(metrics[[b]][active])
    show <- active[ra <= 15 | rb <= 15]
    d <- data.frame(name = show, a = ra[show], b = rb[show])
    d$moved <- ifelse(d$a != d$b, BLUE, GRAY)
    ggplot(d) +
      geom_segment(aes(x = 0, xend = 1, y = a, yend = b, colour = moved), linewidth = 0.8) +
      geom_point(aes(0, a, colour = moved), size = 2.5) +
      geom_point(aes(1, b, colour = moved), size = 2.5) +
      geom_text(aes(-0.05, a, label = sprintf("%s (%d)", name, a)), hjust = 1, size = 2.8, colour = INK2) +
      geom_text(aes(1.05, b, label = sprintf("(%d) %s", b, name)), hjust = 0, size = 2.8, colour = INK2) +
      scale_colour_identity() +
      scale_x_continuous(limits = c(-0.5, 1.5), breaks = c(0, 1), labels = c("unweighted", "fail-rate weighted")) +
      scale_y_reverse() +
      labs(title = paste0(title, " rank on reversed graph\n(courses in top 15 of either)"), x = NULL, y = NULL) +
      theme_project() + theme(panel.grid.major = element_blank(), axis.text.y = element_blank())
  }
  save_panels(list(slope("pagerank_rev", "pagerank_rev_failw", "PageRank"),
                   slope("katz_rev", "katz_rev_failw", "Katz")),
              "20_weighted_vs_unweighted_rank.png", 2, 13, 8)

  s <- data$sections
  req_cosc <- sort(intersect(plan[startsWith(plan, "COSC")], data$by_course[["Course Code"]]), method = "radix")
  s <- s[s[["Course Code"]] %in% req_cosc, ]
  counts <- function(column) { v <- num(s[[column]]); v[is.na(v)] <- 0; v }
  totals <- aggregate(data.frame(reported = counts("Reported"), failed = counts("<50")),
                      list(course = s[["Course Code"]], term = s$Term), sum)
  totals <- totals[totals$reported > 0, ]
  totals$term <- factor(totals$term, levels = sort(unique(data$sections$Term), method = "radix"))
  p <- ggplot(totals, aes(term, 100 * failed / reported, group = course)) +
    geom_line(colour = BLUE, linewidth = 0.8) + geom_point(colour = BLUE, size = 1.8) +
    facet_wrap(~course, ncol = 4) +
    scale_x_discrete(drop = FALSE) +
    labs(title = "Fail rate by term, required COSC courses", x = NULL,
         y = "fail rate % (hidden <6 counts treated as 0)") +
    theme_project() + theme(axis.text.x = element_text(angle = 60, hjust = 1, size = 7))
  save_figure(p, "21_fail_rate_by_term.png", 16, 2.6 * ceiling(length(req_cosc) / 4))
}

figure_grade_networks <- function(networks, distributions, plan, similar_k) {
  order_ <- rownames(distributions)[order(level_of(rownames(distributions)), rownames(distributions), method = "radix")]
  d <- as.data.frame(as.table(distributions))
  d$course <- factor(d$Var1, levels = rev(order_))
  d$bin <- factor(d$Var2, levels = GRADE_BINS)
  p <- ggplot(d, aes(bin, course, fill = Freq)) +
    geom_tile() +
    scale_fill_gradientn(colours = SEQ, name = "share of\nstudents") +
    labs(title = "Grade distribution per COSC course (all terms pooled)", x = NULL, y = NULL) +
    theme_project() + theme(panel.grid.major = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1))
  save_figure(p, "22_grade_distribution_heatmap.png", 9, 0.28 * length(order_) + 1.5)

  named <- function(g, values) setNames(values, V(g)$name)
  fail0 <- function(g) ifelse(is.na(V(g)$fail_rate), 0, V(g)$fail_rate)

  b <- networks$N9_prof_course_bipartite
  course <- V(b)$bipartite == "course"
  draw_spring(b, "23_prof_course_bipartite.png",
              "N9 Instructor-course bipartite network (COSC sections, 2021S-2025W)\nedge width = sections taught",
              named(b, ifelse(course, BLUE, ORANGE)), c("course" = BLUE, "instructor" = ORANGE),
              widths = "sections",
              labels = named(b, ifelse(course, V(b)$name, sub(".* ", "", V(b)$name))),
              sizes = named(b, ifelse(course, 320, 120)))

  g <- networks$N10_shared_instructor
  draw_spring(g, "24_shared_instructor_network.png",
              "N10 Course-course network: edge = shared instructor (width = number shared)\nsize = fail rate",
              named(g, ifelse(V(g)$name %in% plan, BLUE, GRAY)),
              c("required (BSc or BA)" = BLUE, "elective / other" = GRAY),
              widths = "shared_instructors", sizes = named(g, 80 + 25 * fail0(g)))

  g <- networks$N11_grade_similarity
  level_colours <- c("100-level" = BLUE, "200-level" = ORANGE, "300-level" = AQUA, "400-level and grad (5xx)" = GRAY)
  draw_spring(g, "25_grade_similarity_network.png",
              sprintf("N11 Grade-distribution similarity network (each course linked to its %d most similar)\nsize = fail rate", similar_k),
              named(g, unname(level_colours[pmin(V(g)$year_level, 4)])), level_colours,
              sizes = named(g, 80 + 30 * fail0(g)))
}
