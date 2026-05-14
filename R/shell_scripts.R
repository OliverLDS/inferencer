#' Shell Script Helpers
#'
#' inferencer also ships a small optional shell layer under `inst/shell`.
#' These scripts are executable `zsh` command-line helpers that mirror common
#' R wrapper workflows:
#' `query_gemini`, `query_groq`, `query_openrouter`, `query_ollama`,
#' `query_fallback`, provider-specific `list_*_models` scripts, and
#' `render_markdown_terminal`.
#'
#' The shell scripts read API keys and defaults from shell environment
#' variables, typically configured in `.zprofile`. The variable names are
#' aligned with the R wrappers, such as `GEMINI_API_KEY`, `GROQ_API_KEY`,
#' `OPENROUTER_API_KEY`, and `OLLAMA_API_KEY`.
#'
#' They are intentionally minimal and depend on external `curl` and `jq`
#' binaries. Query scripts print the model response text by default and return
#' the full parsed JSON payload when called with `--json`. Pipe query output to
#' `render_markdown_terminal` when terminal markdown rendering is desired.
#' `query_fallback` tries `query_gemini`, then `query_openrouter`, then
#' `query_groq` using each script's default model.
#'
#' @name shell-scripts
NULL
