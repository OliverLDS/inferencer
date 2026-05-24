#' Query a Cerebras Chat Model
#'
#' Sends a single user prompt to the Cerebras chat completions API.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param api_key Cerebras API key. Defaults to `Sys.getenv("CEREBRAS_API_KEY")`.
#' @param url Cerebras chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @seealso [list_cerebras_models()]
#' @export
query_cerebras <- function(prompt,
  model = c("gpt-oss-120b", "zai-glm-4.7", "llama3.1-8b", "qwen-3-235b-a22b-instruct-2507"),
  api_key = Sys.getenv("CEREBRAS_API_KEY"),
  url = "https://api.cerebras.ai/v1/chat/completions",
  json_list = FALSE) {

  if (!is.character(prompt) || length(prompt) != 1 || !nzchar(prompt)) {
    stop("`prompt` must be a non-empty character string.", call. = FALSE)
  }

  .require_api_key(api_key, "CEREBRAS_API_KEY")

  model <- match.arg(model)

  body <- list(
    model = model,
    stream = FALSE,
    messages = list(list(role = "user", content = prompt)),
    temperature = 0,
    max_tokens = -1,
    seed = 0,
    top_p = 1
  )

  res <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed <- .parse_json_response(res)
  .stop_for_json_response(res, parsed, "Cerebras API request failed: ", NULL)
  json <- parsed$json

  if (json_list) return(json)
  .extract_openai_chat_content(json, "Cerebras")
}

#' List Cerebras Models
#'
#' Retrieves available models from the public Cerebras models endpoint.
#'
#' @param url Cerebras public models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_cerebras_models <- function(
  url = "https://api.cerebras.ai/public/v1/models",
  json_list = FALSE
) {
  response <- .perform_json_request(url = url)
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "Cerebras API request failed: ", "Cerebras API error")
  res <- parsed$json

  if (json_list) {
    return(res)
  }

  if (is.null(res$data)) {
    stop("Cerebras API response does not contain a `data` field.", call. = FALSE)
  }

  data.table::rbindlist(res$data, fill = TRUE)
}
