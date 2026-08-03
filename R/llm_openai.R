#' List OpenAI Models
#'
#' Retrieves models available to the current OpenAI API key.
#'
#' @param api_key OpenAI API key. Defaults to `Sys.getenv("OPENAI_API_KEY")`.
#' @param url OpenAI models endpoint.
#' @param json_list If `TRUE`, return the complete parsed JSON response as a
#'   list.
#'
#' @return A `data.table` by default, or the complete parsed JSON response when
#'   `json_list = TRUE`.
#' @export
list_openai_models <- function(
  api_key = Sys.getenv("OPENAI_API_KEY"),
  url = "https://api.openai.com/v1/models",
  json_list = FALSE
) {
  .require_api_key(api_key, "OPENAI_API_KEY")

  parsed <- .openai_json_request(
    url = url,
    api_key = api_key,
    body = NULL,
    provider = "OpenAI",
    api_error_prefix = "OpenAI API error"
  )

  if (json_list) return(parsed)
  if (is.null(parsed$data) || !is.list(parsed$data)) {
    stop("OpenAI API response does not contain a `data` list.", call. = FALSE)
  }

  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query an OpenAI Model with the Responses API
#'
#' Sends a request directly to OpenAI's Responses API. The input may be a
#' simple text prompt or a structured Responses API input list for multimodal
#' and multi-message workflows.
#'
#' @param input A non-empty character string or structured Responses API input
#'   list.
#' @param model Model identifier.
#' @param instructions Optional system or developer instructions.
#' @param max_output_tokens Optional maximum number of generated tokens,
#'   including visible output and reasoning tokens.
#' @param temperature Optional sampling temperature.
#' @param top_p Optional nucleus sampling parameter.
#' @param tools Optional list of Responses API tool definitions.
#' @param api_key OpenAI API key. Defaults to `Sys.getenv("OPENAI_API_KEY")`.
#' @param url OpenAI Responses endpoint.
#' @param json_list If `TRUE`, return the complete parsed JSON response as a
#'   list.
#'
#' @return A character string containing the response text by default, or the
#'   complete parsed JSON response when `json_list = TRUE`.
#' @export
query_openai <- function(
  input,
  model = "gpt-5.6",
  instructions = NULL,
  max_output_tokens = NULL,
  temperature = NULL,
  top_p = NULL,
  tools = NULL,
  api_key = Sys.getenv("OPENAI_API_KEY"),
  url = Sys.getenv("OPENAI_API_URL", unset = "https://api.openai.com/v1/responses"),
  json_list = FALSE
) {
  input <- .normalize_openai_responses_input(input)
  .require_api_key(api_key, "OPENAI_API_KEY")
  model <- .resolve_model_arg(model)

  if (!is.null(instructions)) {
    .validate_non_empty_string(instructions, "instructions")
  }

  if (!is.null(max_output_tokens)) {
    if (!is.numeric(max_output_tokens) || length(max_output_tokens) != 1 ||
        is.na(max_output_tokens) || max_output_tokens < 1 ||
        max_output_tokens != as.integer(max_output_tokens)) {
      stop("`max_output_tokens` must be NULL or a single positive integer.", call. = FALSE)
    }
    max_output_tokens <- as.integer(max_output_tokens)
  }

  if (!is.null(temperature)) {
    if (!is.numeric(temperature) || length(temperature) != 1 || is.na(temperature) || temperature < 0) {
      stop("`temperature` must be NULL or a single non-negative numeric value.", call. = FALSE)
    }
  }

  if (!is.null(top_p)) {
    if (!is.numeric(top_p) || length(top_p) != 1 || is.na(top_p) || top_p < 0 || top_p > 1) {
      stop("`top_p` must be NULL or a single numeric value between 0 and 1.", call. = FALSE)
    }
  }

  if (!is.null(tools) && (!is.list(tools) || length(tools) < 1)) {
    stop("`tools` must be NULL or a non-empty list.", call. = FALSE)
  }

  body <- list(model = model, input = input)
  if (!is.null(instructions)) body$instructions <- instructions
  if (!is.null(max_output_tokens)) body$max_output_tokens <- max_output_tokens
  if (!is.null(temperature)) body$temperature <- temperature
  if (!is.null(top_p)) body$top_p <- top_p
  if (!is.null(tools)) body$tools <- tools

  parsed <- .openai_json_request(
    url = url,
    api_key = api_key,
    body = body,
    provider = "OpenAI",
    api_error_prefix = "OpenAI API error"
  )

  if (json_list) return(parsed)
  .extract_openai_response_text(parsed)
}
