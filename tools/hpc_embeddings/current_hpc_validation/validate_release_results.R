#!/usr/bin/env Rscript

parse_args <- function(x) {
  out <- list()
  for (arg in x) {
    if (!startsWith(arg, "--")) next
    fields <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[gsub("-", "_", fields[[1L]])]] <- paste(fields[-1L], collapse = "=")
  }
  out
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

read_env_file <- function(path) {
  lines <- trimws(readLines(path, warn = FALSE))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  fields <- strsplit(lines, "=", fixed = TRUE)
  stats::setNames(
    vapply(fields, function(x) paste(x[-1L], collapse = "="), character(1)),
    vapply(fields, `[[`, character(1), 1L)
  )
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
run_root <- normalizePath(
  args$run_root %||% stop("--run-root is required.", call. = FALSE),
  mustWork = TRUE
)
identity_path <- normalizePath(
  args$identity %||% stop("--identity is required.", call. = FALSE),
  mustWork = TRUE
)

identity <- read_env_file(identity_path)
required_identity <- c(
  "FASTEMBEDR_RELEASE_VERSION", "FASTEMBEDR_RELEASE_COMMIT",
  "FASTEMBEDR_SOURCE_ARCHIVE_SHA256", "FASTEMBEDR_PACKAGE_TARBALL_SHA256",
  "FASTEMBEDR_DLL_SHA256", "FASTEMBEDR_IMAGE_SHA256",
  "FASTEMBEDR_BENCHMARK_COMMIT"
)
missing_identity <- setdiff(required_identity, names(identity))
if (length(missing_identity) || any(!nzchar(identity[required_identity]))) {
  stop("The validated release identity is incomplete.", call. = FALSE)
}

files <- list.files(
  run_root, pattern = "^benchmark_runs\\.csv$", recursive = TRUE,
  full.names = TRUE
)
if (!length(files)) stop("No benchmark_runs.csv files were found.", call. = FALSE)

tables <- lapply(files, function(path) {
  value <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  value$result_file <- path
  value
})
common <- Reduce(intersect, lapply(tables, names))
tables <- lapply(tables, `[`, common)
runs <- do.call(rbind, tables)
fast <- runs[startsWith(runs$method, "fastEmbedR") & runs$status == "success", , drop = FALSE]
if (!nrow(fast)) stop("No successful fastEmbedR rows were found.", call. = FALSE)

required_columns <- c(
  "fastEmbedR_version", "fastEmbedR_commit", "fastEmbedR_dll_sha256",
  "fastEmbedR_source_archive_sha256", "fastEmbedR_package_tarball_sha256",
  "fastEmbedR_image_sha256", "benchmark_commit",
  "requested_backend", "actual_backend"
)
missing_columns <- setdiff(required_columns, names(fast))
if (length(missing_columns)) {
  stop("Result identity columns are missing: ", paste(missing_columns, collapse = ", "), call. = FALSE)
}

expected <- c(
  fastEmbedR_version = identity[["FASTEMBEDR_RELEASE_VERSION"]],
  fastEmbedR_commit = identity[["FASTEMBEDR_RELEASE_COMMIT"]],
  fastEmbedR_source_archive_sha256 =
    identity[["FASTEMBEDR_SOURCE_ARCHIVE_SHA256"]],
  fastEmbedR_package_tarball_sha256 =
    identity[["FASTEMBEDR_PACKAGE_TARBALL_SHA256"]],
  fastEmbedR_dll_sha256 = identity[["FASTEMBEDR_DLL_SHA256"]],
  fastEmbedR_image_sha256 = identity[["FASTEMBEDR_IMAGE_SHA256"]],
  benchmark_commit = identity[["FASTEMBEDR_BENCHMARK_COMMIT"]]
)
for (column in names(expected)) {
  bad <- is.na(fast[[column]]) | fast[[column]] != expected[[column]]
  if (any(bad)) stop("Mixed or missing release identity in column ", column, ".", call. = FALSE)
}
if (any(is.na(fast$actual_backend) | fast$requested_backend != fast$actual_backend)) {
  stop("Requested and observed backends differ in successful fastEmbedR rows.", call. = FALSE)
}

summary <- data.frame(
  release_version = expected[["fastEmbedR_version"]],
  release_commit = expected[["fastEmbedR_commit"]],
  benchmark_commit = expected[["benchmark_commit"]],
  result_files = length(files),
  successful_fastEmbedR_rows = nrow(fast),
  backends = paste(sort(unique(fast$actual_backend)), collapse = ","),
  status = "identity_validated",
  stringsAsFactors = FALSE
)
write.csv(summary, file.path(run_root, "release_identity_validation.csv"), row.names = FALSE)
print(summary)
