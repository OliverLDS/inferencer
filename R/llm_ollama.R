#' List Ollama Cloud Models
#'
#' Retrieves available models from the Ollama Cloud tags endpoint.
#'
#' @param api_key Ollama API key. Defaults to `Sys.getenv("OLLAMA_API_KEY")`.
#' @param url Ollama Cloud tags endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_ollama_models <- function(
  api_key = Sys.getenv("OLLAMA_API_KEY"),
  url = "https://ollama.com/api/tags",
  json_list = FALSE
) {
  .require_api_key(api_key, "OLLAMA_API_KEY")

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Authorization" = paste("Bearer", api_key)
    )
  )
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "Ollama API request failed: ", "Ollama API error")
  res <- parsed$json

  if (json_list) {
    return(res)
  }

  if (is.null(res$models)) {
    stop("Ollama API response does not contain a `models` field.", call. = FALSE)
  }

  rows <- lapply(res$models, function(x) {
    x$details <- list(x$details)
    x$model_info <- list(x$model_info)

    for (nm in names(x)) {
      if (length(x[[nm]]) == 0) {
        x[[nm]] <- NA
      }
    }

    x
  })

  data.table::rbindlist(rows, fill = TRUE)
}

#' Query an Ollama Cloud Chat Model
#'
#' Sends a single user prompt to the Ollama Cloud chat API.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param api_key Ollama API key. Defaults to `Sys.getenv("OLLAMA_API_KEY")`.
#' @param url Ollama Cloud chat endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
query_ollama <- function(
  prompt,
  model = "gpt-oss:120b",
  api_key = Sys.getenv("OLLAMA_API_KEY"),
  url = "https://ollama.com/api/chat",
  json_list = FALSE
) {
  .validate_non_empty_string(prompt, "prompt")
  .require_api_key(api_key, "OLLAMA_API_KEY")
  model <- .resolve_model_arg(model)

  body <- list(
    model = model,
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    ),
    stream = FALSE
  )

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(response, parsed_resp, "Ollama API request failed: ", "Ollama API error")
  parsed <- parsed_resp$json

  if (json_list) {
    return(parsed)
  }

  if (is.null(parsed$message) || !is.list(parsed$message)) {
    stop("Ollama API returned no message object.", call. = FALSE)
  }

  content <- parsed$message$content

  if (!is.character(content) || length(content) != 1 || !nzchar(content)) {
    stop("Ollama API returned no message content.", call. = FALSE)
  }

  content
}
