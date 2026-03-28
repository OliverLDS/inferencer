# inferencer

`inferencer` is a lightweight R package for calling hosted foundation model
inference APIs through a simple and mostly consistent interface.

It currently supports:

- Google Gemini
- Groq
- OpenRouter
- Cerebras

The package is intentionally minimal. It focuses on two common tasks:

1. listing available models from each provider
2. sending simple prompt-based inference requests

It also includes Gemini TTS support through `query_gemini()` plus
`write_gemini_audio()`.

More advanced provider-specific parameters may be added gradually in future versions.

## Basic setup

Set your API keys first:

```r
Sys.setenv(GEMINI_API_KEY = "your_key_here")
Sys.setenv(GROQ_API_KEY = "your_key_here")
Sys.setenv(OPENROUTER_API_KEY = "your_key_here")
Sys.setenv(CEREBRAS_API_KEY = "your_key_here")
```

Load the package:

```r
library(inferencer)
```

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

## Example workflow: compare outputs across providers

```r
prompt <- "Explain retrieval-augmented generation in plain English."

list(
  gemini = query_gemini(prompt),
  groq = query_groq(prompt),
  openrouter = query_openrouter(prompt),
  cerebras = query_cerebras(prompt)
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

Note: this package currently wraps Gemini text generation and Gemini TTS.
Gemini embeddings and Imagen text-to-image use different API patterns and are
not yet wrapped here.

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
