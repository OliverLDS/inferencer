#' @export
list_openrouter_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  raw_json = FALSE
) {
  
  txt <- rawToChar(
    curl::curl_fetch_memory(
      url,
      handle = curl::new_handle(
        httpheader = c(
          "Authorization" = paste("Bearer", api_key)
        )
      )
    )$content
  )
  
  if (raw_json) return(txt)
  
  res <- jsonlite::fromJSON(txt, simplifyDataFrame = TRUE)
  
  if (!"data" %in% names(res)) {
    stop("Response does not contain a 'data' field.")
  }
  
  data.table::as.data.table(res$data)
}

#' @export
query_openrouter <- function(
  prompt,
  model = c("openrouter/hunter-alpha", "stepfun/step-3.5-flash:free", "arcee-ai/trinity-large-preview:free", "meta-llama/llama-3.3-70b-instruct:free", 'openrouter/healer-alpha', 'z-ai/glm-4.5-air:free'), # not complete; you can get complete free model list by: rs <- list_openrouter_models; rs[rs$pricing.prompt <= 0, ]
  temperature = 0,
  top_p = 1,
  max_tokens = 512L,
  reasoning = "true",
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  raw_json = FALSE
) {
  if (!nzchar(prompt)) stop('Usage: query_openrouter("your prompt")', call. = FALSE)
  if (!nzchar(api_key)) stop("OPENROUTER_API_KEY is not set.", call. = FALSE)
    
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

  resp <- httr2::request(url) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_perform()

  txt <- httr2::resp_body_string(resp)
  json <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  
  if (raw_json) return(json)

  if (!is.null(json$error)) {
    if (!is.null(json$error$message) && nzchar(json$error$message)) {
      msg <- json$error$message
    } else {
      msg <- "Unknown API error."
    }
    stop(sprintf("OpenRouter API error: %s", msg), call. = FALSE)
  }

  if (is.null(json$choices) || length(json$choices) < 1) {
    stop("API returned no choices.", call. = FALSE)
  }

  if (is.null(json$choices[[1]]$message)) {
    stop("API returned no message object.", call. = FALSE)
  }

  content <- json$choices[[1]]$message$content

  if (is.null(content) || !nzchar(content)) {
    stop("API returned no message content.", call. = FALSE)
  }

  content
}