.require_api_key <- function(api_key, env_name) {
  if (!nzchar(api_key)) {
    stop(sprintf("%s is not set.", env_name), call. = FALSE)
  }
}

.perform_json_request <- function(url, headers = NULL, body = NULL) {
  req <- httr2::request(url)

  if (!is.null(headers) && length(headers) > 0) {
    req <- do.call(httr2::req_headers, c(list(req), headers))
  }

  if (!is.null(body)) {
    req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  }

  req |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
}

.parse_json_response <- function(response) {
  txt <- httr2::resp_body_string(response)

  list(
    text = txt,
    json = jsonlite::fromJSON(txt, simplifyVector = FALSE)
  )
}

.api_error_message <- function(json) {
  if (!is.null(json$error) && !is.null(json$error$message) && nzchar(json$error$message)) {
    return(json$error$message)
  }

  NULL
}

.stop_for_json_response <- function(response, parsed, request_failed_prefix, api_error_prefix = NULL) {
  if (httr2::resp_status(response) >= 300) {
    msg <- .api_error_message(parsed$json)

    if (!is.null(msg) && !is.null(api_error_prefix)) {
      stop(sprintf("%s: %s", api_error_prefix, msg), call. = FALSE)
    }

    stop(request_failed_prefix, parsed$text, call. = FALSE)
  }

  msg <- .api_error_message(parsed$json)
  if (!is.null(msg) && !is.null(api_error_prefix)) {
    stop(sprintf("%s: %s", api_error_prefix, msg), call. = FALSE)
  }
}

.extract_openai_chat_content <- function(parsed, provider) {
  if (is.null(parsed$choices) || length(parsed$choices) < 1) {
    stop(sprintf("%s API returned no choices.", provider), call. = FALSE)
  }

  if (is.null(parsed$choices[[1]]$message)) {
    stop(sprintf("%s API returned no message object.", provider), call. = FALSE)
  }

  content <- parsed$choices[[1]]$message$content

  if (!is.character(content) || length(content) != 1 || !nzchar(content)) {
    stop(sprintf("%s API returned no message content.", provider), call. = FALSE)
  }

  content
}

.openrouter_model_rows <- function(models) {
  rows <- lapply(models, function(x) {
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
