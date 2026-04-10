#' Query Providers with Ordered Fallback
#'
#' Tries the package's text-query wrappers in order until one succeeds:
#' `query_gemini()`, then `query_openrouter()`, then `query_groq()`.
#'
#' @param prompt A non-empty character string.
#' @param json_list If `TRUE`, return a list containing the successful provider
#'   name and parsed response object.
#' @param api_key_gemini Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param api_key_openrouter OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param api_key_groq Groq API key. Defaults to `Sys.getenv("GROQ_API_KEY")`.
#'
#' @return A character string by default. When `json_list = TRUE`, returns a
#'   list with elements `provider` and `response`.
#' @export
query_fallback <- function(
  prompt,
  json_list = FALSE,
  api_key_gemini = Sys.getenv("GEMINI_API_KEY"),
  api_key_openrouter = Sys.getenv("OPENROUTER_API_KEY"),
  api_key_groq = Sys.getenv("GROQ_API_KEY")
) {
  .validate_non_empty_string(prompt, "prompt")

  attempts <- list(
    list(
      provider = "gemini",
      fn = function() {
        query_gemini(
          prompt = prompt,
          api_key = api_key_gemini,
          json_list = json_list
        )
      }
    ),
    list(
      provider = "openrouter",
      fn = function() {
        query_openrouter(
          prompt = prompt,
          api_key = api_key_openrouter,
          json_list = json_list
        )
      }
    ),
    list(
      provider = "groq",
      fn = function() {
        query_groq(
          prompt = prompt,
          api_key = api_key_groq,
          json_list = json_list
        )
      }
    )
  )

  failures <- character(0)

  for (attempt in attempts) {
    result <- tryCatch(
      attempt$fn(),
      error = function(e) e
    )

    if (!inherits(result, "error")) {
      if (json_list) {
        return(list(
          provider = attempt$provider,
          response = result
        ))
      }

      return(result)
    }

    failures <- c(
      failures,
      sprintf("%s: %s", attempt$provider, conditionMessage(result))
    )
  }

  stop(
    sprintf(
      "All fallback providers failed. %s",
      paste(failures, collapse = " | ")
    ),
    call. = FALSE
  )
}
