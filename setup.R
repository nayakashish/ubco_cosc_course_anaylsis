# Run once: installs the packages the project uses.
packages <- c("igraph", "ggplot2")  # analysis and figures
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
cat("Packages ready:", paste(packages, collapse = ", "), "\n")
