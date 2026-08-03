## R CMD check results

0 errors | 0 warnings | 0 notes

The source tarball passes a complete local `R CMD check` on macOS. A local
`R CMD check --as-cran` run under R 4.2.3 reaches the package checks but hangs
in that R version's S3-registration subprocess, as it did for the previous
release. Current R-devel checks are therefore also run through win-builder and
R-hub.

## Submission notes

This is an update to CRAN version 0.1.4.5.

Version 0.2.0 adds direct OpenAI Responses API and model-discovery wrappers,
OpenRouter log-probability controls, buffered Groq SSE response assembly, and a
shared internal transport for OpenAI-compatible chat endpoints. Provider-
specific exported wrappers remain available.

inferencer provides lightweight wrappers for hosted foundation model inference
APIs. User-facing API calls require provider-specific API keys configured in
environment variables such as `OPENAI_API_KEY`, `GEMINI_API_KEY`,
`GROQ_API_KEY`, `OPENROUTER_API_KEY`, `CEREBRAS_API_KEY`, and `OLLAMA_API_KEY`.

Examples do not call live APIs. The normal test suite uses mocked HTTP
responses, and live-provider smoke tests require an explicit opt-in environment
variable, so CRAN checks do not depend on external services, API keys, quotas,
or network availability.

The package also ships optional `zsh` command-line helper scripts under
`inst/shell`. These scripts are not required for R package functionality and
depend on external `zsh`, `curl`, and `jq` commands when users run them.
