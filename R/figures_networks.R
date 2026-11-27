# Figures 01-07: the prerequisite network drawings.
figure_networks <- function(networks, weighted, data, levels_, plan) {
  full <- networks$N1_full
  group_colours <- c("COSC" = BLUE, "MATH / STAT / DATA" = ORANGE, "Other (APSC, PHYS, ...)" = AQUA)
  by_group <- function(g) setNames(group_colours[V(g)$group], V(g)$name)

  draw_prereq(full, "N1 Full prerequisite network (undergrad COSC + external prereqs)",
              "01_full_network_by_generation.png", by_group(full), group_colours)
  draw_prereq(full, "N1 Full prerequisite network, arranged by year level",
              "02_full_network_by_year.png", by_group(full), group_colours, key = "year")
  draw_prereq(networks$N3_cosc_only, "N3 COSC-only prerequisite network", "03_cosc_only_network.png",
              by_group(networks$N3_cosc_only), group_colours[1], width = 18, height = 10)

  for (degree_ in list(c("N4_bsc", "BSc"), c("N5_ba", "BA"))) {
    g <- networks[[degree_[1]]]
    draw_prereq(g, paste(degree_[1], degree_[2], "core: required courses and the links between them"),
                sprintf("04_%s_network.png", tolower(degree_[2])),
                setNames(ifelse(startsWith(V(g)$name, "COSC"), BLUE, ORANGE), V(g)$name),
                c("COSC course" = BLUE, "other subject" = ORANGE),
                width = 16, height = 10, drop_isolates = FALSE)
  }

  both <- networks$N6_bsc_ba_union
  membership <- c("both" = BLUE, "BSc only" = ORANGE, "BA only" = AQUA)
  draw_prereq(both, "N6 BSc / BA union, coloured by which degree network the course is in",
              "05_bsc_vs_ba_union.png", setNames(membership[V(both)$membership], V(both)$name),
              membership, width = 18, drop_isolates = FALSE)

  # The course whose shortest possible route is longest, and that route.
  candidates <- sort(names(levels_), method = "radix")
  deepest <- candidates[order(-levels_[candidates], !candidates %in% plan,
                              !startsWith(candidates, "COSC"), method = "radix")][1]
  chain <- critical_chain(deepest, data$prereq, levels_, plan)
  draw_prereq(full, sprintf("Longest forced prerequisite chain (%d levels: %s)\ntaking the shortest alternative at every step",
                            length(chain) - 1, paste(chain, collapse = " -> ")),
              "06_longest_chain.png",
              setNames(ifelse(V(full)$name %in% chain, BLUE, GRAY), V(full)$name),
              c("on longest chain" = BLUE, "other" = GRAY),
              highlight = paste(head(chain, -1), tail(chain, -1)))

  draw_prereq(weighted, "N7 Grade-weighted network: node size = fail rate, colour = has grade data",
              "07_grade_weighted_network.png",
              setNames(ifelse(V(weighted)$has_grades, BLUE, GRAY), V(weighted)$name),
              c("has PAIR grade data" = BLUE, "no grade data (size = median)" = GRAY),
              sizes = setNames(150 + 90 * V(weighted)$fail_rate_filled, V(weighted)$name))
  chain
}
