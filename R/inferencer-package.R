#' inferencer: Simple Wrappers for Hosted Inference APIs
#'
#' The package provides lightweight helpers for listing models and sending
#' inference requests to hosted model APIs, currently including OpenAI, Gemini,
#' Groq, OpenRouter, Cerebras, Ollama Cloud, Qwen, Zhipu, DeepSeek, Moonshot,
#' and MiniMax. In addition to prompt-based text generation, it includes
#' wrappers for embeddings, image generation, and multimodal non-text inputs
#' where supported by the provider APIs. It also provides direct OpenRouter
#' benchmark retrieval and mainland-China-provider fallback helpers. Groq
#' streaming requests are buffered and assembled before return, rather than
#' emitted incrementally to the terminal. The package also ships small
#' executable shell companions under `inst/shell` for
#' terminal-based API calls that mirror common R wrapper workflows.
#'
#' @keywords internal
"_PACKAGE"

NULL
