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
