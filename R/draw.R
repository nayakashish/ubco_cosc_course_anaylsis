# Node-link drawings.

# x = topological generation (or year level), nodes spread on y. Courses with no
# links get their own column at x = -1.
layered_positions <- function(g, key = "generation") {
  x <- if (key == "generation" && is_dag(g)) generations(g)[V(g)$name] else V(g)$year_level
  x[degree(g) == 0] <- -1
  d <- data.frame(name = V(g)$name, x = unname(x), group = V(g)$group)
  d <- d[order(d$x, d$group, d$name, method = "radix"), ]
  d$y <- ave(d$x, d$x, FUN = function(v) seq_along(v) - (length(v) + 1) / 2)
  d
}

# Shorten each link so the arrow head stops at the edge of the target node.
trim_links <- function(links, xr, yr, width, height, gap = 0.17) {
  dx <- (links$xend - links$x) * width / xr
  dy <- (links$yend - links$y) * height / yr
  cut <- pmin(gap / pmax(sqrt(dx^2 + dy^2), 1e-9), 0.4)
  within(links, {
    xend2 <- xend - (xend - x) * cut
    yend2 <- yend - (yend - y) * cut
  })
}

draw_prereq <- function(g, title, file, colours, legend, sizes = NULL, highlight = NULL,
                        key = "generation", width = 20, height = 11, drop_isolates = TRUE) {
  if (drop_isolates) g <- delete_vertices(g, V(g)$name[degree(g) == 0])
  pos <- layered_positions(g, key)
  height <- max(height, 0.42 * max(table(pos$x)) + 2)
  pos$fill <- colours[pos$name]
  pos$size <- if (is.null(sizes)) 9.3 else sqrt(sizes[pos$name]) * 0.353

  e <- ends(g, E(g))
  links <- data.frame(
    x = pos$x[match(e[, 1], pos$name)], y = pos$y[match(e[, 1], pos$name)],
    xend = pos$x[match(e[, 2], pos$name)], yend = pos$y[match(e[, 2], pos$name)],
    relation = ifelse(E(g)$relation == "coreq", "corequisite", "prerequisite"),
    marked = paste(e[, 1], e[, 2]) %in% highlight)
  links <- trim_links(links, diff(range(pos$x)), diff(range(pos$y)), width - 3, height - 1)
  arrow_ <- arrow(length = unit(0.08, "in"), type = "closed")

  xlab <- if (key == "generation") "topological generation (left = no prerequisites)" else "year level"
  if (any(pos$x == -1)) xlab <- paste0(xlab, "; far-left column = courses with no prerequisite links")

  p <- ggplot() +
    geom_curve(data = links[!links$marked, ], aes(x, y, xend = xend2, yend = yend2, linetype = relation),
               curvature = 0.06, colour = GRAY, linewidth = 0.35, arrow = arrow_) +
    scale_linetype_manual(values = c(prerequisite = "solid", corequisite = "dashed"), name = NULL)
  if (any(links$marked)) {
    p <- p + geom_curve(data = links[links$marked, ], aes(x, y, xend = xend2, yend = yend2),
                        curvature = -0.25, colour = INK, linewidth = 1, arrow = arrow_)
  }
  p <- p +
    geom_point(data = pos, aes(x, y, fill = fill), shape = 21, size = pos$size,
               colour = SURFACE, stroke = 1) +
    geom_text(data = pos, aes(x, y, label = sub(" ", "\n", name)), size = 2.3,
              lineheight = 0.9, colour = INK) +
    scale_fill_identity(guide = "legend", name = NULL, breaks = unname(legend), labels = names(legend)) +
    guides(fill = guide_legend(override.aes = list(size = 4))) +
    labs(title = paste0(title, "\nx-axis: ", xlab), x = NULL, y = NULL) +
    theme_project() +
    theme(panel.grid.major = element_blank(), axis.text = element_blank())
  save_figure(p, file, width, height)
}

# Force-directed drawing for the grade-data networks.
draw_spring <- function(g, file, title, colours, legend, widths = NULL, labels = NULL,
                        sizes = NULL, seed = 7) {
  alone <- V(g)$name[degree(g) == 0]
  if (length(alone)) {
    title <- paste0(title, "\n(not drawn, no links: ",
                    paste(sort(alone, method = "radix"), collapse = ", "), ")")
    g <- delete_vertices(g, alone)
  }
  set.seed(seed)
  xy <- layout_with_fr(g, weights = NA, niter = 3000)
  pos <- data.frame(name = V(g)$name, x = xy[, 1], y = xy[, 2])
  pos$fill <- colours[pos$name]
  pos$size <- if (is.null(sizes)) 6 else sqrt(sizes[pos$name]) * 0.353
  pos$label <- if (is.null(labels)) pos$name else labels[pos$name]
  e <- ends(g, E(g))
  links <- data.frame(
    x = pos$x[match(e[, 1], pos$name)], y = pos$y[match(e[, 1], pos$name)],
    xend = pos$x[match(e[, 2], pos$name)], yend = pos$y[match(e[, 2], pos$name)],
    width = if (is.null(widths)) 0.8 else 0.5 + 0.8 * edge_attr(g, widths))
  p <- ggplot() +
    geom_segment(data = links, aes(x, y, xend = xend, yend = yend), colour = GRAY,
                 linewidth = links$width * 0.4, alpha = 0.8) +
    geom_point(data = pos, aes(x, y, fill = fill), shape = 21, size = pos$size,
               colour = SURFACE, stroke = 0.8) +
    geom_text(data = pos, aes(x, y, label = label), size = 2.3, colour = INK) +
    scale_fill_identity(guide = "legend", name = NULL, breaks = unname(legend), labels = names(legend)) +
    guides(fill = guide_legend(override.aes = list(size = 4))) +
    labs(title = title, x = NULL, y = NULL) +
    theme_project() + theme(panel.grid.major = element_blank(), axis.text = element_blank())
  save_figure(p, file, 16, 12)
}

# The overview drawing of every course in the network (network_basic.png/.pdf).
draw_basic_network <- function(g, plan, files = c("network_basic.png", "network_basic.pdf")) {
  subject_fill <- c(COSC = "#9ecae1", MATH = "#fdd0a2", STAT = "#c7e9c0", PHYS = "#dadaeb",
                    APSC = "#fcbba1", DATA = "#b2e2cd", ENGL = "#fff2a8", CORH = "#fff2a8",
                    PHIL = "#e0e0e0")
  linked <- delete_vertices(g, V(g)$name[degree(g) == 0])
  pos <- layered_positions(linked)[, c("name", "x")]
  pos$y <- ave(pos$x, pos$x, FUN = seq_along)
  centre <- function() pos$y <<- ave(pos$y, pos$x, FUN = function(v) {
    (rank(v, ties.method = "first") - (length(v) + 1) / 2) * 1.0
  })
  centre()
  # Reorder each column by the average height of its neighbours to reduce crossings.
  for (pass in 1:12) {
    for (column in sort(unique(pos$x), decreasing = pass %% 2 == 0)) {
      for (i in which(pos$x == column)) {
        near <- as_ids(neighbors(linked, pos$name[i], mode = "all"))
        pos$y[i] <- mean(pos$y[match(near, pos$name)])
      }
      centre()
    }
  }
  alone <- sort(V(g)$name[degree(g) == 0], method = "radix")
  if (length(alone)) {
    pos <- rbind(pos, data.frame(
      name = alone, x = seq(0, max(pos$x), length.out = length(alone)), y = max(pos$y) + 3))
  }
  pos$fill <- subject_fill[sub(" .*", "", pos$name)]
  pos$plan <- pos$name %in% plan

  e <- ends(g, E(g))
  at <- function(v, col) pos[[col]][match(v, pos$name)]
  links <- data.frame(x = at(e[, 1], "x") + 0.32, y = at(e[, 1], "y"),
                      xend = at(e[, 2], "x") - 0.32, yend = at(e[, 2], "y"),
                      coreq = E(g)$relation == "coreq")
  p <- ggplot() +
    geom_curve(data = links, aes(x, y, xend = xend, yend = yend, colour = coreq, linetype = coreq),
               curvature = 0.08, linewidth = 0.35, arrow = arrow(length = unit(0.06, "in"), type = "closed")) +
    scale_colour_manual(values = c(`FALSE` = "#777777", `TRUE` = "#1f6fb4"), guide = "none") +
    scale_linetype_manual(values = c(`FALSE` = "solid", `TRUE` = "dashed"), guide = "none") +
    geom_tile(data = pos, aes(x, y, fill = fill), width = 0.64, height = 0.72,
              colour = ifelse(pos$plan, "black", "#777777"), linewidth = ifelse(pos$plan, 1.2, 0.25)) +
    geom_text(data = pos, aes(x, y, label = name), size = 2.9) +
    scale_fill_identity() +
    labs(title = "UBCO CS prerequisite network (never-offered COSC 223, 413 and 417 left out)",
         subtitle = paste("Thick border = in the BSc or BA plan. Solid arrow = prerequisite (A unlocks B).",
                          "Dashed blue = corequisite. Arrows do not show AND / OR.",
                          "Top row = courses with no links."),
         x = NULL, y = NULL) +
    theme_project() + theme(panel.grid.major = element_blank(), axis.text = element_blank())
  height <- 0.36 * diff(range(pos$y)) + 1.5
  # The PDF (zoomable) uses the base device, which needs no extra software.
  ggsave(files[1], p, width = 15, height = height, dpi = 160, bg = "white")
  ggsave(files[2], p, device = grDevices::pdf, width = 15, height = height, bg = "white")
}
