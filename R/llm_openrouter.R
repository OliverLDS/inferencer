#' List OpenRouter Models
#'
#' Retrieves available models from the OpenRouter models endpoint.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_openrouter_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  .require_api_key(api_key, "OPENROUTER_API_KEY")

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Authorization" = paste("Bearer", api_key)
    )
  )
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  res <- parsed$json

  if (json_list) return(res)
  
  if (!"data" %in% names(res)) {
    stop("Response does not contain a 'data' field.", call. = FALSE)
  }
  
  .openrouter_model_rows(res$data)
}

#' Query an OpenRouter Chat Model
#'
#' Sends a single user prompt to the OpenRouter chat completions API.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param reasoning Whether to enable reasoning mode.
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
query_openrouter <- function(
  prompt,
  model = "openrouter/free", # other current free options can be inspected from list_openrouter_models()
  temperature = 0,
  top_p = 1,
  max_tokens = 2048L,
  reasoning = TRUE,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE
) {
  query_openrouter_content(
    content = prompt,
    model = model,
    temperature = temperature,
    top_p = top_p,
    max_tokens = max_tokens,
    reasoning = reasoning,
    api_key = api_key,
    url = url,
    json_list = json_list
  )
}
