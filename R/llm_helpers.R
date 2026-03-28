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

.validate_non_empty_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1 || !nzchar(x)) {
    stop(sprintf("`%s` must be a non-empty character string.", arg), call. = FALSE)
  }
}

.validate_character_vector <- function(x, arg) {
  if (!is.character(x) || length(x) < 1 || any(is.na(x)) || any(!nzchar(x))) {
    stop(sprintf("`%s` must be a non-empty character vector.", arg), call. = FALSE)
  }
}

.validate_named_list <- function(x, arg) {
  if (!is.list(x) || length(x) < 1) {
    stop(sprintf("`%s` must be a non-empty list.", arg), call. = FALSE)
  }
}

.resolve_model_arg <- function(model) {
  if (!is.character(model) || length(model) < 1 || any(is.na(model))) {
    stop("`model` must be a non-empty character vector.", call. = FALSE)
  }

  if (length(model) > 1) {
    return(match.arg(model))
  }

  .validate_non_empty_string(model, "model")
  model
}

.normalize_openrouter_content <- function(content) {
  if (is.character(content) && length(content) == 1) {
    return(content)
  }

  if (!is.list(content) || length(content) < 1) {
    stop("`content` must be a non-empty character string or list.", call. = FALSE)
  }

  content
}

.extract_openai_message <- function(parsed, provider) {
  if (is.null(parsed$choices) || length(parsed$choices) < 1) {
    stop(sprintf("%s API returned no choices.", provider), call. = FALSE)
  }

  message <- parsed$choices[[1]]$message

  if (is.null(message) || !is.list(message)) {
    stop(sprintf("%s API returned no message object.", provider), call. = FALSE)
  }

  message
}

.extract_openai_message_text <- function(message) {
  if (is.character(message$content) && length(message$content) == 1 && nzchar(message$content)) {
    return(message$content)
  }

  if (is.list(message$content) && length(message$content) >= 1) {
    text_parts <- lapply(message$content, function(part) {
      if (!is.null(part$text) && is.character(part$text) && length(part$text) == 1 && nzchar(part$text)) {
        return(part$text)
      }
      NULL
    })
    text_parts <- Filter(Negate(is.null), text_parts)

    if (length(text_parts) >= 1) {
      return(paste(unlist(text_parts, use.names = FALSE), collapse = "\n"))
    }
  }

  NULL
}

.extract_openai_message_image <- function(message) {
  if (!is.null(message$images) && length(message$images) >= 1) {
    image <- message$images[[1]]
    if (!is.null(image$image_url$url)) {
      return(image$image_url$url)
    }
    if (!is.null(image$data)) {
      return(image$data)
    }
  }

  if (is.list(message$content) && length(message$content) >= 1) {
    for (part in message$content) {
      if (!is.null(part$image_url$url)) {
        return(part$image_url$url)
      }
      if (!is.null(part$data)) {
        return(part$data)
      }
    }
  }

  NULL
}

.extract_openai_embedding_matrix <- function(parsed, provider) {
  if (is.null(parsed$data) || length(parsed$data) < 1) {
    stop(sprintf("%s API returned no embeddings.", provider), call. = FALSE)
  }

  embeddings <- lapply(parsed$data, function(x) x$embedding)

  if (any(vapply(embeddings, is.null, logical(1)))) {
    stop(sprintf("%s API returned an embedding without values.", provider), call. = FALSE)
  }

  lengths <- vapply(embeddings, length, integer(1))
  if (length(unique(lengths)) != 1) {
    stop(sprintf("%s API returned embeddings with inconsistent dimensions.", provider), call. = FALSE)
  }

  matrix(
    unlist(embeddings, use.names = FALSE),
    nrow = length(embeddings),
    byrow = TRUE
  )
}

.normalize_gemini_parts <- function(prompt = NULL, parts = NULL) {
  if (is.null(parts)) {
    .validate_non_empty_string(prompt, "prompt")
    return(list(list(text = prompt)))
  }

  if (!is.null(prompt)) {
    stop("Supply either `prompt` or `parts`, not both.", call. = FALSE)
  }

  if (!is.list(parts) || length(parts) < 1) {
    stop("`parts` must be a non-empty list.", call. = FALSE)
  }

  parts
}

.extract_gemini_parts <- function(parsed) {
  if (is.null(parsed$candidates) || length(parsed$candidates) < 1) {
    stop("Gemini API returned no candidates.", call. = FALSE)
  }

  parts <- parsed$candidates[[1]]$content$parts

  if (is.null(parts) || length(parts) < 1) {
    stop("Gemini API returned no content parts.", call. = FALSE)
  }

  parts
}

.extract_gemini_part <- function(parsed) {
  .extract_gemini_parts(parsed)[[1]]
}

.extract_gemini_embedding_matrix <- function(parsed) {
  if (!is.null(parsed$embedding) && !is.null(parsed$embedding$values)) {
    values <- parsed$embedding$values
    return(matrix(as.numeric(values), nrow = 1L))
  }

  if (is.null(parsed$embeddings) || length(parsed$embeddings) < 1) {
    stop("Gemini API returned no embeddings.", call. = FALSE)
  }

  embeddings <- lapply(parsed$embeddings, function(x) x$values)
  lengths <- vapply(embeddings, length, integer(1))

  if (length(unique(lengths)) != 1) {
    stop("Gemini API returned embeddings with inconsistent dimensions.", call. = FALSE)
  }

  matrix(
    as.numeric(unlist(embeddings, use.names = FALSE)),
    nrow = length(embeddings),
    byrow = TRUE
  )
}

.extract_gemini_images <- function(parsed) {
  parts <- .extract_gemini_parts(parsed)
  images <- lapply(parts, function(part) {
    if (!is.null(part$inlineData) && !is.null(part$inlineData$data)) {
      return(part$inlineData$data)
    }
    NULL
  })

  images <- Filter(Negate(is.null), images)

  if (length(images) < 1) {
    stop("Gemini API returned no image data.", call. = FALSE)
  }

  unname(unlist(images, use.names = FALSE))
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
