#' @export
query_cerebras <- function(prompt, 
  model = c("llama3.1-8b", "qwen-3-235b-a22b-instruct-2507"), # it looks like they only have two models
  api_key = Sys.getenv("CEREBRAS_API_KEY"), 
  url = "https://api.cerebras.ai/v1/chat/completions",
  raw_json = FALSE) {

  api_key <- api_key
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

  json <- jsonlite::fromJSON(httr::content(res, "text", encoding = "UTF-8"))

  if (raw_json) return(json)
  json$choices$message$content
}