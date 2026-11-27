# Figures 08-18: centrality, removal impact, chains and BSc vs BA.

figure_degrees <- function(full, metrics, active) {
  panel <- function(values, label) {
    d <- data.frame(v = values[active])
    ggplot(d, aes(v)) + geom_bar(fill = BLUE, width = 0.9) +
      labs(title = paste("N1", label, "distribution"), x = label, y = "number of courses") +
      theme_project()
  }
  save_panels(list(panel(metrics$in_degree, "in-degree"), panel(metrics$out_degree, "out-degree")),
              "08_degree_distributions.png", 2, 11, 4)
}

figure_centrality <- function(metrics, active) {
  panels <- list(
    list("in_degree", "in-degree", 0), list("out_degree", "out-degree", 0),
    list("betweenness", "betweenness", 3), list("closeness_in", "closeness (incoming)", 3),
    list("closeness_out", "closeness (outgoing)", 3),
    list("descendants", "downstream courses (descendants)", 0))
  save_panels(lapply(panels, function(p) top_bar(metrics[[p[[1]]]], paste("Top 15 by", p[[2]]), digits = p[[3]])),
              "09_centrality_top15.png", 3, 17, 10, "N1 centrality measures (Q1)")

  keys <- c("in_degree", "out_degree", "betweenness", "closeness_in", "closeness_out", "descendants",
            "ancestors", "blocked_if_removed", "delayed_if_removed", "min_levels",
            "pagerank_rev", "katz_rev")
  x <- vapply(keys, function(k) unname(metrics[[k]][active]), numeric(length(active)))
  d <- as.data.frame(as.table(cor(x, method = "spearman")))
  p <- ggplot(d, aes(Var2, factor(Var1, levels = rev(keys)), fill = Freq)) +
    geom_tile() +
    geom_text(aes(label = sprintf("%.2f", Freq)), size = 2.6, colour = INK) +
    scale_fill_gradient2(low = ORANGE, mid = "#f1efe9", high = BLUE, limits = c(-1, 1),
                         name = "Spearman rank\ncorrelation") +
    coord_equal() +
    labs(title = "Rank correlation between node measures (N1, linked courses)", x = NULL, y = NULL) +
    theme_project() + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid.major = element_blank())
  save_figure(p, "10_measure_correlation.png", 8.5, 7)
}

# Courses that become impossible when one prerequisite option (one arrow) is removed.
link_removal_effect <- function(edges, data, courses, base) {
  pre <- edges[edges$relation == "prereq", ]
  effect <- mapply(function(source, target) {
    prereq <- data$prereq
    prereq[[target]] <- lapply(prereq[[target]], function(route) lapply(route, setdiff, source))
    length(setdiff(base, takeable(courses, prereq, data$coreq)))
  }, pre$source, pre$target)
  setNames(effect, paste(pre$source, "->", pre$target))
}

figure_removal <- function(metrics, active, edges, data, courses, base) {
  save_panels(list(
    top_bar(metrics$descendants, "Downstream courses (every course reachable by arrows)\nupper bound: ignores alternatives"),
    top_bar(metrics$blocked_if_removed, "Courses blocked if removed\n(read from the AND/OR rules: no alternative left)", colour = ORANGE)),
    "11_removal_impact.png", 2, 14, 6, "Node removal impact (Q2)")

  blocked <- metrics$blocked_if_removed
  labelled <- head(active[order(-blocked[active])], 6)
  scatter <- lapply(c("betweenness", "out_degree", "closeness_out"), function(k) {
    d <- data.frame(name = active, x = metrics[[k]][active], y = blocked[active])
    ggplot(d, aes(x, y)) +
      geom_point(colour = BLUE, size = 3, alpha = 0.85) +
      geom_text(data = d[d$name %in% labelled, ], aes(label = name), size = 2.7, colour = INK2,
                hjust = -0.1, vjust = -0.4, check_overlap = TRUE) +
      scale_x_continuous(expand = expansion(mult = c(0.05, 0.18))) +
      labs(x = k, y = "courses blocked if removed") + theme_project()
  })
  save_panels(scatter, "12_centrality_vs_removal.png", 3, 16, 5, "Centrality vs removal impact (Q2)")

  both <- metrics$blocked_if_removed[active] + metrics$delayed_if_removed[active]
  top <- head(active[order(-both)], 15)
  d <- data.frame(
    course = factor(rep(top, 2), levels = rev(top)),
    kind = factor(rep(c("blocked", "still possible, longer chain"), each = length(top)),
                  levels = c("still possible, longer chain", "blocked")),
    n = c(metrics$blocked_if_removed[top], metrics$delayed_if_removed[top]))
  stacked <- ggplot(d, aes(n, course, fill = kind)) +
    geom_col(width = 0.7) +
    scale_fill_manual(values = c("blocked" = BLUE, "still possible, longer chain" = ORANGE),
                      name = NULL, guide = guide_legend(reverse = TRUE)) +
    labs(title = "When a course is removed: courses blocked vs delayed", x = NULL, y = NULL) +
    theme_project() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
  arrows_ <- top_bar(link_removal_effect(edges, data, courses, base),
                     "Courses that become impossible when one\nprerequisite option (arrow) is removed", n = 20)
  save_panels(list(arrows_, stacked), "15_sensitivity_removals.png", 2, 16, 6.5,
              "Sensitivity to single removals (Q4)")
}

figure_chains <- function(metrics, active, levels_, networks) {
  gen <- ggplot(data.frame(v = metrics$topo_generation[active]), aes(v)) +
    geom_bar(fill = BLUE, width = 0.7) +
    labs(title = "Courses per topological generation (N1)", x = "generation (0 = no prerequisites)", y = "courses") +
    theme_project()
  lev <- ggplot(data.frame(v = levels_[intersect(active, names(levels_))]), aes(v)) +
    geom_bar(fill = BLUE, width = 0.9) +
    labs(title = "Prerequisite levels needed before each course\n(shortest alternative at every step)",
         x = "levels (0 = no prerequisites)", y = NULL) +
    theme_project()
  save_panels(list(gen, lev), "13_chain_structure.png", 2, 13, 4.5)

  degrees <- list(BSc = networks$N4_bsc, BA = networks$N5_ba)
  d <- do.call(rbind, lapply(names(degrees), function(n) {
    data.frame(degree = n, level = levels_[V(degrees[[n]])$name])
  }))
  d$degree <- factor(d$degree, levels = names(degrees))
  p <- ggplot(d, aes(level, fill = degree)) +
    geom_bar(position = position_dodge(preserve = "single"), width = 0.75) +
    scale_fill_manual(values = c(BSc = BLUE, BA = ORANGE), name = NULL) +
    labs(title = "Chain depth of courses in the BSc vs BA networks",
         x = "prerequisite levels needed before the course (from the full network)", y = "courses") +
    theme_project()
  save_figure(p, "14_chain_depth_bsc_vs_ba.png", 9, 4.5)

  summary_of <- function(g) c(
    "nodes" = vcount(g), "edges" = ecount(g), "density" = edge_density(g),
    "levels needed (max)" = max(levels_[V(g)$name]), "generations" = max(generations(g)) + 1,
    "% no prereqs" = 100 * mean(degree(g, mode = "in") == 0), "linked courses" = sum(degree(g) > 0))
  values <- lapply(degrees, summary_of)
  panels <- lapply(names(values$BSc), function(k) {
    d <- data.frame(degree = factor(names(degrees), levels = names(degrees)),
                    v = c(values$BSc[[k]], values$BA[[k]]))
    ggplot(d, aes(degree, v, fill = degree)) +
      geom_col(width = 0.6) +
      geom_text(aes(label = sprintf(if (k == "density") "%.3f" else "%.0f", v)), vjust = -0.4,
                size = 2.8, colour = INK2) +
      scale_fill_manual(values = c(BSc = BLUE, BA = ORANGE), guide = "none") +
      scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
      labs(title = k, x = NULL, y = NULL) +
      theme_project() + theme(plot.title = element_text(size = 9), panel.grid.major.x = element_blank())
  })
  save_panels(panels, "17_bsc_vs_ba_summary.png", length(panels), 17, 3.6, "BSc vs BA network summary (Q5)")

  broken <- function(key, label, colour) {
    v <- metrics[[key]]
    top_bar(v[v > 0], paste0(label, ": requirements that can no longer be met\nif this course is removed"), colour = colour)
  }
  save_panels(list(broken("bsc_reqs_broken", "BSc", BLUE), broken("ba_reqs_broken", "BA", ORANGE)),
              "18_bsc_vs_ba_top_downstream.png", 2, 13, 6)
}
