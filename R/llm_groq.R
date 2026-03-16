#' @export
list_groq_models <- function(api_key = Sys.getenv("GROQ_API_KEY"), url = "https://api.groq.com/openai/v1/models", raw_json = FALSE) {
  
  response <- httr2::request(url) |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_perform()
  if (raw_json) return(response)
  
  response_dt <- lapply(httr2::resp_body_json(response)$data, function(x) {x$public_apps <- NULL; x}) # public_apps field has problem
  data.table::rbindlist(response_dt, fill = TRUE)
}

#' @export
query_groq <- function(prompt, api_key = Sys.getenv("GROQ_API_KEY"),
  url = Sys.getenv("GROQ_API_URL", unset = "https://api.groq.com/openai/v1/chat/completions"),
  model = c("groq/compound", "allam-2-7b", "groq/compound-mini", "qwen/qwen3-32b", "openai/gpt-oss-20b", "canopylabs/orpheus-v1-english", "openai/gpt-oss-120b", "whisper-large-v3", "llama-3.3-70b-versatile", "moonshotai/kimi-k2-instruct-0905", "whisper-large-v3-turbo", "meta-llama/llama-prompt-guard-2-86m", "moonshotai/kimi-k2-instruct", "meta-llama/llama-prompt-guard-2-22m", "meta-llama/llama-4-scout-17b-16e-instruct", "openai/gpt-oss-safeguard-20b", "llama-3.1-8b-instant", "canopylabs/orpheus-arabic-saudi"),
  temperature = 1.0, top_p = 1.0, max_tokens = 1024, 
  stream = FALSE, raw_json = FALSE) {

  model <- match.arg(model)

  body <- list(
    messages = list(list(role = "user", content = prompt)),
    model = model,
    temperature = temperature,
    top_p = top_p,
    stream = stream,
    max_tokens = max_tokens
  )

  response <- httr::POST(
    url,
    httr::add_headers(
      "Content-Type" = "application/json",
      Authorization = paste("Bearer", api_key)
    ),
    body = jsonlite::toJSON(body, auto_unbox = TRUE),
    encode = "json"
  )

  if (raw_json) return(response)
  parsed <- httr::content(response, as = "parsed", encoding = "UTF-8")
  text <- parsed$choices[[1]]$message$content
  return(text)
}


