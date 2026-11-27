# Builds all networks, computes the measures and draws figures 01-25 plus
# network_basic. Descriptive only: no conclusions are drawn here.
# Run from the project root (open cosc421.Rproj): source("build_networks.R")

suppressPackageStartupMessages({
  library(igraph)
  library(ggplot2)
})
for (f in c("data", "logic", "networks", "metrics", "theme", "draw", "figures_networks",
            "figures_measures", "figures_grades")) {
  source(file.path("R", paste0(f, ".R")))
}

NET_DIR <- "output/networks"
dir.create(NET_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
# Clear earlier output so nothing stale (e.g. a renamed N8 network) is left over.
unlink(list.files(NET_DIR, full.names = TRUE))
unlink(list.files(FIG_DIR, pattern = "^(0|1|2[0-5]).*\\.png$", full.names = TRUE))

data <- load_project_data()
all_courses <- data$nodes$course
edges <- edge_table(data)

degree_courses <- function(program) unique(unlist(core_requirements(data$reqs, program)))
BSC <- degree_courses("BSc")
BA <- degree_courses("BA")
attributes_for <- function(codes) course_attributes(codes, data, BSC, BA)

# ---- networks
networks <- list()
networks$N1_full <- build_network(edges, attributes_for, extra_nodes = all_courses)
networks$N2_prereq_only <- build_network(edges[edges$relation == "prereq", ], attributes_for,
                                         extra_nodes = all_courses)
networks$N3_cosc_only <- build_network(edges, attributes_for, keep = function(x) startsWith(x, "COSC"),
                                       extra_nodes = all_courses)
full <- networks$N1_full
prereq_net <- networks$N2_prereq_only

order_ <- as_ids(topo_sort(prereq_net))
base <- takeable(all_courses, data$prereq, data$coreq)
blocked <- setNames(lapply(all_courses, function(course) {
  setdiff(base, c(takeable(all_courses, data$prereq, data$coreq, removed = course), course))
}), all_courses)
levels_ <- min_levels(order_, data$prereq)

degree_network <- function(codes) {
  g <- induced_subgraph(full, V(full)$name[V(full)$name %in% codes])
  V(g)$required <- TRUE
  g
}
networks$N4_bsc <- degree_network(BSC)
networks$N5_ba <- degree_network(BA)

union_codes <- V(full)$name[V(full)$name %in% c(BSC, BA)]
union_edges <- unique(rbind(as_data_frame(networks$N4_bsc), as_data_frame(networks$N5_ba)))
union_nodes <- attributes_for(union_codes)
union_nodes$required <- TRUE
union_nodes$membership <- ifelse(union_codes %in% BSC & union_codes %in% BA, "both",
                                 ifelse(union_codes %in% BSC, "BSc only", "BA only"))
networks$N6_bsc_ba_union <- graph_from_data_frame(union_edges, vertices = union_nodes)

# Grade-weighted copy. Courses without grade data get the median fail rate.
#   w_fail_src / w_pass_src : fail / pass rate of the prerequisite
#   w_cost_src              : 1 / pass rate ("expected attempts")
#   w_fail_tgt              : fail rate of the course being unlocked
weighted <- full
median_fail <- median(V(full)$fail_rate, na.rm = TRUE)
V(weighted)$fail_rate_filled <- ifelse(is.na(V(full)$fail_rate), median_fail, V(full)$fail_rate)
fail_filled <- setNames(V(weighted)$fail_rate_filled, V(weighted)$name)
e <- ends(weighted, E(weighted))
E(weighted)$w_fail_src <- unname(fail_filled[e[, 1]]) / 100
E(weighted)$w_pass_src <- 1 - E(weighted)$w_fail_src
E(weighted)$w_cost_src <- 1 / E(weighted)$w_pass_src
E(weighted)$w_fail_tgt <- unname(fail_filled[e[, 2]]) / 100
networks$N7_grade_weighted <- weighted

metrics <- course_metrics(full, prereq_net, data, fail_filled, base, blocked, levels_, order_)

# N8: drop each of the three courses that block the most other courses.
top_removed <- head(V(full)$name[order(-metrics$blocked_if_removed, -metrics$descendants)], 3)
for (course in top_removed) {
  networks[[paste0("N8_minus_", sub(" ", "", course))]] <- delete_vertices(full, course)
}

networks$N9_prof_course_bipartite <- instructor_network(data$sections, attributes_for)
networks$N10_shared_instructor <- shared_instructor_network(networks$N9_prof_course_bipartite)
distributions <- grade_distributions(data$sections)
SIMILAR_K <- 3
networks$N11_grade_similarity <- grade_similarity_network(distributions, attributes_for, SIMILAR_K)

# ---- tables
for (name in names(networks)) save_network(networks[[name]], name, NET_DIR)

columns <- c("title", "group", "role", "year_level", "in_bsc", "in_ba", "avg_grade",
             "fail_rate", "terms_offered")
node_table <- data.frame(course = V(full)$name, as_data_frame(full, "vertices")[columns],
                         lapply(metrics, function(m) unname(m[V(full)$name])))
node_table <- node_table[order(node_table$course, method = "radix"), ]
write.csv(node_table, file.path(NET_DIR, "node_metrics_full.csv"), row.names = FALSE, na = "")
write.csv(network_summary(networks), file.path(NET_DIR, "network_summary.csv"),
          row.names = FALSE, na = "")

# ---- figures
draw_basic_network(full, plan = unique(unlist(lapply(
  data$reqs$options[data$reqs$kind %in% c("mandatory", "choice")], options_of))))
chain <- figure_networks(networks, weighted, data, levels_, c(BSC, BA))
active <- V(full)$name[degree(full) > 0]
figure_centrality(metrics, active)
figure_removal(metrics, active, edges, data, all_courses, base)
figure_chains(metrics, active, levels_, networks)
figure_degrees(full, metrics, active)
figure_grades(data, metrics, active, c(BSC, BA))
figure_grade_networks(networks, distributions, c(BSC, BA), SIMILAR_K)

cat("never offered, left out:", paste(data$never, collapse = ", "), "\n")
cat("courses:", vcount(full), "| links:", ecount(full), "| DAG:", is_dag(full), "\n")
cat("longest forced chain:", paste(chain, collapse = " -> "), "\n")
cat("removed variants:", paste(top_removed, collapse = ", "), "\n")
cat("figures:", length(list.files(FIG_DIR, "\\.png$")), "| networks:", length(networks), "\n")
