live_provider_test <- function(api_key) {
  testthat::skip_if_not(
    identical(Sys.getenv("INFERENCER_LIVE_TESTS"), "true"),
    "Live provider tests are opt-in."
  )
  testthat::skip_if_not(nzchar(Sys.getenv(api_key)), paste(api_key, "is not set."))
}

test_that("OpenAI Responses and model discovery work against the live API", {
  live_provider_test("OPENAI_API_KEY")

  models <- list_openai_models()
  expect_s3_class(models, "data.table")
  expect_true(nrow(models) > 0L)
  expect_true(all(c("id", "object", "created", "owned_by") %in% names(models)))

  response <- query_openai("Reply with exactly: OPENAI_OK")
  expect_match(response, "OPENAI_OK", fixed = TRUE)
})

test_that("OpenRouter returns token and top-token log probabilities", {
  live_provider_test("OPENROUTER_API_KEY")
  model <- Sys.getenv(
    "INFERENCER_OPENROUTER_LOGPROBS_MODEL",
    unset = "openai/gpt-oss-20b:free"
  )

  response <- query_openrouter(
    "Reply with exactly one word: OK",
    model = model,
    logprobs = TRUE,
    top_logprobs = 2L,
    json_list = TRUE
  )
  logprobs <- response$choices[[1]]$logprobs$content

  expect_true(length(logprobs) > 0L)
  expect_true(length(logprobs[[1]]$top_logprobs) > 0L)
})

test_that("Groq buffered streaming assembles SSE text", {
  live_provider_test("GROQ_API_KEY")
  model <- Sys.getenv(
    "INFERENCER_GROQ_STREAM_MODEL",
    unset = "llama-3.1-8b-instant"
  )

  response <- query_groq(
    "Reply with exactly: GROQ_OK",
    model = model,
    stream = TRUE
  )
  expect_match(response, "GROQ_OK", fixed = TRUE)
})

test_that("Cerebras works through the shared compatible transport", {
  live_provider_test("CEREBRAS_API_KEY")

  response <- query_cerebras("Reply with exactly: CEREBRAS_OK")
  expect_match(response, "CEREBRAS_OK", fixed = TRUE)
})
