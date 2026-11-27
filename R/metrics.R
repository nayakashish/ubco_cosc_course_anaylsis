# Per-course measures on the full network.

closeness_directed <- function(g, mode) {
  d <- distances(g, mode = mode)
  n <- nrow(d)
  apply(d, 1, function(row) {
    reached <- row[is.finite(row)]
    total <- sum(reached)
    if (total == 0) return(0)
    r <- length(reached)
    (r - 1) / total * (r - 1) / (n - 1)
  })
}

# Weighted adjacency of the reversed network (course -> its prerequisite).
# The weight is the fail rate of the prerequisite.
reversed_adjacency <- function(g, fail_rate = NULL) {
  a <- t(as_adjacency_matrix(g, sparse = FALSE))
  if (!is.null(fail_rate)) a <- sweep(a, 2, fail_rate[colnames(a)] / 100, "*")
  a
}

pagerank <- function(a, damping = 0.85) {
  n <- nrow(a)
  out <- rowSums(a)
  p <- a / ifelse(out == 0, 1, out)
  rank <- rep(1 / n, n)
  repeat {
    new <- damping * (as.vector(crossprod(p, rank)) + sum(rank[out == 0]) / n) + (1 - damping) / n
    if (sum(abs(new - rank)) < 1e-12) return(setNames(new, rownames(a)))
    rank <- new
  }
}

katz <- function(a, alpha = 0.1) {
  x <- solve(diag(nrow(a)) - alpha * t(a), rep(1, nrow(a)))
  setNames(x / sqrt(sum(x^2)), rownames(a))
}

course_metrics <- function(full, prereq_net, data, fail_filled, base, blocked, levels, order) {
  names_ <- V(full)$name
  n <- length(names_)
  count <- function(f) setNames(vapply(names_, f, numeric(1)), names_)
  plain <- reversed_adjacency(full)
  weighted <- reversed_adjacency(full, fail_filled)
  list(
    in_degree = degree(full, mode = "in"),
    out_degree = degree(full, mode = "out"),
    betweenness = betweenness(full, directed = TRUE) / ((n - 1) * (n - 2)),
    closeness_in = closeness_directed(full, "in"),
    closeness_out = closeness_directed(full, "out"),
    descendants = count(function(v) length(subcomponent(full, v, "out")) - 1),
    ancestors = count(function(v) length(subcomponent(full, v, "in")) - 1),
    blocked_if_removed = count(function(v) length(blocked[[v]])),
    delayed_if_removed = count(function(v) {
      without <- min_levels(order, data$prereq, removed = v)
      sum(without > levels[names(without)])
    }),
    bsc_reqs_broken = count(function(v) length(requirements_broken(data$reqs, "BSc", setdiff(base, c(blocked[[v]], v))))),
    ba_reqs_broken = count(function(v) length(requirements_broken(data$reqs, "BA", setdiff(base, c(blocked[[v]], v))))),
    min_levels = levels[names_],
    pagerank_rev = pagerank(plain),
    pagerank_rev_failw = pagerank(weighted),
    katz_rev = katz(plain),
    katz_rev_failw = katz(weighted),
    topo_generation = generations(full),
    longest_chain_to_node = longest_chain(prereq_net)[names_])
}
