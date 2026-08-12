.list_openai_compatible_models <- function(api_key, env_name, url, provider, timeout) {
  .require_api_key(api_key, env_name)

  parsed <- .openai_json_request(
    url = url,
    api_key = api_key,
    body = NULL,
    provider = provider,
    api_error_prefix = paste0(provider, " API error"),
    timeout = timeout
  )

  if (is.null(parsed$data) || !is.list(parsed$data)) {
    stop(sprintf("%s API response does not contain a `data` list.", provider), call. = FALSE)
  }

  parsed
}

.query_openai_compatible_text <- function(
  prompt,
  model,
  api_key,
  env_name,
  url,
  provider,
  temperature,
  top_p,
  max_tokens,
  timeout,
  json_list
) {
  .validate_non_empty_string(prompt, "prompt")
  .require_api_key(api_key, env_name)
  model <- .resolve_model_arg(model)

  if (!is.numeric(temperature) || length(temperature) != 1 || is.na(temperature) ||
      temperature < 0) {
    stop("`temperature` must be a single non-negative numeric value.", call. = FALSE)
  }
  if (!is.numeric(top_p) || length(top_p) != 1 || is.na(top_p) || top_p < 0 || top_p > 1) {
    stop("`top_p` must be a single numeric value between 0 and 1.", call. = FALSE)
  }
  if (!is.numeric(max_tokens) || length(max_tokens) != 1 || is.na(max_tokens) ||
      max_tokens < 1) {
    stop("`max_tokens` must be a single positive number.", call. = FALSE)
  }

  parsed <- .openai_compatible_chat_request(
    url = url,
    api_key = api_key,
    provider = provider,
    model = model,
    messages = list(list(role = "user", content = prompt)),
    parameters = list(
      temperature = temperature,
      top_p = top_p,
      max_tokens = max_tokens
    ),
    api_error_prefix = paste0(provider, " API error"),
    timeout = timeout
  )

  if (json_list) return(parsed)
  .extract_openai_chat_content(parsed, provider)
}

#' List Qwen Models
#'
#' Retrieves models available from Alibaba Cloud Model Studio.
#'
#' @param api_key Qwen API key. Defaults to `Sys.getenv("DASHSCOPE_API_KEY")`.
#' @param url Qwen OpenAI-compatible models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_qwen_models <- function(
  api_key = Sys.getenv("DASHSCOPE_API_KEY"),
  url = Sys.getenv("QWEN_MODELS_URL", unset = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models"),
  json_list = FALSE,
  timeout = 120
) {
  parsed <- .list_openai_compatible_models(
    api_key, "DASHSCOPE_API_KEY", url, "Qwen", timeout
  )
  if (json_list) return(parsed)
  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query a Qwen Model
#'
#' Sends a prompt to Alibaba Cloud Model Studio's OpenAI-compatible chat
#' endpoint.
#'
#' @param prompt A non-empty character string.
#' @param model Model identifier.
#' @param temperature Sampling temperature.
#' @param top_p Nucleus sampling parameter.
#' @param max_tokens Maximum number of output tokens.
#' @param api_key Qwen API key. Defaults to `Sys.getenv("DASHSCOPE_API_KEY")`.
#' @param url Qwen OpenAI-compatible chat completions endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A character string by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @seealso [list_qwen_models()]
#' @export
query_qwen <- function(
  prompt,
  model = "qwen-plus",
  temperature = 0.7,
  top_p = 1,
  max_tokens = 2048L,
  api_key = Sys.getenv("DASHSCOPE_API_KEY"),
  url = Sys.getenv("QWEN_API_URL", unset = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"),
  json_list = FALSE,
  timeout = 120
) {
  .query_openai_compatible_text(
    prompt, model, api_key, "DASHSCOPE_API_KEY", url, "Qwen", temperature,
    top_p, max_tokens, timeout, json_list
  )
}

#' List Zhipu Models
#'
#' Retrieves models available from the Zhipu AI Open Platform.
#'
#' @param api_key Zhipu AI API key. Defaults to `Sys.getenv("ZHIPUAI_API_KEY")`.
#' @param url Zhipu OpenAI-compatible models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_zhipu_models <- function(
  api_key = Sys.getenv("ZHIPUAI_API_KEY"),
  url = "https://open.bigmodel.cn/api/paas/v4/models",
  json_list = FALSE,
  timeout = 120
) {
  parsed <- .list_openai_compatible_models(
    api_key, "ZHIPUAI_API_KEY", url, "Zhipu", timeout
  )
  if (json_list) return(parsed)
  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query a Zhipu Model
#'
#' Sends a prompt to the Zhipu AI Open Platform's OpenAI-compatible chat
#' endpoint.
#'
#' @inheritParams query_qwen
#' @param api_key Zhipu AI API key. Defaults to `Sys.getenv("ZHIPUAI_API_KEY")`.
#' @param url Zhipu OpenAI-compatible chat completions endpoint.
#' @seealso [list_zhipu_models()]
#' @export
query_zhipu <- function(
  prompt,
  model = "glm-5",
  temperature = 0.7,
  top_p = 1,
  max_tokens = 2048L,
  api_key = Sys.getenv("ZHIPUAI_API_KEY"),
  url = "https://open.bigmodel.cn/api/paas/v4/chat/completions",
  json_list = FALSE,
  timeout = 120
) {
  .query_openai_compatible_text(
    prompt, model, api_key, "ZHIPUAI_API_KEY", url, "Zhipu", temperature,
    top_p, max_tokens, timeout, json_list
  )
}

#' List DeepSeek Models
#'
#' Retrieves models available from the DeepSeek API.
#'
#' @param api_key DeepSeek API key. Defaults to `Sys.getenv("DEEPSEEK_API_KEY")`.
#' @param url DeepSeek OpenAI-compatible models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_deepseek_models <- function(
  api_key = Sys.getenv("DEEPSEEK_API_KEY"),
  url = "https://api.deepseek.com/models",
  json_list = FALSE,
  timeout = 120
) {
  parsed <- .list_openai_compatible_models(
    api_key, "DEEPSEEK_API_KEY", url, "DeepSeek", timeout
  )
  if (json_list) return(parsed)
  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query a DeepSeek Model
#'
#' Sends a prompt to the DeepSeek OpenAI-compatible chat endpoint.
#'
#' @inheritParams query_qwen
#' @param api_key DeepSeek API key. Defaults to `Sys.getenv("DEEPSEEK_API_KEY")`.
#' @param url DeepSeek OpenAI-compatible chat completions endpoint.
#' @seealso [list_deepseek_models()]
#' @export
query_deepseek <- function(
  prompt,
  model = "deepseek-v4-flash",
  temperature = 0.7,
  top_p = 1,
  max_tokens = 2048L,
  api_key = Sys.getenv("DEEPSEEK_API_KEY"),
  url = "https://api.deepseek.com/chat/completions",
  json_list = FALSE,
  timeout = 120
) {
  .query_openai_compatible_text(
    prompt, model, api_key, "DEEPSEEK_API_KEY", url, "DeepSeek", temperature,
    top_p, max_tokens, timeout, json_list
  )
}

#' List Moonshot Models
#'
#' Retrieves models available from the Moonshot AI Kimi API.
#'
#' @param api_key Moonshot API key. Defaults to `Sys.getenv("MOONSHOT_API_KEY")`.
#' @param url Moonshot OpenAI-compatible models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_moonshot_models <- function(
  api_key = Sys.getenv("MOONSHOT_API_KEY"),
  url = "https://api.moonshot.ai/v1/models",
  json_list = FALSE,
  timeout = 120
) {
  parsed <- .list_openai_compatible_models(
    api_key, "MOONSHOT_API_KEY", url, "Moonshot", timeout
  )
  if (json_list) return(parsed)
  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query a Moonshot Model
#'
#' Sends a prompt to the Moonshot AI Kimi OpenAI-compatible chat endpoint.
#'
#' @inheritParams query_qwen
#' @param api_key Moonshot API key. Defaults to `Sys.getenv("MOONSHOT_API_KEY")`.
#' @param url Moonshot OpenAI-compatible chat completions endpoint.
#' @seealso [list_moonshot_models()]
#' @export
query_moonshot <- function(
  prompt,
  model = "kimi-k2.6",
  temperature = 0.7,
  top_p = 1,
  max_tokens = 2048L,
  api_key = Sys.getenv("MOONSHOT_API_KEY"),
  url = "https://api.moonshot.ai/v1/chat/completions",
  json_list = FALSE,
  timeout = 120
) {
  .query_openai_compatible_text(
    prompt, model, api_key, "MOONSHOT_API_KEY", url, "Moonshot", temperature,
    top_p, max_tokens, timeout, json_list
  )
}

#' List MiniMax Models
#'
#' Retrieves models available from the MiniMax API.
#'
#' @param api_key MiniMax API key. Defaults to `Sys.getenv("MINIMAX_API_KEY")`.
#' @param url MiniMax OpenAI-compatible models endpoint.
#' @param json_list If `TRUE`, return the parsed JSON response as a list.
#' @param timeout Maximum number of seconds to wait for the HTTP request.
#'
#' @return A `data.table` by default, or a parsed JSON list when
#'   `json_list = TRUE`.
#' @export
list_minimax_models <- function(
  api_key = Sys.getenv("MINIMAX_API_KEY"),
  url = Sys.getenv("MINIMAX_MODELS_URL", unset = "https://api.minimax.io/v1/models"),
  json_list = FALSE,
  timeout = 120
) {
  parsed <- .list_openai_compatible_models(
    api_key, "MINIMAX_API_KEY", url, "MiniMax", timeout
  )
  if (json_list) return(parsed)
  data.table::rbindlist(parsed$data, fill = TRUE)
}

#' Query a MiniMax Model
#'
#' Sends a prompt to the MiniMax OpenAI-compatible chat endpoint.
#'
#' @inheritParams query_qwen
#' @param api_key MiniMax API key. Defaults to `Sys.getenv("MINIMAX_API_KEY")`.
#' @param url MiniMax OpenAI-compatible chat completions endpoint.
#' @seealso [list_minimax_models()]
#' @export
query_minimax <- function(
  prompt,
  model = "MiniMax-M2.7",
  temperature = 0.7,
  top_p = 1,
  max_tokens = 2048L,
  api_key = Sys.getenv("MINIMAX_API_KEY"),
  url = Sys.getenv("MINIMAX_API_URL", unset = "https://api.minimax.io/v1/chat/completions"),
  json_list = FALSE,
  timeout = 120
) {
  .query_openai_compatible_text(
    prompt, model, api_key, "MINIMAX_API_KEY", url, "MiniMax", temperature,
    top_p, max_tokens, timeout, json_list
  )
}

.china_fallback <- function(prompt, json_list, timeout, attempts) {
  .validate_non_empty_string(prompt, "prompt")
  timeout <- .validate_timeout(timeout)
  failures <- character()

  for (attempt in attempts) {
    result <- tryCatch(attempt$fn(), error = function(error) error)
    if (!inherits(result, "error")) {
      if (json_list) return(list(provider = attempt$provider, response = result))
      return(result)
    }
    failures <- c(failures, sprintf("%s: %s", attempt$provider, conditionMessage(result)))
  }

  stop(
    sprintf("All mainland-China fallback providers failed. %s", paste(failures, collapse = " | ")),
    call. = FALSE
  )
}

#' Query Mainland-China Providers with Ordered Fallback
#'
#' Tries mainland-China-hosted provider APIs in order: Qwen, Zhipu, DeepSeek,
#' Moonshot, then MiniMax.
#'
#' @param prompt A non-empty character string.
#' @param json_list If `TRUE`, return a list containing the successful provider
#'   name and parsed response object.
#' @param timeout Maximum number of seconds to wait for each provider request.
#' @param api_key_qwen Qwen API key. Defaults to `Sys.getenv("DASHSCOPE_API_KEY")`.
#' @param api_key_zhipu Zhipu AI API key. Defaults to `Sys.getenv("ZHIPUAI_API_KEY")`.
#' @param api_key_deepseek DeepSeek API key. Defaults to `Sys.getenv("DEEPSEEK_API_KEY")`.
#' @param api_key_moonshot Moonshot API key. Defaults to `Sys.getenv("MOONSHOT_API_KEY")`.
#' @param api_key_minimax MiniMax API key. Defaults to `Sys.getenv("MINIMAX_API_KEY")`.
#'
#' @return A character string by default. When `json_list = TRUE`, returns a
#'   list with elements `provider` and `response`.
#' @export
query_china_fallback <- function(
  prompt,
  json_list = FALSE,
  timeout = 120,
  api_key_qwen = Sys.getenv("DASHSCOPE_API_KEY"),
  api_key_zhipu = Sys.getenv("ZHIPUAI_API_KEY"),
  api_key_deepseek = Sys.getenv("DEEPSEEK_API_KEY"),
  api_key_moonshot = Sys.getenv("MOONSHOT_API_KEY"),
  api_key_minimax = Sys.getenv("MINIMAX_API_KEY")
) {
  .china_fallback(prompt, json_list, timeout, list(
    list(provider = "qwen", fn = function() query_qwen(prompt, api_key = api_key_qwen, json_list = json_list, timeout = timeout)),
    list(provider = "zhipu", fn = function() query_zhipu(prompt, api_key = api_key_zhipu, json_list = json_list, timeout = timeout)),
    list(provider = "deepseek", fn = function() query_deepseek(prompt, api_key = api_key_deepseek, json_list = json_list, timeout = timeout)),
    list(provider = "moonshot", fn = function() query_moonshot(prompt, api_key = api_key_moonshot, json_list = json_list, timeout = timeout)),
    list(provider = "minimax", fn = function() query_minimax(prompt, api_key = api_key_minimax, json_list = json_list, timeout = timeout))
  ))
}

#' List Verified No-Cost Mainland-China Models
#'
#' Returns models that Inferencer can verify as no-cost APIs rather than models
#' with account-specific trials or expiring promotional quotas.
#'
#' @return A `data.table` with provider, model, free_basis, and source_url.
#' @export
list_china_free_models <- function() {
  data.table::data.table(
    provider = "zhipu",
    model = "glm-z1-flash",
    free_basis = "Documented permanently free API model",
    source_url = "https://docs.bigmodel.cn/cn/guide/models/free/glm-z1-flash"
  )
}

#' Query a Verified No-Cost Mainland-China Model
#'
#' Calls only the currently verified no-cost mainland-China model. This avoids
#' treating account-specific free trials as universally free and therefore does
#' not silently route a request to a paid model.
#'
#' @param prompt A non-empty character string.
#' @param json_list If `TRUE`, return a list containing the successful provider
#'   name and parsed response object.
#' @param timeout Maximum number of seconds to wait for the provider request.
#' @param api_key_zhipu Zhipu AI API key. Defaults to `Sys.getenv("ZHIPUAI_API_KEY")`.
#'
#' @return A character string by default. When `json_list = TRUE`, returns a
#'   list with elements `provider` and `response`.
#' @seealso [list_china_free_models()]
#' @export
query_china_free_fallback <- function(
  prompt,
  json_list = FALSE,
  timeout = 120,
  api_key_zhipu = Sys.getenv("ZHIPUAI_API_KEY")
) {
  .china_fallback(prompt, json_list, timeout, list(
    list(
      provider = "zhipu",
      fn = function() query_zhipu(
        prompt,
        model = "glm-z1-flash",
        api_key = api_key_zhipu,
        json_list = json_list,
        timeout = timeout
      )
    )
  ))
}
