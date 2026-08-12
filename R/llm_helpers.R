.require_api_key <- function(api_key, env_name) {
  if (!nzchar(api_key)) {
    stop(sprintf("%s is not set.", env_name), call. = FALSE)
  }
}

.validate_timeout <- function(timeout) {
  if (!is.numeric(timeout) || length(timeout) != 1 || is.na(timeout) ||
      !is.finite(timeout) || timeout <= 0) {
    stop("`timeout` must be a single positive number of seconds.", call. = FALSE)
  }

  timeout
}

.redact_sensitive_text <- function(text, values = NULL) {
  if (is.null(text)) return(NULL)
  if (is.null(values)) return(text)

  values <- unique(as.character(values))
  values <- values[!is.na(values) & nchar(values) >= 8]
  for (value in values) {
    text <- gsub(value, "[REDACTED]", text, fixed = TRUE)
  }

  text
}

.perform_json_request <- function(url, headers = NULL, body = NULL, timeout = 120) {
  timeout <- .validate_timeout(timeout)
  req <- httr2::request(url)

  if (!is.null(headers) && length(headers) > 0) {
    req <- do.call(httr2::req_headers, c(list(req), headers))
  }

  if (!is.null(body)) {
    req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  }

  # Mocked requests in unit tests are not httr2 request objects.
  if (inherits(req, "httr2_request")) {
    req <- httr2::req_timeout(req, seconds = timeout)
  }

  req |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
}

.openai_json_request <- function(
  url,
  api_key,
  body,
  provider,
  stream = FALSE,
  headers = NULL,
  api_error_prefix = NULL,
  timeout = 120
) {
  request_headers <- c(
    list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    headers
  )

  response <- .perform_json_request(
    url = url,
    headers = request_headers,
    body = body,
    timeout = timeout
  )

  if (httr2::resp_status(response) >= 300 || !stream) {
    parsed <- .parse_json_response(response)
    .stop_for_json_response(
      response,
      parsed,
      paste0(provider, " API request failed: "),
      api_error_prefix,
      sensitive_values = api_key
    )
    return(parsed$json)
  }

  chunks <- .parse_openai_sse_response(response, provider)
  .stop_for_openai_stream_error(chunks, provider)
  chunks
}

.openai_compatible_chat_request <- function(
  url,
  api_key,
  provider,
  model,
  messages,
  parameters = list(),
  stream = FALSE,
  headers = NULL,
  api_error_prefix = NULL,
  timeout = 120
) {
  body <- utils::modifyList(
    list(
      model = model,
      messages = messages,
      stream = stream
    ),
    parameters
  )

  .openai_json_request(
    url = url,
    api_key = api_key,
    body = body,
    provider = provider,
    stream = stream,
    headers = headers,
    api_error_prefix = api_error_prefix,
    timeout = timeout
  )
}

.parse_openai_sse_response <- function(response, provider) {
  text <- httr2::resp_body_string(response)
  text <- gsub("\r\n?", "\n", text)
  blocks <- strsplit(text, "\n\n", fixed = TRUE)[[1]]
  payloads <- lapply(blocks, function(block) {
    lines <- strsplit(block, "\n", fixed = TRUE)[[1]]
    data_lines <- grep("^data:", lines, value = TRUE)
    if (length(data_lines) == 0) return(NULL)

    data_lines <- sub("^data:[[:space:]]?", "", data_lines)
    payload <- paste(data_lines, collapse = "\n")
    if (!nzchar(payload) || identical(payload, "[DONE]")) return(NULL)
    payload
  })
  payloads <- Filter(Negate(is.null), payloads)

  if (length(payloads) == 0) {
    parsed <- tryCatch(
      jsonlite::fromJSON(text, simplifyVector = FALSE),
      error = function(e) NULL
    )
    message <- .api_error_message(parsed)
    if (!is.null(message)) {
      stop(sprintf("%s API error: %s", provider, message), call. = FALSE)
    }
    stop(sprintf("%s API returned no streaming events.", provider), call. = FALSE)
  }

  lapply(payloads, function(payload) {
    tryCatch(
      jsonlite::fromJSON(payload, simplifyVector = FALSE),
      error = function(e) {
        stop(
          sprintf("%s API returned an invalid streaming event: %s", provider, conditionMessage(e)),
          call. = FALSE
        )
      }
    )
  })
}

.stop_for_openai_stream_error <- function(chunks, provider) {
  for (chunk in chunks) {
    message <- .api_error_message(chunk)
    if (!is.null(message)) {
      stop(sprintf("%s API error: %s", provider, message), call. = FALSE)
    }
  }
}

.extract_openai_stream_text <- function(chunks, provider) {
  parts <- lapply(chunks, function(chunk) {
    if (is.null(chunk$choices) || length(chunk$choices) < 1) return(NULL)
    delta <- chunk$choices[[1]]$delta
    if (is.null(delta)) return(NULL)
    content <- delta$content
    if (is.character(content) && length(content) == 1) content else NULL
  })
  parts <- Filter(Negate(is.null), parts)

  if (length(parts) == 0) {
    stop(
      sprintf("%s API returned no streaming text content. Call with `json_list = TRUE` to inspect the events.", provider),
      call. = FALSE
    )
  }

  paste0(unlist(parts, use.names = FALSE), collapse = "")
}

.normalize_openai_responses_input <- function(input) {
  if (is.character(input) && length(input) == 1 && !is.na(input) && nzchar(input)) {
    return(input)
  }

  if (!is.list(input) || length(input) < 1) {
    stop("`input` must be a non-empty character string or list.", call. = FALSE)
  }

  input
}

.extract_openai_response_text <- function(parsed) {
  if (is.character(parsed$output_text) && length(parsed$output_text) == 1 && nzchar(parsed$output_text)) {
    return(parsed$output_text)
  }

  if (is.null(parsed$output) || !is.list(parsed$output)) {
    stop("OpenAI API returned no output items.", call. = FALSE)
  }

  text <- list()
  index <- 1L
  for (item in parsed$output) {
    if (!is.list(item) || is.null(item$content) || !is.list(item$content)) next

    for (part in item$content) {
      if (!is.list(part) || !identical(part$type, "output_text")) next
      if (is.character(part$text) && length(part$text) == 1 && nzchar(part$text)) {
        text[[index]] <- part$text
        index <- index + 1L
      }
    }
  }

  if (length(text) == 0) {
    stop(
      "OpenAI API returned no text output. Call with `json_list = TRUE` to inspect the response.",
      call. = FALSE
    )
  }

  paste(unlist(text, use.names = FALSE), collapse = "\n")
}

.parse_json_response <- function(response) {
  txt <- httr2::resp_body_string(response)
  parse_error <- NULL
  json <- tryCatch(
    jsonlite::fromJSON(txt, simplifyVector = FALSE),
    error = function(error) {
      parse_error <<- error
      NULL
    }
  )

  list(
    text = txt,
    json = json,
    parse_error = parse_error
  )
}

.api_error_message <- function(json) {
  if (!is.null(json$error) && !is.null(json$error$message) && nzchar(json$error$message)) {
    return(json$error$message)
  }

  NULL
}

.stop_for_json_response <- function(
  response,
  parsed,
  request_failed_prefix,
  api_error_prefix = NULL,
  sensitive_values = NULL
) {
  if (httr2::resp_status(response) >= 300) {
    msg <- .redact_sensitive_text(.api_error_message(parsed$json), sensitive_values)

    if (!is.null(msg) && !is.null(api_error_prefix)) {
      stop(sprintf("%s: %s", api_error_prefix, msg), call. = FALSE)
    }

    stop(request_failed_prefix, .redact_sensitive_text(parsed$text, sensitive_values), call. = FALSE)
  }

  if (!is.null(parsed$parse_error)) {
    stop(
      request_failed_prefix,
      "invalid JSON response: ",
      conditionMessage(parsed$parse_error),
      call. = FALSE
    )
  }

  msg <- .redact_sensitive_text(.api_error_message(parsed$json), sensitive_values)
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

.extract_openai_choice <- function(parsed, provider) {
  if (is.null(parsed$choices) || length(parsed$choices) < 1) {
    stop(sprintf("%s API returned no choices.", provider), call. = FALSE)
  }

  choice <- parsed$choices[[1]]

  if (is.null(choice) || !is.list(choice)) {
    stop(sprintf("%s API returned an invalid choice object.", provider), call. = FALSE)
  }

  choice
}

.openai_choice_finish_reason <- function(choice) {
  for (field in c("finish_reason", "native_finish_reason")) {
    value <- choice[[field]]
    if (is.character(value) && length(value) == 1 && nzchar(value)) {
      return(value)
    }
  }

  NULL
}

.openai_choice_is_truncated <- function(choice) {
  finish_reason <- .openai_choice_finish_reason(choice)

  is.character(finish_reason) &&
    length(finish_reason) == 1 &&
    finish_reason %in% c("length", "max_tokens")
}

.extract_openai_message_text <- function(message) {
  if (is.character(message$content) && length(message$content) == 1 && nzchar(message$content)) {
    return(message$content)
  }

  if (is.list(message$content) && length(message$content) >= 1) {
    text_parts <- lapply(message$content, function(part) {
      for (field in c("text", "content", "output_text")) {
        value <- part[[field]]
        if (is.character(value) && length(value) == 1 && nzchar(value)) {
          return(value)
        }
      }
      NULL
    })
    text_parts <- Filter(Negate(is.null), text_parts)

    if (length(text_parts) >= 1) {
      return(paste(unlist(text_parts, use.names = FALSE), collapse = "\n"))
    }
  }

  if (is.character(message$refusal) && length(message$refusal) == 1 && nzchar(message$refusal)) {
    return(message$refusal)
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

.openrouter_video_model_rows <- function(models) {
  rows <- lapply(models, function(x) {
    for (nm in c(
      "allowed_passthrough_parameters",
      "supported_aspect_ratios",
      "supported_durations",
      "supported_frame_images",
      "supported_reference_images",
      "supported_resolutions",
      "supported_sizes"
    )) {
      if (nm %in% names(x)) {
        x[[nm]] <- list(x[[nm]])
      }
    }

    if ("pricing_skus" %in% names(x)) {
      x$pricing_skus <- list(x$pricing_skus)
    }

    for (nm in names(x)) {
      if (length(x[[nm]]) == 0) {
        x[[nm]] <- NA
      }
    }

    x
  })

  data.table::rbindlist(rows, fill = TRUE)
}

.validate_openrouter_benchmark_filter <- function(x, arg, choices) {
  if (is.null(x)) {
    return(invisible(NULL))
  }

  .validate_non_empty_string(x, arg)
  if (!x %in% choices) {
    stop(
      sprintf("`%s` must be NULL or one of: %s.", arg, paste(sprintf("`%s`", choices), collapse = ", ")),
      call. = FALSE
    )
  }
}

.openrouter_benchmarks_url <- function(url, source = NULL, task_type = NULL) {
  .validate_non_empty_string(url, "url")

  parameters <- c()
  if (!is.null(source)) parameters <- c(parameters, source = source)
  if (!is.null(task_type)) parameters <- c(parameters, task_type = task_type)
  if (length(parameters) == 0) return(url)

  separator <- if (grepl("?", url, fixed = TRUE)) "&" else "?"
  query <- paste(
    paste0(names(parameters), "=", vapply(parameters, utils::URLencode, character(1), reserved = TRUE)),
    collapse = "&"
  )
  paste0(url, separator, query)
}

.openrouter_benchmark_empty_table <- function() {
  data.table::data.table(
    model_id = character(),
    model_name = character(),
    source = character(),
    metric = character(),
    score = numeric(),
    score_unit = character(),
    prompt_price_per_token = numeric(),
    completion_price_per_token = numeric(),
    price_basis = character(),
    avg_cost_per_task = numeric(),
    accuracy_stddev = numeric(),
    total_tasks = integer(),
    last_run_timestamp = character(),
    source_as_of = character(),
    source_url = character(),
    endpoint = character(),
    fetched_at = as.POSIXct(character(), tz = "UTC")
  )
}

.openrouter_benchmark_value <- function(x) {
  if (is.null(x) || length(x) != 1 || is.na(x)) return(NA_real_)
  suppressWarnings(as.numeric(x))
}

.openrouter_benchmark_text <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) return(NA_character_)
  x
}

.openrouter_benchmark_score_unit <- function(source, metric) {
  if (identical(source, "openrouter")) return("proportion")

  units <- c(
    "artificial-analysis::intelligence_index" = "index_points",
    "artificial-analysis::coding_index" = "index_points",
    "artificial-analysis::agentic_index" = "index_points",
    "design-arena::elo" = "elo_points",
    "design-arena::win_rate" = "proportion",
    "design-arena::rank" = "ordinal_rank"
  )

  unit <- units[paste(source, metric, sep = "::")]
  if (is.null(unit)) NA_character_ else unname(unit)
}

.openrouter_benchmark_rows <- function(records, meta = NULL, endpoint, fetched_at) {
  if (length(records) == 0) return(.openrouter_benchmark_empty_table())

  meta_source_url <- if (is.list(meta)) .openrouter_benchmark_text(meta$source_url) else NA_character_
  source_as_of <- if (is.list(meta)) .openrouter_benchmark_text(meta$as_of) else NA_character_
  rows <- list()
  index <- 1L

  for (record in records) {
    if (!is.list(record)) next

    source <- .openrouter_benchmark_text(record$source)
    model_id <- .openrouter_benchmark_text(record$model_permaslug)
    if (is.na(model_id)) model_id <- .openrouter_benchmark_text(record$model_id)
    model_name <- .openrouter_benchmark_text(record$display_name)
    if (is.na(model_name)) model_name <- .openrouter_benchmark_text(record$model_name)

    pricing <- if (is.list(record$pricing)) record$pricing else list()
    prompt_price <- .openrouter_benchmark_value(pricing$prompt)
    completion_price <- .openrouter_benchmark_value(pricing$completion)
    source_url <- .openrouter_benchmark_text(record$source_url)
    if (is.na(source_url)) source_url <- meta_source_url
    if (is.na(source_url)) source_url <- endpoint

    metrics <- switch(
      source,
      "artificial-analysis" = c("intelligence_index", "coding_index", "agentic_index"),
      "openrouter" = if (is.character(record$benchmark_type) && length(record$benchmark_type) == 1) record$benchmark_type else "accuracy",
      "design-arena" = c("elo", "win_rate", "rank"),
      character()
    )

    values <- switch(
      source,
      "artificial-analysis" = lapply(metrics, function(metric) record[[metric]]),
      "openrouter" = list(record$accuracy),
      "design-arena" = lapply(metrics, function(metric) record[[metric]]),
      list()
    )

    for (i in seq_along(metrics)) {
      score <- .openrouter_benchmark_value(values[[i]])
      if (is.na(score)) next

      rows[[index]] <- list(
        model_id = model_id,
        model_name = model_name,
        source = source,
        metric = metrics[[i]],
        score = score,
        score_unit = .openrouter_benchmark_score_unit(source, metrics[[i]]),
        prompt_price_per_token = prompt_price,
        completion_price_per_token = completion_price,
        price_basis = if (!is.na(prompt_price) || !is.na(completion_price)) "source_reported_per_token" else NA_character_,
        avg_cost_per_task = .openrouter_benchmark_value(record$avg_cost_per_task),
        accuracy_stddev = .openrouter_benchmark_value(record$accuracy_stddev),
        total_tasks = as.integer(.openrouter_benchmark_value(record$total_tasks)),
        last_run_timestamp = .openrouter_benchmark_text(record$last_run_timestamp),
        source_as_of = source_as_of,
        source_url = source_url,
        endpoint = endpoint,
        fetched_at = as.POSIXct(fetched_at, tz = "UTC")
      )
      index <- index + 1L
    }
  }

  if (length(rows) == 0) return(.openrouter_benchmark_empty_table())
  data.table::rbindlist(rows, fill = TRUE)
}

.coerce_openrouter_models_input <- function(models) {
  if (is.list(models) && !is.data.frame(models) && !is.null(models$data) && is.list(models$data)) {
    return(models$data)
  }

  if (is.data.frame(models)) {
    out <- vector("list", nrow(models))
    for (i in seq_len(nrow(models))) {
      out[[i]] <- as.list(models[i, , drop = FALSE])
    }
    return(out)
  }

  if (is.list(models) && length(models) >= 1) {
    return(models)
  }

  stop("`models` must be a parsed OpenRouter models response, list of model objects, or data.frame.", call. = FALSE)
}

.flatten_benchmark_payload <- function(x, prefix = NULL) {
  out <- list()

  if (is.null(x) || length(x) == 0) {
    return(out)
  }

  if (!is.list(x)) {
    key <- if (is.null(prefix)) "value" else prefix
    out[[key]] <- as.character(x[[1]])
    return(out)
  }

  nms <- names(x)
  if (is.null(nms)) {
    nms <- rep("", length(x))
  }

  for (i in seq_along(x)) {
    name_i <- nms[[i]]
    next_prefix <- prefix

    if (nzchar(name_i)) {
      next_prefix <- if (is.null(prefix)) name_i else paste(prefix, name_i, sep = ".")
    } else if (length(x) > 1) {
      next_prefix <- if (is.null(prefix)) as.character(i) else paste(prefix, i, sep = ".")
    }

    flattened <- .flatten_benchmark_payload(x[[i]], next_prefix)
    if (length(flattened) > 0) {
      out <- c(out, flattened)
    }
  }

  out
}

.openrouter_extract_architecture_field <- function(x, field) {
  if (is.data.frame(x)) {
    if (!"architecture" %in% names(x)) {
      return(rep(list(NULL), nrow(x)))
    }

    return(lapply(x$architecture, function(arch) {
      if (is.list(arch) && !is.null(arch[[field]])) arch[[field]] else NULL
    }))
  }

  if (is.list(x) && !is.null(x$data) && is.list(x$data)) {
    return(lapply(x$data, function(model) {
      if (is.list(model$architecture) && !is.null(model$architecture[[field]])) model$architecture[[field]] else NULL
    }))
  }

  if (is.list(x)) {
    return(lapply(x, function(model) {
      if (is.list(model$architecture) && !is.null(model$architecture[[field]])) model$architecture[[field]] else NULL
    }))
  }

  stop("Unsupported OpenRouter model container.", call. = FALSE)
}

.normalize_modality_values <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(character(0))
  }

  vals <- unlist(x, use.names = FALSE)
  vals <- vals[!is.na(vals)]
  tolower(as.character(vals))
}

.openrouter_models_keep <- function(models, keep) {
  if (is.data.frame(models)) {
    return(models[keep, , drop = FALSE])
  }

  if (is.list(models) && !is.null(models$data) && is.list(models$data)) {
    out <- models
    out$data <- models$data[keep]
    return(out)
  }

  if (is.list(models)) {
    return(models[keep])
  }

  stop("Unsupported OpenRouter model container.", call. = FALSE)
}

.filter_openrouter_models_by_modalities <- function(models,
  input_modalities = NULL,
  output_modalities = NULL,
  require_multiple_inputs = FALSE) {

  inputs <- .openrouter_extract_architecture_field(models, "input_modalities")
  outputs <- .openrouter_extract_architecture_field(models, "output_modalities")

  keep <- rep(TRUE, length(inputs))

  if (!is.null(input_modalities)) {
    wanted <- tolower(input_modalities)
    keep <- keep & vapply(inputs, function(x) {
      vals <- .normalize_modality_values(x)
      any(wanted %in% vals)
    }, logical(1))
  }

  if (!is.null(output_modalities)) {
    wanted <- tolower(output_modalities)
    keep <- keep & vapply(outputs, function(x) {
      vals <- .normalize_modality_values(x)
      any(wanted %in% vals)
    }, logical(1))
  }

  if (require_multiple_inputs) {
    keep <- keep & vapply(inputs, function(x) {
      length(.normalize_modality_values(x)) > 1
    }, logical(1))
  }

  .openrouter_models_keep(models, keep)
}
