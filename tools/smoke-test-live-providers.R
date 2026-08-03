#!/usr/bin/env Rscript

options(warn = 1)

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("Install devtools to run the live provider smoke tests.", call. = FALSE)
}

Sys.setenv(INFERENCER_LIVE_TESTS = "true")
devtools::load_all(quiet = TRUE)

result <- testthat::test_file("tests/testthat/test-live-providers.R")
expectations <- unlist(lapply(result, `[[`, "results"), recursive = FALSE)
unsuccessful <- vapply(
  expectations,
  inherits,
  logical(1),
  what = c("expectation_failure", "expectation_error", "expectation_skip")
)
if (any(unsuccessful)) {
  quit(status = 1L)
}
