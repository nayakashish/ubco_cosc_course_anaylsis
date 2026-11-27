# RQ4 chart: extra terms to graduate when one course is missed once (BSc,
# Winter-only runs). Reads output/rq4_term_delay.csv.
# Run from the project root: source("rq4_chart.R")

suppressPackageStartupMessages(library(ggplot2))
source("R/theme.R")

local({
  d <- read.csv("output/rq4_term_delay.csv")
  d <- d[d$summer == "no" & d$program == "BSc", ]
  d$missed_course <- factor(d$missed_course, levels = rev(unique(d$missed_course)))
  base <- unique(d[c("load", "terms_to_graduate")])
  labels <- setNames(sprintf("%s per term (graduate in %d terms)", base$load, base$terms_to_graduate), base$load)
  d$text <- ifelse(d$extra_terms == 0, "0", sprintf("+%d", d$extra_terms))
  dodge <- position_dodge(width = 0.8, reverse = TRUE)
  p <- ggplot(d, aes(extra_terms, missed_course, fill = load)) +
    geom_col(position = dodge, width = 0.8) +
    geom_text(aes(label = text), position = dodge, hjust = -0.3, size = 3, colour = INK2) +
    facet_wrap(~ factor(paste(pattern, "course offerings"),
                        levels = paste(c("2025-26", "2022-23"), "course offerings"))) +
    scale_fill_manual(values = c("5 courses" = "#257de0", "6 courses" = "#f47230"), labels = labels, name = NULL) +
    scale_x_continuous(breaks = 0:2, limits = c(0, 2.4)) +
    labs(title = "Extra terms to graduate when one course is missed once (BSc, no summer terms)",
         x = "Extra terms to graduate", y = NULL,
         caption = "BA results are the same, except missing COSC 222 adds no terms in 2022-23. Source: rq4_term_simulation.R") +
    theme_project() +
    theme(legend.position = "top", panel.grid.major.y = element_blank(),
          strip.text = element_text(face = "bold", hjust = 0))
  save_figure(p, "26_rq4_term_delay.png", 12, 6, dpi = 200)
  cat("saved output/figures/26_rq4_term_delay.png\n")
})
