# inferencer

`inferencer` is a lightweight R package for calling hosted foundation model
inference APIs through a simple and mostly consistent interface. It also ships
with a small shell companion for the same providers when you want terminal
usage without writing R code.

It currently supports:

- Google Gemini
- Groq
- OpenRouter
- Cerebras
- Ollama Cloud

The package is intentionally minimal. It focuses on a few common tasks:

1. listing available models from each provider
2. sending simple prompt-based inference requests
3. requesting embeddings
4. working with image-generation and multimodal model inputs

It also includes Gemini TTS support through `query_gemini()` plus
`write_gemini_audio()`, OpenRouter and Gemini embedding helpers, Gemini and
OpenRouter image-generation helpers, and lower-level multimodal wrappers for
non-text inputs.

More advanced provider-specific parameters may be added gradually in future versions.

## Basic setup

Set your API keys first:

```r
Sys.setenv(GEMINI_API_KEY = "your_key_here")
Sys.setenv(GROQ_API_KEY = "your_key_here")
Sys.setenv(OPENROUTER_API_KEY = "your_key_here")
Sys.setenv(CEREBRAS_API_KEY = "your_key_here")
Sys.setenv(OLLAMA_API_KEY = "your_key_here")
```

Load the package:

```r
library(inferencer)
```

## Shell scripts

The package includes shell helpers in `inst/shell/inferencer.sh`. They are
kept inside `inferencer` because they mirror the R wrappers closely and stay
small enough not to justify a separate package. This shell layer is intended
for `zsh`, which matches the `.zprofile` setup and the bundled markdown
renderer.

The shell layer currently includes:

- `query_gemini`
- `query_groq`
- `query_openrouter`
- `query_cerebras`
- `query_ollama`
- `query_fallback`
- `render_markdown_terminal`

Source the script from the repo:

```sh
source inst/shell/inferencer.sh
```

Or from an installed package:

```r
system.file("shell", "inferencer.sh", package = "inferencer")
```

```sh
source "$(Rscript -e 'cat(system.file(\"shell\", \"inferencer.sh\", package = \"inferencer\"))')"
```

Shell API keys should live in `.zprofile`, not `.Renviron`, but they use the
same names as the R wrappers:

```sh
export GEMINI_API_KEY="your_key_here"
export GROQ_API_KEY="your_key_here"
export OPENROUTER_API_KEY="your_key_here"
export CEREBRAS_API_KEY="your_key_here"
export OLLAMA_API_KEY="your_key_here"
```

Example shell usage:

```sh
query_openrouter "Summarize the main uses of retrieval-augmented generation."
query_gemini "Write three title ideas for a data engineering memo."
query_ollama "Explain principal component analysis in one paragraph."
query_fallback "Draft a concise status update for today's analysis."
query_openrouter "Write release notes in markdown." | render_markdown_terminal
```

`query_fallback` uses this fixed order:

1. `query_gemini` with `GEMINI_MODEL=models/gemini-flash-latest`
2. `query_openrouter` with `OPENROUTER_MODEL=openrouter/free`
3. `query_groq` with `GROQ_MODEL=groq/compound`

If all three calls fail, it exits with a non-zero status.

## List available models

### Gemini

```r
gemini_models <- list_gemini_models()
head(gemini_models)
```

Parsed JSON list:

```r
gemini_json <- list_gemini_models(json_list = TRUE)
```

### Groq

```r
groq_models <- list_groq_models()
head(groq_models)
```

### OpenRouter

```r
openrouter_models <- list_openrouter_models()
head(openrouter_models)
```

Parsed JSON list:

```r
openrouter_json <- list_openrouter_models(json_list = TRUE)
```

### Ollama Cloud

```r
ollama_models <- list_ollama_models()
head(ollama_models)
```

## Query models

### Gemini

```r
query_gemini("Explain what a large language model is in simple terms.")
```

Specify model and generation settings:

```r
query_gemini(
  prompt = "Write three short taglines for an AI consulting firm.",
  model = "gemini-2.5-flash",
  temperature = 0.8,
  top_p = 0.95
)
```

Gemini TTS:

```r
audio_b64 <- query_gemini(
  prompt = paste(
    "TTS the following conversation between Joe and Jane:",
    "Joe: Hows it going today Jane?",
    "Jane: Not too bad, how about you?"
  ),
  model = "gemini-2.5-flash-preview-tts",
  response_modalities = "AUDIO",
  speech_config = list(
    multiSpeakerVoiceConfig = list(
      speakerVoiceConfigs = list(
        list(
          speaker = "Joe",
          voiceConfig = list(
            prebuiltVoiceConfig = list(voiceName = "Kore")
          )
        ),
        list(
          speaker = "Jane",
          voiceConfig = list(
            prebuiltVoiceConfig = list(voiceName = "Puck")
          )
        )
      )
    )
  )
)

write_gemini_audio(audio_b64, "out.wav", format = "wav")
```

Gemini embeddings:

```r
embed_gemini(c("machine learning", "data science"))
```

Gemini text-to-image:

```r
img_b64 <- generate_image_gemini("A watercolor skyline at sunrise")
```

Gemini multimodal input:

```r
query_gemini_content(
  parts = list(
    list(text = "Describe this audio clip."),
    list(inlineData = list(mimeType = "audio/mp3", data = "BASE64_AUDIO_HERE"))
  )
)
```

### Groq

```r
query_groq("Summarize the difference between R and Python in 5 bullet points.")
```

Specify model:

```r
query_groq(
  prompt = "Give me a concise explanation of vector databases.",
  model = "llama-3.3-70b-versatile",
  temperature = 0.2,
  max_tokens = 300
)
```

### OpenRouter

```r
query_openrouter("What are the main use cases of retrieval-augmented generation?")
```

Use a free model:

```r
query_openrouter(
  prompt = "Rewrite this in a more professional tone: our app is pretty good at searching files",
  model = "stepfun/step-3.5-flash:free",
  temperature = 0
)
```

OpenRouter embeddings:

```r
embed_openrouter(c("alpha", "beta"))
```

OpenRouter text-to-image:

```r
generate_image_openrouter(
  "A minimalist product photo of a mechanical keyboard on oak"
)
```

OpenRouter multimodal input:

```r
query_openrouter_content(
  content = list(
    list(type = "text", text = "What is in this image?"),
    list(type = "image_url", image_url = list(url = "https://example.com/cat.png"))
  ),
  model = "meta-llama/llama-3.3-70b-instruct:free"
)
```

### Cerebras

```r
query_cerebras("Explain inflation targeting in one paragraph.")
```

Specify model:

```r
query_cerebras(
  prompt = "Write a short introduction to algorithmic trading.",
  model = "llama3.1-8b"
)
```

### Ollama Cloud

```r
query_ollama("Explain why the sky is blue.")
```

Specify model:

```r
query_ollama(
  prompt = "Give me a concise explanation of principal component analysis.",
  model = "gpt-oss:120b"
)
```

## Example workflow: compare outputs across providers

```r
prompt <- "Explain retrieval-augmented generation in plain English."

list(
  gemini = query_gemini(prompt),
  groq = query_groq(prompt),
  openrouter = query_openrouter(prompt),
  cerebras = query_cerebras(prompt),
  ollama = query_ollama(prompt)
)
```

## Example workflow: inspect free or low-cost model candidates

### Gemini models as parsed JSON

```r
gm_json <- list_gemini_models(json_list = TRUE)
names(gm_json)
```

### Gemini model families currently visible in the API

- TTS:
  - `gemini-2.5-flash-preview-tts`
  - `gemini-2.5-pro-preview-tts`
- Embeddings:
  - `gemini-embedding-001`
  - `gemini-embedding-2-preview`
- Text-to-image:
  - `imagen-4.0-generate-001`
  - `imagen-4.0-ultra-generate-001`
  - `imagen-4.0-fast-generate-001`

Note: provider support differs by modality and model family. Model IDs and
capabilities should still be checked against the live provider model catalogs.

### OpenRouter free models

```r
or_models <- list_openrouter_models()
or_models[, pricing.prompt := sapply(pricing, `[[`, "prompt")]
or_models[pricing.prompt == 0]
```

### OpenRouter free model notes

- Verified current free embedding model:
  - `nvidia/llama-nemotron-embed-vl-1b-v2:free`
- OpenRouter free model availability changes frequently.
- Free TTS or free text-to-image model IDs should be checked from the current
  OpenRouter models catalog before use.
