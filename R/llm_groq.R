#' List Groq Models
#'
#' Retrieves available models from the Groq models endpoint.
#'
#' @param api_key Groq API key. Defaults to `Sys.getenv("GROQ_API_KEY")`.
#' @param url Groq models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_groq_models <- function(api_key = Sys.getenv("GROQ_API_KEY"), url = "https://api.groq.com/openai/v1/models", json_list = FALSE) {
  .require_api_key(api_key, "GROQ_API_KEY")

  response <- .perform_json_request(
    url = url,
    headers = list(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    )
  )
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(response, parsed_resp, "Groq API request failed: ", "Groq API error")
  parsed <- parsed_resp$json

  if (json_list) return(parsed)

  if (is.null(parsed$data)) {
    stop("Groq API response does not contain a `data` field.", call. = FALSE)
  }

  response_dt <- lapply(parsed$data, function(x) {x$public_apps <- NULL; x}) # public_apps field has problem
  data.table::rbindlist(response_dt, fill = TRUE)
}

#' Query a Groq Chat Model
#'
#' Sends a single user prompt to the Groq chat completions API.
#'
#' @param prompt A non-empty character string.
#' @param api_key Groq API key. Defaults to `Sys.getenv("GROQ_API_KEY")`.
#' @param url Groq chat completions endpoint.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param stream Whether to request streaming output.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
query_groq <- function(prompt, api_key = Sys.getenv("GROQ_API_KEY"),
  url = Sys.getenv("GROQ_API_URL", unset = "https://api.groq.com/openai/v1/chat/completions"),
  model = c("groq/compound", "allam-2-7b", "groq/compound-mini", "qwen/qwen3-32b", "openai/gpt-oss-20b", "canopylabs/orpheus-v1-english", "openai/gpt-oss-120b", "whisper-large-v3", "llama-3.3-70b-versatile", "moonshotai/kimi-k2-instruct-0905", "whisper-large-v3-turbo", "meta-llama/llama-prompt-guard-2-86m", "moonshotai/kimi-k2-instruct", "meta-llama/llama-prompt-guard-2-22m", "meta-llama/llama-4-scout-17b-16e-instruct", "openai/gpt-oss-safeguard-20b", "llama-3.1-8b-instant", "canopylabs/orpheus-arabic-saudi"),
  temperature = 1.0, top_p = 1.0, max_tokens = 1024, 
  stream = FALSE, json_list = FALSE) {

  if (!is.character(prompt) || length(prompt) != 1 || !nzchar(prompt)) {
    stop("`prompt` must be a non-empty character string.", call. = FALSE)
  }

  .require_api_key(api_key, "GROQ_API_KEY")

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

  if (!is.logical(stream) || length(stream) != 1 || is.na(stream)) {
    stop("`stream` must be TRUE or FALSE.", call. = FALSE)
  }

  model <- match.arg(model)

  body <- list(
    messages = list(list(role = "user", content = prompt)),
    model = model,
    temperature = temperature,
    top_p = top_p,
    stream = stream,
    max_tokens = max_tokens
  )

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      Authorization = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(response, parsed_resp, "Groq API request failed: ", NULL)
  parsed <- parsed_resp$json

  if (json_list) return(parsed)
  .extract_openai_chat_content(parsed, "Groq")
}
