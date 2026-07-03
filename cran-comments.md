## R CMD check results

0 errors | 0 warnings | 2 notes

Notes:

* CRAN incoming and URL checks were unavailable in the local sandbox because
  DNS resolution was blocked.
* Local check environment was unable to verify the current time.

A follow-up network-enabled check confirmed the package URLs were reachable
and reported the expected new-submission NOTE, but the local check process
stalled later in the standard check sequence, so it was interrupted.

Additional checks:

* win-builder R-devel on Windows passed with 1 NOTE:
  https://win-builder.r-project.org/YW57sdGH9P0U/
* R-hub GitHub Actions checks passed on Linux, Windows, and macOS with R-devel:
  https://github.com/OliverLDS/inferencer/actions/runs/28589947133

## Submission notes

This is a new submission.

The win-builder NOTE flags possible misspellings in DESCRIPTION. These are
intentional provider/product names or technical terms: Cerebras, Groq,
Ollama, OpenRouter, and embeddings.

inferencer provides lightweight wrappers for hosted foundation model inference
APIs. Most user-facing API calls require provider-specific API keys configured
in environment variables such as `GEMINI_API_KEY`, `GROQ_API_KEY`,
`OPENROUTER_API_KEY`, `CEREBRAS_API_KEY`, and `OLLAMA_API_KEY`.

Examples are not included for live API calls, and tests use mocked HTTP
responses so CRAN checks do not depend on external services, API keys, quotas,
or network availability.

The package also ships optional `zsh` command-line helper scripts under
`inst/shell`. These scripts are not required for R package functionality and
depend on external `zsh`, `curl`, and `jq` commands when users choose to run
them manually.
