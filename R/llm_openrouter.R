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
  .require_api_key(api_key, "OPENROUTER_API_KEY")

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Authorization" = paste("Bearer", api_key)
    )
  )
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  res <- parsed$json

  if (json_list) return(res)
  
  if (!"data" %in% names(res)) {
    stop("Response does not contain a 'data' field.", call. = FALSE)
  }
  
  .openrouter_model_rows(res$data)
}

#' List OpenRouter Embedding Models
#'
#' Filters the general OpenRouter models catalog to models with embedding
#' output modalities.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the filtered parsed JSON response as a
#'   list.
#'
#' @return A filtered `data.table` by default, or a filtered parsed JSON list
#'   when `json_list = TRUE`.
#' @export
list_openrouter_embedding_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  models <- list_openrouter_models(
    api_key = api_key,
    url = url,
    json_list = json_list
  )

  .filter_openrouter_models_by_modalities(
    models,
    output_modalities = "embeddings"
  )
}

#' List OpenRouter Image Models
#'
#' Filters the general OpenRouter models catalog to models with image output
#' modalities.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the filtered parsed JSON response as a
#'   list.
#'
#' @return A filtered `data.table` by default, or a filtered parsed JSON list
#'   when `json_list = TRUE`.
#' @export
list_openrouter_image_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  models <- list_openrouter_models(
    api_key = api_key,
    url = url,
    json_list = json_list
  )

  .filter_openrouter_models_by_modalities(
    models,
    output_modalities = "image"
  )
}

#' List OpenRouter Audio Models
#'
#' Filters the general OpenRouter models catalog to models with audio input or
#' output modalities.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the filtered parsed JSON response as a
#'   list.
#'
#' @return A filtered `data.table` by default, or a filtered parsed JSON list
#'   when `json_list = TRUE`.
#' @export
list_openrouter_audio_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  models <- list_openrouter_models(
    api_key = api_key,
    url = url,
    json_list = json_list
  )

  keep_input <- .filter_openrouter_models_by_modalities(
    models,
    input_modalities = "audio"
  )
  keep_output <- .filter_openrouter_models_by_modalities(
    models,
    output_modalities = "audio"
  )

  if (is.data.frame(models)) {
    ids <- unique(c(keep_input$id, keep_output$id))
    return(models[models$id %in% ids, , drop = FALSE])
  }

  if (is.list(models) && !is.null(models$data)) {
    ids <- unique(c(
      vapply(keep_input$data, function(x) if (is.character(x$id) && length(x$id) == 1) x$id else NA_character_, character(1)),
      vapply(keep_output$data, function(x) if (is.character(x$id) && length(x$id) == 1) x$id else NA_character_, character(1))
    ))
    ids <- ids[!is.na(ids)]
    models$data <- Filter(function(x) !is.null(x$id) && x$id %in% ids, models$data)
    return(models)
  }

  ids <- unique(c(
    vapply(keep_input, function(x) if (is.character(x$id) && length(x$id) == 1) x$id else NA_character_, character(1)),
    vapply(keep_output, function(x) if (is.character(x$id) && length(x$id) == 1) x$id else NA_character_, character(1))
  ))
  ids <- ids[!is.na(ids)]
  Filter(function(x) !is.null(x$id) && x$id %in% ids, models)
}

#' List OpenRouter Multimodal Models
#'
#' Filters the general OpenRouter models catalog to models that support
#' multiple input modalities.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter models endpoint.
#' @param json_list If `TRUE`, return the filtered parsed JSON response as a
#'   list.
#'
#' @return A filtered `data.table` by default, or a filtered parsed JSON list
#'   when `json_list = TRUE`.
#' @export
list_openrouter_multimodal_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/models",
  json_list = FALSE
) {
  models <- list_openrouter_models(
    api_key = api_key,
    url = url,
    json_list = json_list
  )

  .filter_openrouter_models_by_modalities(
    models,
    require_multiple_inputs = TRUE
  )
}

#' List OpenRouter Video Generation Models
#'
#' Retrieves available video generation models and their normalized feature
#' metadata from the OpenRouter video models endpoint.
#'
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter video models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_openrouter_video_models <- function(
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/videos/models",
  json_list = FALSE
) {
  .require_api_key(api_key, "OPENROUTER_API_KEY")

  response <- .perform_json_request(
    url = url,
    headers = list(
      "Authorization" = paste("Bearer", api_key)
    )
  )
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  res <- parsed$json

  if (json_list) return(res)

  if (!"data" %in% names(res)) {
    stop("Response does not contain a 'data' field.", call. = FALSE)
  }

  .openrouter_video_model_rows(res$data)
}

#' Extract Benchmark Scores from OpenRouter Model Metadata
#'
#' Scans OpenRouter model metadata for benchmark payloads, including possible
#' Artificial Analysis benchmark fields when they are present in the models
#' response.
#'
#' @param models Parsed JSON from `list_openrouter_models(json_list = TRUE)`, a
#'   list of OpenRouter model objects, or a `data.frame` returned by
#'   `list_openrouter_models()`.
#' @param benchmark_fields Candidate field names to inspect on each model.
#'
#' @return A `data.table` with one row per extracted benchmark metric. Returns
#'   an empty `data.table` when no benchmark fields are found.
#' @export
extract_openrouter_benchmarks <- function(
  models,
  benchmark_fields = c(
    "benchmarks",
    "benchmark_scores",
    "artificial_analysis",
    "artificial_analysis_benchmarks",
    "benchmark_data"
  )
) {
  if (!is.character(benchmark_fields) || length(benchmark_fields) < 1 || any(is.na(benchmark_fields)) || any(!nzchar(benchmark_fields))) {
    stop("`benchmark_fields` must be a non-empty character vector.", call. = FALSE)
  }

  model_list <- .coerce_openrouter_models_input(models)
  rows <- list()
  row_index <- 1L

  for (model in model_list) {
    if (!is.list(model)) {
      next
    }

    model_id <- if (is.character(model$id) && length(model$id) == 1) model$id else NA_character_
    model_name <- if (is.character(model$name) && length(model$name) == 1) model$name else NA_character_

    for (field in benchmark_fields) {
      payload <- model[[field]]
      if (is.null(payload) || length(payload) == 0) {
        next
      }

      flat <- .flatten_benchmark_payload(payload)
      if (length(flat) == 0) {
        next
      }

      metrics <- names(flat)
      if (is.null(metrics)) {
        metrics <- rep("value", length(flat))
      }

      for (i in seq_along(flat)) {
        value <- flat[[i]]
        score <- suppressWarnings(as.numeric(value))
        if (length(score) != 1 || is.na(score)) {
          score <- NA_real_
        }

        rows[[row_index]] <- list(
          model_id = model_id,
          model_name = model_name,
          benchmark_field = field,
          metric = metrics[[i]],
          value = value,
          score = score
        )
        row_index <- row_index + 1L
      }
    }
  }

  if (length(rows) == 0) {
    return(data.table::data.table(
      model_id = character(),
      model_name = character(),
      benchmark_field = character(),
      metric = character(),
      value = character(),
      score = numeric()
    ))
  }

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
  model = "openrouter/free", # other current free options can be inspected from list_openrouter_models()
  temperature = 0,
  top_p = 1,
  max_tokens = 2048L,
  reasoning = TRUE,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE
) {
  query_openrouter_content(
    content = prompt,
    model = model,
    temperature = temperature,
    top_p = top_p,
    max_tokens = max_tokens,
    reasoning = reasoning,
    api_key = api_key,
    url = url,
    json_list = json_list
  )
}
