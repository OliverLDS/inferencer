#' List Models from an OpenAI-Compatible Server
#'
#' Retrieves models from an OpenAI-compatible `/v1/models` endpoint. This is
#' suitable for local or self-hosted servers such as `llama.cpp`, vLLM, LM
#' Studio, LocalAI, and compatible deployments. Authentication is optional.
#'
#' @param url OpenAI-compatible models endpoint.
#' @param api_key Optional bearer token. Use `NULL` for an unauthenticated
#'   local server.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_openai_compatible_models <- function(
  url = "http://127.0.0.1:8080/v1/models",
  api_key = NULL,
  json_list = FALSE,
  timeout = 120
) {
  .validate_non_empty_string(url, "url")
  .validate_optional_api_key(api_key)

  headers <- if (is.null(api_key)) NULL else list(Authorization = paste("Bearer", api_key))
  response <- .perform_json_request(url = url, headers = headers, timeout = timeout)
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(
    response,
    parsed_resp,
    "OpenAI-compatible server request failed: ",
    "OpenAI-compatible server error",
    sensitive_values = api_key
  )
  parsed <- parsed_resp$json

  if (json_list) return(parsed)
  if (is.null(parsed$data) || !is.list(parsed$data)) {
    stop("OpenAI-compatible server response does not contain a `data` list.", call. = FALSE)
  }

  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query an OpenAI-Compatible Chat Server
#'
#' Sends a prompt to an OpenAI-compatible `/v1/chat/completions` endpoint.
#' This is suitable for local or self-hosted servers such as `llama.cpp`,
#' vLLM, LM Studio, LocalAI, and compatible deployments. Authentication is
#' optional. `response_format` is forwarded unchanged, allowing servers that
#' support JSON-schema constrained output to use their native request shape.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param system Optional system prompt.
#' @param response_format Optional OpenAI-compatible response-format object.
#' @param temperature Optional sampling temperature.
#' @param max_tokens Optional maximum number of output tokens.
#' @param url OpenAI-compatible chat completions endpoint.
#' @param api_key Optional bearer token. Use `NULL` for an unauthenticated
#'   local server.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
query_openai_compatible <- function(
  prompt,
  model,
  system = NULL,
  response_format = NULL,
  temperature = NULL,
  max_tokens = NULL,
  url = "http://127.0.0.1:8080/v1/chat/completions",
  api_key = NULL,
  timeout = 120,
  json_list = FALSE
) {
  .validate_non_empty_string(prompt, "prompt")
  model <- .resolve_model_arg(model)
  .validate_non_empty_string(url, "url")
  .validate_optional_api_key(api_key)

  if (!is.null(system)) .validate_non_empty_string(system, "system")
  if (!is.null(response_format) && !is.list(response_format)) {
    stop("`response_format` must be NULL or a list.", call. = FALSE)
  }
  if (!is.null(temperature) && (!is.numeric(temperature) || length(temperature) != 1 ||
      is.na(temperature) || temperature < 0)) {
    stop("`temperature` must be NULL or a single non-negative numeric value.", call. = FALSE)
  }
  if (!is.null(max_tokens) && (!is.numeric(max_tokens) || length(max_tokens) != 1 ||
      is.na(max_tokens) || max_tokens < 1 || max_tokens != as.integer(max_tokens))) {
    stop("`max_tokens` must be NULL or a single positive integer.", call. = FALSE)
  }

  messages <- list(list(role = "user", content = prompt))
  if (!is.null(system)) {
    messages <- c(list(list(role = "system", content = system)), messages)
  }

  parameters <- list()
  if (!is.null(response_format)) parameters$response_format <- response_format
  if (!is.null(temperature)) parameters$temperature <- temperature
  if (!is.null(max_tokens)) parameters$max_tokens <- as.integer(max_tokens)

  parsed <- .openai_compatible_chat_request(
    url = url,
    api_key = api_key,
    provider = "OpenAI-compatible server",
    model = model,
    messages = messages,
    parameters = parameters,
    api_error_prefix = "OpenAI-compatible server error",
    timeout = timeout
  )

  if (json_list) return(parsed)
  .extract_openai_chat_content(parsed, "OpenAI-compatible server")
}
