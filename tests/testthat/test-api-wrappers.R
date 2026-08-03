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

test_that("query_gemini_content accepts explicit multimodal parts", {
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
          body = '{"candidates":[{"content":{"parts":[{"text":"Multimodal reply"}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  parts <- list(
    list(text = "Describe this clip"),
    list(inlineData = list(mimeType = "audio/mp3", data = "AQID"))
  )

  expect_equal(
    query_gemini_content(parts = parts, api_key = "key", model = "gemini-2.5-flash"),
    "Multimodal reply"
  )
  expect_error(
    query_gemini_content(prompt = "hello", parts = parts, api_key = "key", model = "gemini-2.5-flash"),
    "Supply either `prompt` or `parts`, not both."
  )
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

test_that("embed_gemini returns numeric matrices for single and batch inputs", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      req$body <- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      body <- if (grepl("batchEmbedContents", req$url, fixed = TRUE)) {
        '{"embeddings":[{"values":[0.1,0.2]},{"values":[0.3,0.4]}]}'
      } else {
        '{"embedding":{"values":[0.1,0.2]}}'
      }

      structure(list(status = 200L, body = body), class = "httr2_response")
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  single <- embed_gemini("hello", api_key = "key")
  expect_equal(dim(single), c(1, 2))
  expect_equal(single[1, ], c(0.1, 0.2))

  batch <- embed_gemini(c("hello", "world"), api_key = "key")
  expect_equal(dim(batch), c(2, 2))
  expect_equal(batch[2, ], c(0.3, 0.4))
})

test_that("generate_image_gemini returns base64 image payloads", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"candidates":[{"content":{"parts":[{"text":"Here is your image"},{"inlineData":{"mimeType":"image/png","data":"iVBORw0KGgo="}}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(generate_image_gemini("draw a cat", api_key = "key"), "iVBORw0KGgo=")
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

test_that("OpenAI-compatible wrappers handle non-JSON HTTP errors", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(status = 503L, body = "<html>service unavailable</html>"),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(
    query_cerebras("hello", api_key = "key"),
    "Cerebras API request failed: <html>service unavailable</html>",
    fixed = TRUE
  )
})

test_that("query_groq parses streaming SSE responses", {
  captured_body <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured_body <<- body
      req$body <- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            'data: {"id":"chat-1","choices":[{"delta":{"role":"assistant"}}]}\n\n',
            'data: {"id":"chat-1","choices":[{"delta":{"content":"Streamed"}}]}\n\n',
            'data: {"id":"chat-1","choices":[{"delta":{"content":" reply"},"finish_reason":"stop"}]}\n\n',
            'data: [DONE]\n\n'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_groq("hello", api_key = "key", stream = TRUE), "Streamed reply")
  expect_true(captured_body$stream)

  chunks <- query_groq("hello", api_key = "key", stream = TRUE, json_list = TRUE)
  expect_length(chunks, 3L)
  expect_equal(chunks[[2]]$choices[[1]]$delta$content, "Streamed")
})

test_that("query_groq surfaces streaming API errors", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(status = 200L, body = 'data: {"error":{"message":"upstream failed"}}\n\ndata: [DONE]\n\n'),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(query_groq("hello", api_key = "key", stream = TRUE), "Groq API error: upstream failed")
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

test_that("list_openrouter_video_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"data":[{"id":"google/veo-3.1","name":"Veo 3.1",',
            '"supported_resolutions":["720p"],',
            '"supported_durations":[5,8],',
            '"supported_aspect_ratios":["16:9"],',
            '"pricing_skus":{"generate":"0.50"}}]}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_openrouter_video_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$id[[1]], "google/veo-3.1")
  expect_equal(unlist(models$supported_resolutions[[1]], use.names = FALSE), "720p")

  json <- list_openrouter_video_models(api_key = "key", json_list = TRUE)
  expect_equal(json$data[[1]]$pricing_skus$generate, "0.50")
})

test_that("list_openrouter_benchmarks normalizes Artificial Analysis results", {
  captured_url <- NULL
  testthat::local_mocked_bindings(
    request = function(url) {
      captured_url <<- url
      structure(list(url = url), class = "request")
    },
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"data":[{"source":"artificial-analysis",',
            '"model_permaslug":"openai/gpt-4o","display_name":"GPT-4o",',
            '"intelligence_index":71.2,"coding_index":65.8,"agentic_index":58.3,',
            '"pricing":{"prompt":"0.0000025","completion":"0.00001"}}],',
            '"meta":{"as_of":"2026-06-03T12:00:00Z",',
            '"source_url":"https://artificialanalysis.ai"}}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  benchmarks <- list_openrouter_benchmarks(
    api_key = "key",
    source = "artificial-analysis",
    task_type = "coding"
  )

  expect_s3_class(benchmarks, "data.table")
  expect_equal(benchmarks$metric, c("intelligence_index", "coding_index", "agentic_index"))
  expect_equal(benchmarks$score, c(71.2, 65.8, 58.3))
  expect_equal(benchmarks$score_unit, rep("index_points", 3))
  expect_equal(benchmarks$prompt_price_per_token[[1]], 0.0000025)
  expect_equal(benchmarks$completion_price_per_token[[1]], 0.00001)
  expect_equal(benchmarks$price_basis, rep("source_reported_per_token", 3))
  expect_equal(benchmarks$source_as_of, rep("2026-06-03T12:00:00Z", 3))
  expect_true(all(benchmarks$source_url == "https://artificialanalysis.ai"))
  expect_match(captured_url, "source=artificial-analysis&task_type=coding", fixed = TRUE)
})

test_that("list_openrouter_benchmarks preserves OpenRouter task results", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"data":[{"source":"openrouter","model_permaslug":"openai/gpt-4o",',
            '"display_name":"GPT-4o","benchmark_type":"gpqa_diamond",',
            '"accuracy":0.72,"accuracy_stddev":0.03,"avg_cost_per_task":0.002,',
            '"total_tasks":300,"last_run_timestamp":"2026-06-03T12:00:00Z"}],',
            '"meta":{"source_url":"https://openrouter.ai/benchmarks"}}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  benchmarks <- list_openrouter_benchmarks(api_key = "key", source = "openrouter")

  expect_equal(benchmarks$metric, "gpqa_diamond")
  expect_equal(benchmarks$score, 0.72)
  expect_equal(benchmarks$score_unit, "proportion")
  expect_true(is.na(benchmarks$price_basis))
  expect_equal(benchmarks$accuracy_stddev, 0.03)
  expect_equal(benchmarks$avg_cost_per_task, 0.002)
  expect_equal(benchmarks$total_tasks, 300L)
  expect_equal(benchmarks$last_run_timestamp, "2026-06-03T12:00:00Z")
  expect_true(is.na(benchmarks$source_as_of))
})

test_that("list_openrouter_benchmarks handles sparse Design Arena results", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"data":[{"source":"design-arena","model_permaslug":"model-a",',
            '"display_name":"Model A","elo":1245,"win_rate":0.61,"rank":4}],',
            '"meta":{}}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  benchmarks <- list_openrouter_benchmarks(api_key = "key", source = "design-arena")

  expect_equal(benchmarks$metric, c("elo", "win_rate", "rank"))
  expect_equal(benchmarks$score, c(1245, 0.61, 4))
  expect_equal(benchmarks$score_unit, c("elo_points", "proportion", "ordinal_rank"))
  expect_true(all(is.na(benchmarks$avg_cost_per_task)))
  expect_true(all(is.na(benchmarks$accuracy_stddev)))
  expect_true(all(is.na(benchmarks$total_tasks)))
  expect_true(all(is.na(benchmarks$last_run_timestamp)))
  expect_true(all(is.na(benchmarks$source_as_of)))
  expect_equal(benchmarks$source_url, rep("https://openrouter.ai/api/v1/benchmarks?source=design-arena", 3))
})

test_that("list_openrouter_benchmarks returns typed empty results and validates filters", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(list(status = 200L, body = '{"data":[],"meta":{}}'), class = "httr2_response")
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  benchmarks <- list_openrouter_benchmarks(api_key = "key")
  expect_s3_class(benchmarks, "data.table")
  expect_equal(nrow(benchmarks), 0L)
  expect_identical(typeof(benchmarks$score), "double")
  expect_identical(typeof(benchmarks$total_tasks), "integer")
  expect_identical(typeof(benchmarks$score_unit), "character")
  expect_identical(typeof(benchmarks$price_basis), "character")
  expect_identical(typeof(benchmarks$source_as_of), "character")
  expect_s3_class(benchmarks$fetched_at, "POSIXct")
  expect_error(list_openrouter_benchmarks(api_key = "key", source = "unknown"), "`source` must be NULL")
  expect_error(list_openrouter_benchmarks(api_key = "key", task_type = "math"), "`task_type` must be NULL")
})

test_that("extract_openrouter_benchmarks flattens benchmark metadata", {
  models <- list(
    data = list(
      list(
        id = "openai/gpt-4",
        name = "GPT-4",
        artificial_analysis = list(
          coding = 64.2,
          math = 71.5,
          long_context = list(`100k` = 58.1, `1m` = 42.7)
        )
      ),
      list(
        id = "google/gemini-2.5-pro",
        name = "Gemini 2.5 Pro",
        benchmark_scores = list(science = 68.4)
      )
    )
  )

  benchmarks <- extract_openrouter_benchmarks(models)
  expect_s3_class(benchmarks, "data.table")
  expect_true(nrow(benchmarks) >= 5)
  expect_true(any(benchmarks$model_id == "openai/gpt-4"))
  expect_true(any(benchmarks$metric == "coding"))
  expect_true(any(benchmarks$metric == "long_context.100k"))
  expect_true(any(benchmarks$benchmark_field == "benchmark_scores"))
})

test_that("OpenRouter category model wrappers filter from model metadata", {
  mock_models <- list(
    data = list(
      list(
        id = "embed-a",
        name = "Embed A",
        architecture = list(
          input_modalities = list("text"),
          output_modalities = list("embeddings")
        )
      ),
      list(
        id = "image-a",
        name = "Image A",
        architecture = list(
          input_modalities = list("text"),
          output_modalities = list("image")
        )
      ),
      list(
        id = "audio-a",
        name = "Audio A",
        architecture = list(
          input_modalities = list("audio", "text"),
          output_modalities = list("text")
        )
      ),
      list(
        id = "multi-a",
        name = "Multi A",
        architecture = list(
          input_modalities = list("text", "image"),
          output_modalities = list("text")
        )
      )
    )
  )

  testthat::local_mocked_bindings(
    list_openrouter_models = function(api_key = Sys.getenv("OPENROUTER_API_KEY"), url = "https://openrouter.ai/api/v1/models", json_list = FALSE) {
      if (json_list) {
        return(mock_models)
      }

      .openrouter_model_rows(mock_models$data)
    },
    .package = "inferencer"
  )

  embed_dt <- list_openrouter_embedding_models(api_key = "key")
  expect_equal(embed_dt$id, "embed-a")

  image_json <- list_openrouter_image_models(api_key = "key", json_list = TRUE)
  expect_equal(image_json$data[[1]]$id, "image-a")

  audio_dt <- list_openrouter_audio_models(api_key = "key")
  expect_equal(audio_dt$id, "audio-a")

  multi_dt <- list_openrouter_multimodal_models(api_key = "key")
  expect_equal(multi_dt$id, c("audio-a", "multi-a"))
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

test_that("query_openrouter sends log probability parameters", {
  captured_body <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured_body <<- body
      req$body <- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"choices":[{"message":{"content":"answer"},"logprobs":{"content":[',
            '{"token":"answer","logprob":-0.1,"top_logprobs":[]}]}}]}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  response <- query_openrouter(
    "hello",
    api_key = "key",
    logprobs = TRUE,
    top_logprobs = 5,
    json_list = TRUE
  )

  expect_true(captured_body$logprobs)
  expect_identical(captured_body$top_logprobs, 5L)
  expect_equal(response$choices[[1]]$logprobs$content[[1]]$logprob, -0.1)
  expect_error(query_openrouter("hello", api_key = "key", logprobs = 1), "`logprobs` must be TRUE or FALSE.")
  expect_error(query_openrouter("hello", api_key = "key", top_logprobs = 5), "requires `logprobs = TRUE`")
  expect_error(
    query_openrouter("hello", api_key = "key", logprobs = TRUE, top_logprobs = 21),
    "integer from 0 through 20"
  )
})

test_that("OpenAI-compatible transport accepts provider parameters", {
  captured_body <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured_body <<- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(status = 200L, body = '{"choices":[{"message":{"content":"ok"}}]}'),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  response <- inferencer:::.openai_compatible_chat_request(
    url = "https://example.com/chat/completions",
    api_key = "key",
    provider = "Example",
    model = "model-a",
    messages = list(list(role = "user", content = "hello")),
    parameters = list(seed = 42L, response_format = list(type = "json_object"))
  )

  expect_equal(response$choices[[1]]$message$content, "ok")
  expect_identical(captured_body$seed, 42L)
  expect_equal(captured_body$response_format$type, "json_object")
})

test_that("query_openai returns Responses API text and raw JSON", {
  captured_body <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured_body <<- body
      req$body <- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"id":"resp_1","status":"completed","output":[{"type":"message",',
            '"content":[{"type":"output_text","text":"OpenAI reply"}]}]}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  tools <- list(list(type = "web_search"))
  expect_equal(
    query_openai(
      "hello",
      api_key = "key",
      instructions = "Answer briefly.",
      max_output_tokens = 100,
      tools = tools
    ),
    "OpenAI reply"
  )
  expect_equal(captured_body$model, "gpt-5.6")
  expect_equal(captured_body$input, "hello")
  expect_identical(captured_body$max_output_tokens, 100L)
  expect_equal(captured_body$tools, tools)

  response <- query_openai("hello", api_key = "key", json_list = TRUE)
  expect_equal(response$id, "resp_1")
})

test_that("list_openai_models returns a data table or raw JSON", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = paste0(
            '{"object":"list","data":[',
            '{"id":"gpt-5.6","object":"model","created":1785686400,"owned_by":"openai"}',
            ']}'
          )
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_openai_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$id, "gpt-5.6")
  expect_equal(models$owned_by, "openai")

  response <- list_openai_models(api_key = "key", json_list = TRUE)
  expect_equal(response$data[[1]]$id, "gpt-5.6")
})

test_that("list_openai_models surfaces API and shape errors", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(list(status = 401L, body = '{"error":{"message":"bad key"}}'), class = "httr2_response")
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(list_openai_models(api_key = "key"), "OpenAI API error: bad key")

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(list(status = 200L, body = '{"object":"list"}'), class = "httr2_response")
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(list_openai_models(api_key = "key"), "does not contain a `data` list")
})

test_that("query_openai supports structured input and API errors", {
  captured_body <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured_body <<- body
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(status = 200L, body = '{"output_text":"Structured reply"}'),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  input <- list(list(role = "user", content = list(list(type = "input_text", text = "hello"))))
  expect_equal(query_openai(input, api_key = "key"), "Structured reply")
  expect_equal(captured_body$input, input)
  expect_error(query_openai("", api_key = "key"), "`input` must be a non-empty character string or list.")
  expect_error(query_openai("hello", api_key = "key", max_output_tokens = 1.5), "positive integer")

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(status = 401L, body = '{"error":{"message":"bad key"}}'),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(query_openai("hello", api_key = "key"), "OpenAI API error: bad key")
})

test_that("query_openrouter_content accepts multimodal content blocks", {
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
          body = '{"choices":[{"message":{"content":"Vision reply"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  content <- list(
    list(type = "text", text = "What is in this image?"),
    list(type = "image_url", image_url = list(url = "https://example.com/test.png"))
  )

  expect_equal(
    query_openrouter_content(content, api_key = "key", model = "meta-llama/llama-3.3-70b-instruct:free"),
    "Vision reply"
  )
})

test_that("query_fallback returns the first successful provider response", {
  testthat::local_mocked_bindings(
    query_gemini = function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"), json_list = FALSE, ...) {
      stop("Gemini down", call. = FALSE)
    },
    query_openrouter = function(prompt, api_key = Sys.getenv("OPENROUTER_API_KEY"), json_list = FALSE, ...) {
      if (json_list) {
        return(list(text = "OpenRouter reply"))
      }
      "OpenRouter reply"
    },
    query_groq = function(prompt, api_key = Sys.getenv("GROQ_API_KEY"), json_list = FALSE, ...) {
      stop("Groq should not be called", call. = FALSE)
    },
    .package = "inferencer"
  )

  expect_equal(query_fallback("hello"), "OpenRouter reply")

  json <- query_fallback("hello", json_list = TRUE)
  expect_equal(json$provider, "openrouter")
  expect_equal(json$response$text, "OpenRouter reply")
})

test_that("query_fallback reports all provider failures", {
  testthat::local_mocked_bindings(
    query_gemini = function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"), json_list = FALSE, ...) {
      stop("Gemini down", call. = FALSE)
    },
    query_openrouter = function(prompt, api_key = Sys.getenv("OPENROUTER_API_KEY"), json_list = FALSE, ...) {
      stop("OpenRouter down", call. = FALSE)
    },
    query_groq = function(prompt, api_key = Sys.getenv("GROQ_API_KEY"), json_list = FALSE, ...) {
      stop("Groq down", call. = FALSE)
    },
    .package = "inferencer"
  )

  expect_error(
    query_fallback("hello"),
    "All fallback providers failed"
  )
  expect_error(
    query_fallback("hello"),
    "gemini: Gemini down"
  )
  expect_error(
    query_fallback("hello"),
    "openrouter: OpenRouter down"
  )
  expect_error(
    query_fallback("hello"),
    "groq: Groq down"
  )
})

test_that("query_openrouter_content parses text blocks and catches truncation", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"finish_reason":"stop","message":{"content":[{"type":"output_text","content":"Block reply"}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_openrouter_content("hello", api_key = "key"), "Block reply")

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_error(
    query_openrouter_content("hello", api_key = "key"),
    "OpenRouter response was truncated"
  )
})

test_that("embed_openrouter returns a numeric matrix", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"data":[{"embedding":[0.1,0.2]},{"embedding":[0.3,0.4]}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  embeddings <- embed_openrouter(c("hello", "world"), api_key = "key")
  expect_equal(dim(embeddings), c(2, 2))
  expect_equal(embeddings[1, ], c(0.1, 0.2))
  expect_error(embed_openrouter("hello", api_key = "key", encoding_format = "base64"), "json_list = TRUE")
})

test_that("generate_image_openrouter returns the first image url", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"choices":[{"message":{"images":[{"image_url":{"url":"https://example.com/image.png"}}]}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(
    generate_image_openrouter("draw a skyline", api_key = "key"),
    "https://example.com/image.png"
  )
})

test_that("list_ollama_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"models":[{"name":"gpt-oss:120b","model":"gpt-oss:120b","details":{"family":"gpt-oss"}}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_ollama_models(api_key = "key")
  expect_s3_class(models, "data.table")
  expect_equal(models$name[[1]], "gpt-oss:120b")

  json <- list_ollama_models(api_key = "key", json_list = TRUE)
  expect_equal(json$models[[1]]$details$family, "gpt-oss")
})

test_that("query_ollama returns text, json, and validates prompt", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) req,
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"message":{"role":"assistant","content":"Ollama reply"},"done":true}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  expect_equal(query_ollama("hello", api_key = "key"), "Ollama reply")
  expect_equal(query_ollama("hello", api_key = "key", json_list = TRUE)$message$content, "Ollama reply")
  expect_error(query_ollama("", api_key = "key"), "`prompt` must be a non-empty character string.")
})

test_that("query_cerebras returns text, json, and validates prompt", {
  captured <- NULL
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_headers = function(req, ...) req,
    req_body_json = function(req, body, auto_unbox = TRUE) {
      captured <<- body
      req
    },
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
  expect_equal(captured$model, "gpt-oss-120b")

  expect_equal(
    query_cerebras("hello", model = "gemma-4-31b", api_key = "key"),
    "Cerebras reply"
  )
  expect_equal(captured$model, "gemma-4-31b")

  expect_error(query_cerebras("", api_key = "key"), "`prompt` must be a non-empty character string.")
  expect_error(query_cerebras("hello", model = "", api_key = "key"), "`model` must be a non-empty character string.")
})

test_that("list_cerebras_models returns a data table or json list", {
  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "request"),
    req_error = function(req, is_error) req,
    req_perform = function(req) {
      structure(
        list(
          status = 200L,
          body = '{"object":"list","data":[{"id":"gpt-oss-120b","name":"OpenAI GPT OSS","deprecated":false},{"id":"gemma-4-31b","name":"Gemma 4 31B","deprecated":false}]}'
        ),
        class = "httr2_response"
      )
    },
    resp_body_string = function(resp) resp$body,
    resp_status = function(resp) resp$status,
    .package = "httr2"
  )

  models <- list_cerebras_models()
  expect_s3_class(models, "data.table")
  expect_equal(models$id[[1]], "gpt-oss-120b")

  json <- list_cerebras_models(json_list = TRUE)
  expect_equal(json$data[[2]]$name, "Gemma 4 31B")
})
