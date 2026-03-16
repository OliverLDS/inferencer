.has_free_tier <- function(model_name) {

  free_models <- c(
    "models/gemini-3.1-flash-lite-preview",
    "models/gemini-3-flash-preview",
    
    "models/gemini-2.5-pro",
    "models/gemini-2.5-flash",
    "models/gemini-2.5-flash-lite",
    "models/gemini-2.5-flash-lite-preview-09-2025",
    
    "models/gemini-2.5-flash-native-audio-preview-12-2025",
    "models/gemini-2.5-flash-preview-tts",
    
    "models/gemini-2.0-flash",
    "models/gemini-2.0-flash-lite",
    
    "models/gemini-embedding-001",
    "models/gemini-embedding-2-preview",
    
    "models/gemini-robotics-er-1.5-preview",
    
    "models/gemma-3-1b-it",
    "models/gemma-3-4b-it",
    "models/gemma-3-12b-it",
    "models/gemma-3-27b-it",
    "models/gemma-3n-e4b-it",
    "models/gemma-3n-e2b-it"
  )

  if (model_name %in% free_models) return(TRUE)
  FALSE
}

#' @export
list_gemini_models <- function(api_key = Sys.getenv("GEMINI_API_KEY"), url = "https://generativelanguage.googleapis.com/v1beta/models", raw_json = FALSE) {

  res <- jsonlite::fromJSON(
    paste0(url, "?key=", api_key),
    simplifyVector = TRUE
  )
  if (raw_json) return(res)
  data.table::rbindlist(res, fill = TRUE)
}

#' @export
query_gemini <- function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"),
  model = c("gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.5-flash-lite", "gemini-2.5-flash-preview-tts", "gemini-embedding-001", "gemma-3-27b-it", "gemma-3n-e2b-it"), # just list some common models here; if you want the complete list of free models, you can rs <- list_gemini_models(); rs[sapply(rs$name, .has_free_tier), name]
  url0 = Sys.getenv("GEMINI_API_URL", unset = "https://generativelanguage.googleapis.com/v1beta/models"),
  temperature = 0.7, top_p = 1, top_k = 40, max_tokens = NULL, 
  raw_json = FALSE) {

  model <- match.arg(model)
  
  url <- sprintf("%s/%s:generateContent?key=%s", url0, model, api_key)
  
  body <- list(
    contents = list(list(
      role = "user",
      parts = list(list(text = prompt))
    )),
    generationConfig = list(
      temperature = temperature,
      topP = top_p,
      topK = top_k
    )
  )

  if (!is.null(max_tokens)) {
    body$generationConfig$maxOutputTokens <- max_tokens
  }

  response <- httr::POST(
    url,
    httr::add_headers(`Content-Type` = "application/json"),
    body = jsonlite::toJSON(body, auto_unbox = TRUE),
    encode = "raw"
  )
  
  if (raw_json) return(response)

  if (httr::status_code(response) != 200) {
    stop("Gemini API request failed: ", httr::content(response, as = "text"))
  }

  parsed <- httr::content(response, as = "parsed", type = "application/json")
  return(parsed$candidates[[1]]$content$parts[[1]]$text)
}
