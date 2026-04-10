# inferencer 0.1.4.2

- Added an R-side `query_fallback()` wrapper with ordered fallback across Gemini, OpenRouter, and Groq.
- Added tests and documentation for the new R fallback helper.

# inferencer 0.1.4.1

- Improved the shipped shell markdown renderer for headings, bullets, horizontal rules, and pipe tables.
- Changed shell query helpers to take prompt as the first argument and optional model override as the second.
- Made shell query helpers render markdown automatically on successful text responses.
- Updated `query_fallback()` to use the default models of `query_gemini()`, `query_openrouter()`, and `query_groq()`.

# inferencer 0.1.4

- Added a zsh-oriented shell companion under `inst/shell/inferencer.sh`.
- Added shell wrappers for Gemini, Groq, OpenRouter, Cerebras, and Ollama Cloud.
- Added `query_fallback()` for ordered shell failover across Gemini, OpenRouter, and Groq.
- Added shell documentation and README examples for sourcing and using the shipped scripts.

# inferencer 0.1.3.2

- Added Ollama Cloud model listing and chat-query wrappers.
- Updated package metadata to use the maintainer email `oliver.yxzhou@gmail.com`.

# inferencer 0.1.3.1

- Changed the default OpenRouter model to `openrouter/free`.
- Increased the default OpenRouter token budget to reduce truncation.
- Improved OpenRouter response parsing and truncation error handling for alias models.

# inferencer 0.1.3

- Added Gemini and OpenRouter embedding helpers.
- Added Gemini and OpenRouter image-generation helpers.
- Added Gemini and OpenRouter multimodal query wrappers for generic non-text inputs.

# inferencer 0.1.2

- Standardized provider HTTP requests on `httr2`.
- Added shared internal request, response, and chat-content helpers.
- Moved OpenRouter model reshaping into an internal helper.
- Removed `httr` and `curl` from package imports.
