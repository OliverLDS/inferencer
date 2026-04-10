#' Shell Script Helpers
#'
#' inferencer also ships a small shell layer under `inst/shell/inferencer.sh`.
#' Source that file from `zsh` to access shell functions that mirror the
#' package's simple provider wrappers:
#' `query_gemini()`, `query_groq()`, `query_openrouter()`,
#' `query_cerebras()`, `query_ollama()`, `query_fallback()`, and
#' `render_markdown_terminal()`.
#'
#' The shell functions read API keys and defaults from shell environment
#' variables, typically configured in `.zprofile`. The variable names are
#' aligned with the R wrappers, such as `GEMINI_API_KEY`, `GROQ_API_KEY`,
#' `OPENROUTER_API_KEY`, `CEREBRAS_API_KEY`, and `OLLAMA_API_KEY`.
#'
#' They are intentionally minimal and depend on external `curl` and `jq`
#' binaries. Query helpers take the prompt as the first argument and an
#' optional model override as the second argument, while keeping the same
#' default models as before. Successful query helpers automatically pass the
#' returned text through `render_markdown_terminal()`.
#' `query_fallback()` tries `query_gemini()`, then `query_openrouter()`, then
#' `query_groq()` using each function's default model.
#' It prints provider-specific stderr before moving to the next fallback.
#' The Gemini shell wrapper accepts model names either with or without the
#' leading `models/` prefix.
#'
#' @name shell-scripts
NULL
