# Checks that never-offered courses appear in no network or table.
# Run after build_networks.R, from the project root.
suppressPackageStartupMessages(library(igraph))
source("R/data.R")

local({
  never <- never_offered_courses()
  stopifnot(setequal(never, c("COSC 223", "COSC 413", "COSC 417")))
  # Every other course must still be in the full network.
  kept <- setdiff(read_data("network_nodes.csv")$course, never)
  stopifnot(setequal(kept, V(read_graph("output/networks/N1_full.graphml", format = "graphml"))$name))

  graphs <- list.files("output/networks", "\\.graphml$", full.names = TRUE)
  stopifnot(length(graphs) == 13)
  for (path in graphs) {
    found <- intersect(V(read_graph(path, format = "graphml"))$name, never)
    if (length(found)) stop(path, " contains never-offered courses: ", paste(found, collapse = ", "))
  }
  tables <- c(list.files("output/networks", "\\.csv$", full.names = TRUE),
              "output/rq4_term_delay.csv", "rq4_results.txt")
  for (path in tables) {
    text <- readLines(path)
    found <- never[vapply(never, function(c) any(grepl(c, text, fixed = TRUE)), logical(1))]
    if (length(found)) stop(path, " mentions never-offered courses: ", paste(found, collapse = ", "))
  }
  cat("OK:", length(never), "never-offered courses are absent from all networks and tables\n")
})
