#' List OpenRouter Models
#'
#' Retrieves available models from the OpenRouter models endpoint.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_openrouter_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  if (!nzchar(api_key)) {
    stop("OPENROUTER_API_KEY is not set.", call. = FALSE)
  }
  
  response <- curl::curl_fetch_memory(
    url,
    handle = curl::new_handle(
      httpheader = c(
        "Authorization" = paste("Bearer", api_key)
      )
    )
  )

  txt <- rawToChar(response$content)

  if (response$status_code >= 300) {
    stop("OpenRouter API request failed: ", txt, call. = FALSE)
  }
  
  res <- jsonlite::fromJSON(txt, simplifyVector = FALSE)

  if (!is.null(res$error)) {
    if (!is.null(res$error$message) && nzchar(res$error$message)) {
      msg <- res$error$message
    } else {
      msg <- "Unknown API error."
    }
    stop(sprintf("OpenRouter API error: %s", msg), call. = FALSE)
  }

  if (json_list) return(res)
  
  if (!"data" %in% names(res)) {
    stop("Response does not contain a 'data' field.", call. = FALSE)
  }
  
  # need to handle nested list strucutre which may contain different number of items across models
  rows <- lapply(res$data, function(x) {
    x$architecture <- list(x$architecture)
    x$pricing <- list(x$pricing)
    x$top_provider <- list(x$top_provider)
    x$per_request_limits <- list(x$per_request_limits)
    x$supported_parameters <- list(x$supported_parameters)
    x$default_parameters <- list(x$default_parameters)
  
    for (nm in names(x)) {
      if (length(x[[nm]]) == 0) {
        x[[nm]] <- NA
      }
    }
  
    x
  })
  
  data.table::rbindlist(rows, fill = TRUE)
}

#' Query an OpenRouter Chat Model
#'
#' Sends a single user prompt to the OpenRouter chat completions API.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param reasoning Whether to enable reasoning mode.
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
query_openrouter <- function(
  prompt,
  model = c("openrouter/hunter-alpha", "stepfun/step-3.5-flash:free", "arcee-ai/trinity-large-preview:free", "meta-llama/llama-3.3-70b-instruct:free", 'openrouter/healer-alpha', 'z-ai/glm-4.5-air:free'), # not complete; you can get complete free model list by: rs <- list_openrouter_models; rs[rs$pricing.prompt <= 0, ]
  temperature = 0,
  top_p = 1,
  max_tokens = 512L,
  reasoning = TRUE,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE
) {
  if (!is.character(prompt) || length(prompt) != 1 || !nzchar(prompt)) {
    stop("`prompt` must be a non-empty character string.", call. = FALSE)
  }
  if (!nzchar(api_key)) stop("OPENROUTER_API_KEY is not set.", call. = FALSE)

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

  if (!is.logical(reasoning) || length(reasoning) != 1 || is.na(reasoning)) {
    stop("`reasoning` must be TRUE or FALSE.", call. = FALSE)
  }
    
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
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  txt <- httr2::resp_body_string(resp)
  json <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  
  if (httr2::resp_status(resp) >= 300) {
    if (!is.null(json$error) && !is.null(json$error$message) && nzchar(json$error$message)) {
      stop(sprintf("OpenRouter API error: %s", json$error$message), call. = FALSE)
    }
    stop("OpenRouter API request failed: ", txt, call. = FALSE)
  }

  if (!is.null(json$error)) {
    if (!is.null(json$error$message) && nzchar(json$error$message)) {
      msg <- json$error$message
    } else {
      msg <- "Unknown API error."
    }
    stop(sprintf("OpenRouter API error: %s", msg), call. = FALSE)
  }

  if (json_list) return(json)

  if (is.null(json$choices) || length(json$choices) < 1) {
    stop("API returned no choices.", call. = FALSE)
  }

  if (is.null(json$choices[[1]]$message)) {
    stop("API returned no message object.", call. = FALSE)
  }

  content <- json$choices[[1]]$message$content

  if (!is.character(content) || length(content) != 1 || !nzchar(content)) {
    stop("API returned no message content.", call. = FALSE)
  }

  content
}
