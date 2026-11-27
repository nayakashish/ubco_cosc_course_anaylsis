# Building the networks (igraph) and saving them.

# One row per prerequisite / corequisite link.
edge_table <- function(data) {
  rows <- list()
  for (relation in c("prereq", "coreq")) {
    logic <- data[[relation]]
    for (course in names(logic)) {
      for (route in seq_along(logic[[course]])) {
        for (group in logic[[course]][[route]]) {
          members <- sort(setdiff(group, NO_EDGE), method = "radix")
          if (!length(members)) next
          rows[[length(rows) + 1]] <- data.frame(
            source = members, target = course, relation = relation,
            route = route, alternatives = length(group))
        }
      }
    }
  }
  do.call(rbind, rows)
}

level_of <- function(code) as.integer(substr(sub(".* ", "", code), 1, 1))

subject_group <- function(code) {
  subject <- sub(" .*", "", code)
  ifelse(subject == "COSC", "COSC",
         ifelse(subject %in% c("MATH", "STAT", "DATA"), "MATH / STAT / DATA",
                "Other (APSC, PHYS, ...)"))
}

# Attribute table for a set of courses; NA where there is no value.
course_attributes <- function(codes, data, bsc, ba) {
  g <- data$by_course[match(codes, data$by_course[["Course Code"]]), ]
  title <- data$titles$title[match(codes, data$titles$code)]
  title <- ifelse(is.na(title) | title == "", g$Title, title)
  data.frame(
    name = codes,
    title = ifelse(is.na(title), "", title),
    subject = sub(" .*", "", codes),
    group = subject_group(codes),
    year_level = level_of(codes),
    in_bsc = codes %in% bsc,
    in_ba = codes %in% ba,
    role = ifelse(codes %in% data$nodes$course, data$nodes$role[match(codes, data$nodes$course)], ""),
    has_grades = !is.na(g[["Course Code"]]),
    avg_grade = num(g[["Avg Grade"]]),
    fail_rate = num(g[["Fail Rate %"]]),
    students = num(g[["Students"]]),
    terms_offered = num(g[["Terms_Offered"]]),
    offered_winter = g$Offered_in_Winter == "TRUE",
    offered_summer = g$Offered_in_Summer == "TRUE")
}

build_network <- function(edges, attributes, keep = function(x) TRUE, extra_nodes = character(0)) {
  edges <- edges[keep(edges$source) & keep(edges$target), ]
  # A pair listed twice keeps one link, with the values of its last row.
  key <- paste(edges$source, edges$target, sep = "|")
  edges <- edges[!duplicated(key, fromLast = TRUE), ]
  nodes <- unique(c(extra_nodes[keep(extra_nodes)], rbind(edges$source, edges$target)))
  graph_from_data_frame(edges, directed = TRUE, vertices = attributes(nodes))
}

save_network <- function(g, name, dir) {
  write_graph(g, file.path(dir, paste0(name, ".graphml")), format = "graphml")
  ends_ <- ends(g, E(g))
  attrs <- edge_attr(g)
  out <- data.frame(source = ends_[, 1], target = ends_[, 2])
  for (k in sort(names(attrs))) out[[k]] <- attrs[[k]]
  write.csv(out, file.path(dir, paste0(name, "_edges.csv")), row.names = FALSE)
}

network_summary <- function(networks) {
  do.call(rbind, lapply(names(networks), function(name) {
    g <- networks[[name]]
    dag <- is_directed(g) && is_dag(g)
    n <- vcount(g)
    data.frame(
      network = name, directed = is_directed(g), nodes = n, edges = ecount(g),
      density = sprintf("%.4f", edge_density(g)),
      components = components(g, mode = "weak")$no, is_dag = dag,
      longest_path = if (dag) max(longest_chain(g)) else NA)
  }))
}

# Longest path (in links) ending at each node of a DAG.
longest_chain <- function(g) {
  depth <- setNames(numeric(vcount(g)), V(g)$name)
  for (v in as_ids(topo_sort(g))) {
    before <- as_ids(neighbors(g, v, mode = "in"))
    if (length(before)) depth[v] <- 1 + max(depth[before])
  }
  depth
}

# Layer of each node in a DAG: 0 = no incoming links.
generations <- function(g) longest_chain(g)

# Professor - course network from the COSC grade sections.
instructor_network <- function(sections, attributes) {
  s <- sections[sections$Subject == "COSC" & trimws(sections$Professor) != "", ]
  s <- data.frame(prof = trimws(s$Professor), course = s[["Course Code"]])
  links <- aggregate(list(sections = rep(1, nrow(s))), s, sum)
  courses <- unique(sections[["Course Code"]][sections$Subject == "COSC" & trimws(sections$Professor) != ""])
  vertices <- attributes(courses)
  vertices$bipartite <- "course"
  profs <- vertices[rep(NA_integer_, length(unique(s$prof))), ]
  profs$name <- unique(s$prof)
  profs$bipartite <- "professor"
  graph_from_data_frame(links, directed = FALSE, vertices = rbind(vertices, profs))
}

# Course - course network, weighted by the number of shared instructors.
shared_instructor_network <- function(bipartite) {
  is_course <- V(bipartite)$bipartite == "course"
  courses <- V(bipartite)$name[is_course]
  m <- as_adjacency_matrix(bipartite, sparse = FALSE)[courses, V(bipartite)$name[!is_course]]
  shared <- tcrossprod((m > 0) * 1)
  diag(shared) <- 0
  g <- graph_from_adjacency_matrix(shared, mode = "undirected", weighted = "shared_instructors")
  vertex_attr(g) <- vertex_attr(induced_subgraph(bipartite, courses))
  g
}

GRADE_BINS <- c("<50", "50-54", "55-59", "60-63", "64-67", "68-71", "72-75",
                "76-79", "80-84", "85-89", "90-100")

# Share of students per grade bin for each COSC course with at least 30 students.
# Hidden (<6) counts are blank and treated as 0.
grade_distributions <- function(sections) {
  s <- sections[sections$Subject == "COSC", ]
  counts <- vapply(s[GRADE_BINS], num, numeric(nrow(s)))
  counts[is.na(counts)] <- 0
  total <- rowsum(counts, s[["Course Code"]])
  total <- total[rowSums(total) >= 30, ]
  total <- total[sort(rownames(total), method = "radix"), ]
  total / rowSums(total)
}

# Link each course to its k most similar grade distributions (cosine similarity).
grade_similarity_network <- function(dist, attributes, k) {
  unit <- dist / sqrt(rowSums(dist^2))
  similarity <- tcrossprod(unit)
  codes <- rownames(dist)
  links <- do.call(rbind, lapply(seq_along(codes), function(i) {
    others <- similarity[i, ]
    others[i] <- -1
    j <- order(-others)[seq_len(k)]
    data.frame(a = pmin(i, j), b = pmax(i, j))
  }))
  links <- unique(links)
  edges <- data.frame(source = codes[links$a], target = codes[links$b],
                      similarity = similarity[cbind(links$a, links$b)])
  graph_from_data_frame(edges, directed = FALSE, vertices = attributes(codes))
}
