test_that("list_gemini_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"models":[{"name":"models/gemini-2.5-flash","displayName":"Gemini 2.5 Flash"}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_gemini_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$name[[1]], "models/gemini-2.5-flash")

  json <- list_gemini_models(api_key = "key", json_list = TRUE)
  expect_equal(json$models[[1]]$displayName, "Gemini 2.5 Flash")
})

test_that("query_gemini returns text and validates prompt", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"candidates":[{"content":{"parts":[{"text":"Gemini reply"}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_gemini("hello", api_key = "key"), "Gemini reply")

  json <- query_gemini("hello", api_key = "key", json_list = TRUE)
  expect_equal(json$candidates[[1]]$content$parts[[1]]$text, "Gemini reply")

  expect_error(query_gemini("", api_key = "key"), "`prompt` must be a non-empty character string.")
  expect_error(query_gemini("hello", api_key = "key", top_p = 2), "`top_p` must be between 0 and 1.")
  expect_error(query_gemini("hello", api_key = "key", top_k = 0), "`top_k` must be a single positive integer.")
})

test_that("query_gemini can return base64 audio data", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"candidates":[{"content":{"parts":[{"inlineData":{"mimeType":"audio/pcm","data":"AQID"}}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(
    query_gemini(
      "hello",
      api_key = "key",
      model = "gemini-2.5-flash-preview-tts",
      response_modalities = "AUDIO",
      speech_config = list(voiceConfig = list(prebuiltVoiceConfig = list(voiceName = "Kore")))
    ),
    "AQID"
  )

  json <- query_gemini(
    "hello",
    api_key = "key",
    model = "gemini-2.5-flash-preview-tts",
    response_modalities = "AUDIO",
    json_list = TRUE
  )
  expect_equal(json$candidates[[1]]$content$parts[[1]]$inlineData$data, "AQID")
})

test_that("write_gemini_audio writes pcm and wav files", {
  pcm_path <- tempfile(fileext = ".pcm")
  wav_path <- tempfile(fileext = ".wav")

  write_gemini_audio("AQID", pcm_path, format = "pcm")
  expect_true(file.exists(pcm_path))
  expect_equal(file.info(pcm_path)$size[[1]], 3)

  write_gemini_audio("AQID", wav_path, format = "wav")
  expect_true(file.exists(wav_path))
  expect_true(file.info(wav_path)$size[[1]] > 3)

  con <- file(wav_path, "rb")
  on.exit(close(con), add = TRUE)
  expect_equal(rawToChar(readBin(con, "raw", n = 4L)), "RIFF")
})

test_that("list_groq_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"data":[{"id":"llama-3.1-8b-instant","owned_by":"groq","public_apps":["app"]}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_groq_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$id[[1]], "llama-3.1-8b-instant")

  json <- list_groq_models(api_key = "key", json_list = TRUE)
  expect_equal(json$data[[1]]$owned_by, "groq")
})

test_that("query_groq returns text and surfaces API errors", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"message":{"content":"Groq reply"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_groq("hello", api_key = "key"), "Groq reply")
  expect_equal(query_groq("hello", api_key = "key", json_list = TRUE)$choices[[1]]$message$content, "Groq reply")

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(list(status = 401L, body = '{"error":{"message":"bad key"}}'), class = "httr2_response")
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(query_groq("hello", api_key = "key"), "Groq API request failed")
})

test_that("query_groq validates local parameters", {
  expect_error(query_groq("hello", api_key = "key", top_p = 2), "`top_p` must be between 0 and 1.")
  expect_error(query_groq("hello", api_key = "key", stream = "yes"), "`stream` must be TRUE or FALSE.")
})

test_that("list_openrouter_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"data":[{"id":"model-a","name":"Model A"}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_openrouter_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$id[[1]], "model-a")

  json <- list_openrouter_models(api_key = "key", json_list = TRUE)
  expect_equal(json$data[[1]]$name, "Model A")
})

test_that("query_openrouter returns text, json, and API errors", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      req$body <- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"message":{"content":"OpenRouter reply"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_openrouter("hello", api_key = "key"), "OpenRouter reply")
  expect_equal(query_openrouter("hello", api_key = "key", json_list = TRUE)$choices[[1]]$message$content, "OpenRouter reply")

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 400L,
          body = '{"error":{"message":"bad request"}}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(query_openrouter("hello", api_key = "key"), "OpenRouter API error: bad request")
  expect_error(query_openrouter("hello", api_key = "key", temperature = -1), "`temperature` must be greater than or equal to 0.")
  expect_error(query_openrouter("hello", api_key = "key", top_p = 2), "`top_p` must be between 0 and 1.")
})

test_that("query_cerebras returns text, json, and validates prompt", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"message":{"content":"Cerebras reply"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_cerebras("hello", api_key = "key"), "Cerebras reply")
  expect_equal(query_cerebras("hello", api_key = "key", json_list = TRUE)$choices[[1]]$message$content, "Cerebras reply")

  expect_error(query_cerebras("", api_key = "key"), "`prompt` must be a non-empty character string.")
})
