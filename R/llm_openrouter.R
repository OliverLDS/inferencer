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
  model = c("openrouter/hunter-alpha", "stepfun/step-3.5-flash:free", "arcee-ai/trinity-large-preview:free", "meta-llama/llama-3.3-70b-instruct:free", 'openrouter/healer-alpha', 'z-ai/glm-4.5-air:free'), # not complete; you can get complete free model list by: rs <- list_openrouter_models; rs[rs$pricing.prompt <= 0, ]
  temperature = 0,
  top_p = 1,
  max_tokens = 512L,
  reasoning = TRUE,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE
) {
  if (!is.character(prompt) || length(prompt) != 1 || !nzchar(prompt)) {
    stop("`prompt` must be a non-empty character string.", call. = FALSE)
  }
  .require_api_key(api_key, "OPENROUTER_API_KEY")

  if (!is.numeric(temperature) || length(temperature) != 1 || is.na(temperature)) {
    stop("`temperature` must be a single numeric value.", call. = FALSE)
  }

  if (temperature < 0) {
    stop("`temperature` must be greater than or equal to 0.", call. = FALSE)
  }

  if (!is.numeric(top_p) || length(top_p) != 1 || is.na(top_p)) {
    stop("`top_p` must be a single numeric value.", call. = FALSE)
  }

  if (top_p < 0 || top_p > 1) {
    stop("`top_p` must be between 0 and 1.", call. = FALSE)
  }

  if (!is.numeric(max_tokens) || length(max_tokens) != 1 || is.na(max_tokens) || max_tokens < 1) {
    stop("`max_tokens` must be a single positive number.", call. = FALSE)
  }

  if (!is.logical(reasoning) || length(reasoning) != 1 || is.na(reasoning)) {
    stop("`reasoning` must be TRUE or FALSE.", call. = FALSE)
  }
    
  model <- match.arg(model)

  body <- list(
    model = model,
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    ),
    temperature = temperature,
    top_p = top_p,
    max_tokens = max_tokens,
    reasoning = list(
      enabled = reasoning
    )
  )

  resp <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed <- .parse_json_response(resp)
  .stop_for_json_response(resp, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  json <- parsed$json

  if (json_list) return(json)
  .extract_openai_chat_content(json, "OpenRouter")
}
