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
#' @export
query_cerebras <- function(prompt, 
  model = c("llama3.1-8b", "qwen-3-235b-a22b-instruct-2507"), # it looks like they only have two models
  api_key = Sys.getenv("CEREBRAS_API_KEY"), 
  url = "https://api.cerebras.ai/v1/chat/completions",
  json_list = FALSE) {

  if (!is.character(prompt) || length(prompt) != 1 || !nzchar(prompt)) {
    stop("`prompt` must be a non-empty character string.", call. = FALSE)
  }

  if (!nzchar(api_key)) {
    stop("CEREBRAS_API_KEY is not set.", call. = FALSE)
  }

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

  res <- httr::POST(
    url,
    httr::add_headers(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = jsonlite::toJSON(body, auto_unbox = TRUE)
  )

  txt <- httr::content(res, "text", encoding = "UTF-8")

  if (httr::status_code(res) >= 300) {
    stop("Cerebras API request failed: ", txt, call. = FALSE)
  }

  json <- jsonlite::fromJSON(txt, simplifyVector = FALSE)

  if (json_list) return(json)

  if (is.null(json$choices) || length(json$choices) < 1) {
    stop("Cerebras API returned no choices.", call. = FALSE)
  }

  if (is.null(json$choices[[1]]$message)) {
    stop("Cerebras API returned no message object.", call. = FALSE)
  }

  content <- json$choices[[1]]$message$content

  if (!is.character(content) || length(content) != 1 || !nzchar(content)) {
    stop("Cerebras API returned no message content.", call. = FALSE)
  }

  content
}
