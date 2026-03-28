#' Query a Gemini Multimodal Model
#'
#' Sends Gemini `generateContent` requests using either a simple text prompt or
#' an explicit list of content parts. This allows text, image, audio, PDF, and
#' other supported non-text inputs to be passed through the same wrapper.
#'
#' @param prompt A non-empty character string. Ignored when `parts` is
#'   supplied.
#' @param parts Optional Gemini `parts` payload supplied as a list. Use this for
#'   multimodal inputs such as `inlineData` or `fileData`.
#' @param api_key Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param model Model identifier.
#' @param url0 Base Gemini models URL.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param top_k Top-k sampling parameter.
#' @param max_tokens Optional maximum number of output tokens.
#' @param response_modalities Optional response modalities, for example
#'   `c("TEXT")`, `c("AUDIO")`, or `c("TEXT", "IMAGE")`.
#' @param speech_config Optional Gemini `speechConfig` object supplied as an R
#'   list.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string when Gemini returns text, a base64 string when the
#'   first returned part is inline binary data, or the parsed JSON response when
#'   `json_list = TRUE`.
#' @export
query_gemini_content <- function(prompt = NULL, parts = NULL,
  api_key = Sys.getenv("GEMINI_API_KEY"),
  model = "gemini-2.5-flash",
  url0 = Sys.getenv("GEMINI_API_URL", unset = "https://generativelanguage.googleapis.com/v1beta/models"),
  temperature = 0.7, top_p = 1, top_k = 40, max_tokens = NULL,
  response_modalities = NULL, speech_config = NULL,
  json_list = FALSE) {

  content_parts <- .normalize_gemini_parts(prompt = prompt, parts = parts)
  .require_api_key(api_key, "GEMINI_API_KEY")

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

  if (!is.numeric(top_k) || length(top_k) != 1 || is.na(top_k)) {
    stop("`top_k` must be a single numeric value.", call. = FALSE)
  }

  if (top_k < 1 || top_k != as.integer(top_k)) {
    stop("`top_k` must be a single positive integer.", call. = FALSE)
  }

  model <- .resolve_model_arg(model)

  if (!is.null(max_tokens)) {
    if (!is.numeric(max_tokens) || length(max_tokens) != 1 || is.na(max_tokens) || max_tokens < 1) {
      stop("`max_tokens` must be a single positive number or NULL.", call. = FALSE)
    }
  }

  if (!is.null(response_modalities)) {
    if (!is.character(response_modalities) || length(response_modalities) < 1 || any(!nzchar(response_modalities))) {
      stop("`response_modalities` must be a non-empty character vector or NULL.", call. = FALSE)
    }
  }

  if (!is.null(speech_config) && !is.list(speech_config)) {
    stop("`speech_config` must be a list or NULL.", call. = FALSE)
  }

  url <- sprintf("%s/%s:generateContent?key=%s", url0, model, api_key)

  body <- list(
    contents = list(list(
      role = "user",
      parts = content_parts
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

  if (!is.null(response_modalities)) {
    body$generationConfig$responseModalities <- unname(response_modalities)
  }

  if (!is.null(speech_config)) {
    body$generationConfig$speechConfig <- speech_config
  }

  response <- .perform_json_request(
    url = url,
    headers = list(`Content-Type` = "application/json"),
    body = body
  )
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(response, parsed_resp, "Gemini API request failed: ", NULL)
  parsed <- parsed_resp$json

  if (json_list) {
    return(parsed)
  }

  part <- .extract_gemini_part(parsed)

  if (!is.null(part$text)) {
    text <- part$text

    if (!is.character(text) || length(text) != 1 || !nzchar(text)) {
      stop("Gemini API returned no text content.", call. = FALSE)
    }

    return(text)
  }

  if (!is.null(part$inlineData) && !is.null(part$inlineData$data)) {
    binary_data <- part$inlineData$data

    if (!is.character(binary_data) || length(binary_data) != 1 || !nzchar(binary_data)) {
      stop("Gemini API returned no inline binary data.", call. = FALSE)
    }

    return(binary_data)
  }

  stop("Gemini API returned neither text nor inline binary content.", call. = FALSE)
}

#' Request Gemini Embeddings
#'
#' Calls Gemini embedding endpoints for one or more text inputs.
#'
#' @param input A non-empty character vector.
#' @param api_key Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param model Embedding model identifier.
#' @param url0 Base Gemini models URL.
#' @param task_type Optional Gemini embedding `taskType`.
#' @param title Optional embedding title, used with document-style inputs.
#' @param output_dimensionality Optional embedding dimensionality override.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A numeric matrix by default, or the parsed JSON response when
#'   `json_list = TRUE`.
#' @export
embed_gemini <- function(input,
  api_key = Sys.getenv("GEMINI_API_KEY"),
  model = "gemini-embedding-001",
  url0 = Sys.getenv("GEMINI_API_URL", unset = "https://generativelanguage.googleapis.com/v1beta/models"),
  task_type = NULL, title = NULL, output_dimensionality = NULL,
  json_list = FALSE) {

  .validate_character_vector(input, "input")
  .require_api_key(api_key, "GEMINI_API_KEY")
  model <- .resolve_model_arg(model)

  if (!is.null(task_type)) {
    .validate_non_empty_string(task_type, "task_type")
  }

  if (!is.null(title)) {
    .validate_non_empty_string(title, "title")
  }

  if (!is.null(output_dimensionality)) {
    if (!is.numeric(output_dimensionality) || length(output_dimensionality) != 1 || is.na(output_dimensionality) || output_dimensionality < 1) {
      stop("`output_dimensionality` must be a single positive number or NULL.", call. = FALSE)
    }
  }

  make_request <- function(text) {
    req <- list(
      model = sprintf("models/%s", model),
      content = list(parts = list(list(text = text)))
    )

    if (!is.null(task_type)) {
      req$taskType <- task_type
    }

    if (!is.null(title)) {
      req$title <- title
    }

    if (!is.null(output_dimensionality)) {
      req$outputDimensionality <- as.integer(output_dimensionality)
    }

    req
  }

  if (length(input) == 1) {
    url <- sprintf("%s/%s:embedContent?key=%s", url0, model, api_key)
    body <- make_request(input[[1]])
  } else {
    url <- sprintf("%s/%s:batchEmbedContents?key=%s", url0, model, api_key)
    body <- list(requests = unname(lapply(input, make_request)))
  }

  response <- .perform_json_request(
    url = url,
    headers = list(`Content-Type` = "application/json"),
    body = body
  )
  parsed_resp <- .parse_json_response(response)
  .stop_for_json_response(response, parsed_resp, "Gemini API request failed: ", NULL)
  parsed <- parsed_resp$json

  if (json_list) {
    return(parsed)
  }

  .extract_gemini_embedding_matrix(parsed)
}

#' Generate Images with Gemini
#'
#' Calls Gemini image-generation capable models and returns the generated image
#' payloads as base64 strings.
#'
#' @param prompt A non-empty character string.
#' @param api_key Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param model Image-capable Gemini model identifier.
#' @param url0 Base Gemini models URL.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param top_k Top-k sampling parameter.
#' @param max_tokens Optional maximum number of output tokens.
#' @param response_modalities Modalities to request. Defaults to
#'   `c("TEXT", "IMAGE")`.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character vector of base64-encoded image payloads by default, or
#'   the parsed JSON response when `json_list = TRUE`.
#' @export
generate_image_gemini <- function(prompt,
  api_key = Sys.getenv("GEMINI_API_KEY"),
  model = "gemini-2.5-flash-image",
  url0 = Sys.getenv("GEMINI_API_URL", unset = "https://generativelanguage.googleapis.com/v1beta/models"),
  temperature = 0.7, top_p = 1, top_k = 40, max_tokens = NULL,
  response_modalities = c("TEXT", "IMAGE"),
  json_list = FALSE) {

  model <- .resolve_model_arg(model)

  parsed <- query_gemini_content(
    prompt = prompt,
    api_key = api_key,
    model = model,
    url0 = url0,
    temperature = temperature,
    top_p = top_p,
    top_k = top_k,
    max_tokens = max_tokens,
    response_modalities = response_modalities,
    json_list = TRUE
  )

  if (json_list) {
    return(parsed)
  }

  .extract_gemini_images(parsed)
}

#' Query an OpenRouter Multimodal Model
#'
#' Sends a single OpenRouter chat-completions request using either simple text
#' content or an explicit multimodal content block list.
#'
#' @param content A non-empty character string or a non-empty list of OpenAI
#'   style content blocks.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param reasoning Whether to enable reasoning mode.
#' @param modalities Optional output modalities, for example `"text"` or
#'   `c("text", "image")`.
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default when the assistant returns text, the
#'   first image payload or URL when text is absent but images are returned, or
#'   the parsed JSON response when `json_list = TRUE`.
#' @export
query_openrouter_content <- function(content,
  model = "openrouter/hunter-alpha",
  temperature = 0,
  top_p = 1,
  max_tokens = 512L,
  reasoning = TRUE,
  modalities = NULL,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE) {

  content <- .normalize_openrouter_content(content)
  .require_api_key(api_key, "OPENROUTER_API_KEY")

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

  if (!is.null(modalities)) {
    if (!is.character(modalities) || length(modalities) < 1 || any(!nzchar(modalities))) {
      stop("`modalities` must be a non-empty character vector or NULL.", call. = FALSE)
    }
  }

  model <- .resolve_model_arg(model)

  body <- list(
    model = model,
    messages = list(
      list(
        role = "user",
        content = content
      )
    ),
    temperature = temperature,
    top_p = top_p,
    max_tokens = max_tokens,
    reasoning = list(
      enabled = reasoning
    )
  )

  if (!is.null(modalities)) {
    body$modalities <- unname(modalities)
  }

  resp <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed <- .parse_json_response(resp)
  .stop_for_json_response(resp, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  json <- parsed$json

  if (json_list) {
    return(json)
  }

  message <- .extract_openai_message(json, "OpenRouter")
  text <- .extract_openai_message_text(message)
  if (!is.null(text)) {
    return(text)
  }

  image <- .extract_openai_message_image(message)
  if (!is.null(image)) {
    return(image)
  }

  stop("OpenRouter API returned neither text nor image content.", call. = FALSE)
}

#' Request OpenRouter Embeddings
#'
#' Calls the OpenRouter embeddings endpoint for one or more text inputs.
#'
#' @param input A non-empty character vector.
#' @param model Model identifier.
#' @param dimensions Optional embedding dimensionality override.
#' @param encoding_format Embedding encoding. Defaults to `"float"`.
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter embeddings endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A numeric matrix by default when `encoding_format = "float"`, or the
#'   parsed JSON response when `json_list = TRUE`.
#' @export
embed_openrouter <- function(input,
  model = "openai/text-embedding-3-small",
  dimensions = NULL,
  encoding_format = c("float", "base64"),
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = "https://openrouter.ai/api/v1/embeddings",
  json_list = FALSE) {

  .validate_character_vector(input, "input")
  .require_api_key(api_key, "OPENROUTER_API_KEY")
  model <- .resolve_model_arg(model)
  encoding_format <- match.arg(encoding_format)

  if (!is.null(dimensions)) {
    if (!is.numeric(dimensions) || length(dimensions) != 1 || is.na(dimensions) || dimensions < 1) {
      stop("`dimensions` must be a single positive number or NULL.", call. = FALSE)
    }
  }

  body <- list(
    model = model,
    input = unname(input),
    encoding_format = encoding_format
  )

  if (!is.null(dimensions)) {
    body$dimensions <- as.integer(dimensions)
  }

  resp <- .perform_json_request(
    url = url,
    headers = list(
      "Content-Type" = "application/json",
      "Authorization" = paste("Bearer", api_key)
    ),
    body = body
  )
  parsed <- .parse_json_response(resp)
  .stop_for_json_response(resp, parsed, "OpenRouter API request failed: ", "OpenRouter API error")
  json <- parsed$json

  if (json_list) {
    return(json)
  }

  if (encoding_format != "float") {
    stop("`json_list = TRUE` is required when `encoding_format` is not `\"float\"`.", call. = FALSE)
  }

  .extract_openai_embedding_matrix(json, "OpenRouter")
}

#' Generate Images with OpenRouter
#'
#' Calls the OpenRouter chat completions API for image-capable models and
#' returns the first available image payload or URL.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param api_key OpenRouter API key. Defaults to
#'   `Sys.getenv("OPENROUTER_API_KEY")`.
#' @param url OpenRouter chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string containing an image URL or base64 payload by
#'   default, or the parsed JSON response when `json_list = TRUE`.
#' @export
generate_image_openrouter <- function(prompt,
  model = "google/gemini-2.5-flash-image-preview",
  temperature = 0,
  top_p = 1,
  max_tokens = 512L,
  api_key = Sys.getenv("OPENROUTER_API_KEY"),
  url = Sys.getenv("OPENROUTER_API_URL", unset = "https://openrouter.ai/api/v1/chat/completions"),
  json_list = FALSE) {

  .validate_non_empty_string(prompt, "prompt")
  model <- .resolve_model_arg(model)

  query_openrouter_content(
    content = prompt,
    model = model,
    temperature = temperature,
    top_p = top_p,
    max_tokens = max_tokens,
    reasoning = FALSE,
    modalities = c("text", "image"),
    api_key = api_key,
    url = url,
    json_list = json_list
  )
}
