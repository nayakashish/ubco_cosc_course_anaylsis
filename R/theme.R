# Colours, theme and saving helpers shared by all figures.
BLUE <- "#2a78d6"; ORANGE <- "#eb6834"; AQUA <- "#1baf7a"
GRAY <- "#b4b2ab"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e4e3df"
SURFACE <- "#fcfcfb"
SEQ <- c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b")
FIG_DIR <- "output/figures"

theme_project <- function() {
  theme_minimal(base_size = 11) +
    theme(plot.background = element_rect(fill = SURFACE, colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = GRID, linewidth = 0.4),
          plot.title = element_text(face = "bold", colour = INK, size = 12),
          plot.title.position = "plot",
          axis.text = element_text(colour = INK2),
          axis.title = element_text(colour = INK2),
          legend.title = element_text(colour = INK2))
}

save_figure <- function(plot, name, width, height, dpi = 160) {
  ggsave(file.path(FIG_DIR, name), plot, width = width, height = height, dpi = dpi,
         bg = SURFACE, limitsize = FALSE)
}

# Several plots in one image, filled row by row, with an optional overall title.
save_panels <- function(plots, name, ncol, width, height, title = NULL, dpi = 160) {
  png(file.path(FIG_DIR, name), width = width, height = height, units = "in", res = dpi, bg = SURFACE)
  on.exit(dev.off())
  nrow <- ceiling(length(plots) / ncol)
  top <- if (is.null(title)) 0 else 0.4
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    nrow + 1, ncol, heights = grid::unit(c(top, rep(1, nrow)), c("in", rep("null", nrow))))))
  if (!is.null(title)) {
    grid::grid.text(title, x = 0.01, just = "left", gp = grid::gpar(fontface = "bold", col = INK),
                    vp = grid::viewport(layout.pos.row = 1, layout.pos.col = seq_len(ncol)))
  }
  for (i in seq_along(plots)) {
    print(plots[[i]], vp = grid::viewport(layout.pos.row = (i - 1) %/% ncol + 2,
                                          layout.pos.col = (i - 1) %% ncol + 1))
  }
}

# Horizontal bar chart of the n largest values of a named vector.
top_bar <- function(values, title, n = 15, colour = BLUE, digits = 0) {
  values <- head(values[order(-values)], n)
  d <- data.frame(label = factor(names(values), levels = rev(names(values))), value = unname(values))
  ggplot(d, aes(value, label)) +
    geom_col(fill = colour, width = 0.7) +
    geom_text(aes(label = sprintf("%.*f", digits, value)), hjust = -0.15, size = 2.8, colour = INK2) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(title = title, x = NULL, y = NULL) +
    theme_project() + theme(panel.grid.major.y = element_blank())
}
