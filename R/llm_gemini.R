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

.wav_header <- function(data_size, sample_rate, channels, bits_per_sample) {
  byte_rate <- as.integer(sample_rate * channels * bits_per_sample / 8L)
  block_align <- as.integer(channels * bits_per_sample / 8L)
  chunk_size <- as.integer(36L + data_size)

  con <- rawConnection(raw(), "wb")
  on.exit(close(con), add = TRUE)

  writeChar("RIFF", con, eos = NULL, useBytes = TRUE)
  writeBin(chunk_size, con, size = 4L, endian = "little")
  writeChar("WAVE", con, eos = NULL, useBytes = TRUE)
  writeChar("fmt ", con, eos = NULL, useBytes = TRUE)
  writeBin(16L, con, size = 4L, endian = "little")
  writeBin(1L, con, size = 2L, endian = "little")
  writeBin(as.integer(channels), con, size = 2L, endian = "little")
  writeBin(as.integer(sample_rate), con, size = 4L, endian = "little")
  writeBin(byte_rate, con, size = 4L, endian = "little")
  writeBin(block_align, con, size = 2L, endian = "little")
  writeBin(as.integer(bits_per_sample), con, size = 2L, endian = "little")
  writeChar("data", con, eos = NULL, useBytes = TRUE)
  writeBin(as.integer(data_size), con, size = 4L, endian = "little")

  rawConnectionValue(con)
}

#' List Gemini Models
#'
#' Retrieves available models from the Gemini models endpoint.
#'
#' @param api_key Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param url Gemini models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_gemini_models <- function(api_key = Sys.getenv("GEMINI_API_KEY"), url = "https://generativelanguage.googleapis.com/v1beta/models", json_list = FALSE) {
  .require_api_key(api_key, "GEMINI_API_KEY")

  response <- .perform_json_request(sprintf("%s?key=%s", url, api_key))
  parsed <- .parse_json_response(response)
  .stop_for_json_response(response, parsed, "Gemini API request failed: ", NULL)
  res <- parsed$json

  if (json_list) return(res)

  if (is.null(res$models)) {
    stop("Gemini API response does not contain a `models` field.", call. = FALSE)
  }

  data.table::rbindlist(res$models, fill = TRUE)
}

#' Query a Gemini Model
#'
#' Sends a single user prompt to the Gemini `generateContent` API.
#'
#' @param prompt A non-empty character string.
#' @param api_key Gemini API key. Defaults to `Sys.getenv("GEMINI_API_KEY")`.
#' @param model Model identifier.
#' @param url0 Base Gemini models URL.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param top_k Top-k sampling parameter.
#' @param max_tokens Optional maximum number of output tokens.
#' @param response_modalities Optional response modalities, for example
#'   `c("TEXT")` or `c("AUDIO")`.
#' @param speech_config Optional Gemini `speechConfig` object supplied as an R
#'   list.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#'
#' @return A character string by default. For audio responses, returns the
#'   base64-encoded audio data from `inlineData$data`. Returns the parsed JSON
#'   list when `json_list = TRUE`.
#' @export
query_gemini <- function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"),
  model = "gemini-2.5-flash", # some common free models include gemini-2.5-pro, gemini-2.5-flash-lite, gemini-2.5-flash-preview-tts, gemini-embedding-001, gemma-3-27b-it, and gemma-3n-e2b-it
  url0 = Sys.getenv("GEMINI_API_URL", unset = "https://generativelanguage.googleapis.com/v1beta/models"),
  temperature = 0.7, top_p = 1, top_k = 40, max_tokens = NULL, 
  response_modalities = NULL, speech_config = NULL,
  json_list = FALSE) {
  query_gemini_content(
    prompt = prompt,
    api_key = api_key,
    model = model,
    url0 = url0,
    temperature = temperature,
    top_p = top_p,
    top_k = top_k,
    max_tokens = max_tokens,
    response_modalities = response_modalities,
    speech_config = speech_config,
    json_list = json_list
  )
}

#' Write Gemini Audio to a File
#'
#' Decodes base64 audio returned by `query_gemini()` and writes it as raw PCM
#' or a WAV file.
#'
#' @param x A base64-encoded audio string, or a parsed JSON response returned by
#'   `query_gemini(..., json_list = TRUE)`.
#' @param path Output file path.
#' @param format Output format: `"pcm"` or `"wav"`.
#' @param sample_rate Sample rate used when writing WAV output.
#' @param channels Number of audio channels used when writing WAV output.
#' @param bits_per_sample Bit depth used when writing WAV output.
#'
#' @return Invisibly returns `path`.
#' @export
write_gemini_audio <- function(x, path, format = c("pcm", "wav"),
  sample_rate = 24000L, channels = 1L, bits_per_sample = 16L) {

  format <- match.arg(format)

  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("`path` must be a non-empty character string.", call. = FALSE)
  }

  if (!is.numeric(sample_rate) || length(sample_rate) != 1 || is.na(sample_rate) || sample_rate < 1) {
    stop("`sample_rate` must be a single positive number.", call. = FALSE)
  }

  if (!is.numeric(channels) || length(channels) != 1 || is.na(channels) || channels < 1) {
    stop("`channels` must be a single positive number.", call. = FALSE)
  }

  if (!is.numeric(bits_per_sample) || length(bits_per_sample) != 1 || is.na(bits_per_sample) || bits_per_sample < 1) {
    stop("`bits_per_sample` must be a single positive number.", call. = FALSE)
  }

  audio_data <- x

  if (is.list(x)) {
    part <- .extract_gemini_part(x)

    if (is.null(part$inlineData) || is.null(part$inlineData$data)) {
      stop("Gemini response does not contain inline audio data.", call. = FALSE)
    }

    audio_data <- part$inlineData$data
  }

  if (!is.character(audio_data) || length(audio_data) != 1 || !nzchar(audio_data)) {
    stop("`x` must contain a non-empty base64 audio string.", call. = FALSE)
  }

  audio_raw <- jsonlite::base64_dec(audio_data)
  out <- audio_raw

  if (identical(format, "wav")) {
    out <- c(
      .wav_header(
        data_size = length(audio_raw),
        sample_rate = as.integer(sample_rate),
        channels = as.integer(channels),
        bits_per_sample = as.integer(bits_per_sample)
      ),
      audio_raw
    )
  }

  con <- file(path, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(out, con)

  invisible(path)
}
