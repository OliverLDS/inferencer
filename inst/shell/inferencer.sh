# Source this file from zsh. The markdown renderer uses zsh pattern features.

inferencer_require_command() {
  local cmd="$1"

  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: required command '$cmd' is not available." >&2
    return 1
  }
}

inferencer_require_api_key() {
  local value="$1"
  local name="$2"

  [[ -n "$value" ]] || {
    echo "Error: ${name} is not set." >&2
    return 1
  }
}

inferencer_require_prompt() {
  local prompt="$1"
  local usage="$2"

  [[ -n "$prompt" ]] || {
    echo "$usage" >&2
    return 1
  }
}

inferencer_require_bool() {
  local value="$1"
  local name="$2"

  case "$value" in
    true|false) ;;
    *)
      echo "Error: ${name} must be true or false." >&2
      return 1
      ;;
  esac
}

inferencer_normalize_gemini_model() {
  local model="$1"
  model="${model#models/}"
  printf '%s\n' "$model"
}

inferencer_response_has_error() {
  local response="$1"
  printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1
}

inferencer_print_error_response() {
  local response="$1"

  if printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$response" | jq . >&2
  else
    printf '%s\n' "$response" >&2
  fi
}

inferencer_extract_openai_text() {
  local response="$1"

  printf '%s' "$response" | jq -r '
    .choices[0].message.content as $content
    | if ($content | type) == "string" then
        $content
      elif ($content | type) == "array" then
        $content
        | map(
            if .type == "text" then
              (.text // .content // "")
            else
              ""
            end
          )
        | join("")
      else
        ""
      end
  '
}

inferencer_extract_gemini_text() {
  local response="$1"

  printf '%s' "$response" | jq -r '
    .candidates[0].content.parts
    | map(.text // "")
    | join("")
  '
}

inferencer_check_openrouter_truncation() {
  local response="$1"
  local finish_reason

  finish_reason="$(
    printf '%s' "$response" | jq -r '
      .choices[0].finish_reason
      // .choices[0].native_finish_reason
      // empty
    '
  )"

  case "$finish_reason" in
    length|max_tokens)
      echo "Error: OpenRouter response was truncated (${finish_reason}). Increase OPENROUTER_MAX_TOKENS and retry." >&2
      return 1
      ;;
  esac
}

query_gemini() {
  local prompt="$*"
  inferencer_require_prompt "$prompt" 'Usage: query_gemini "your prompt"' || return 1
  inferencer_require_command jq || return 1
  inferencer_require_command curl || return 1

  local api_key="${GEMINI_API_KEY:-}"
  local model="${GEMINI_MODEL:-gemini-2.5-flash}"
  local temperature="${GEMINI_TEMPERATURE:-0.7}"
  local top_p="${GEMINI_TOP_P:-1}"
  local top_k="${GEMINI_TOP_K:-40}"
  local max_tokens="${GEMINI_MAX_TOKENS:-}"
  local url0="${GEMINI_API_URL:-https://generativelanguage.googleapis.com/v1beta/models}"
  local model_path
  local url
  local body response text

  inferencer_require_api_key "$api_key" "GEMINI_API_KEY" || return 1
  model_path="$(inferencer_normalize_gemini_model "$model")"
  url="${url0}/${model_path}:generateContent?key=${api_key}"

  if [[ -n "$max_tokens" ]]; then
    body="$(
      jq -n \
        --arg prompt "$prompt" \
        --argjson temperature "$temperature" \
        --argjson top_p "$top_p" \
        --argjson top_k "$top_k" \
        --argjson max_tokens "$max_tokens" \
        '{
          contents: [
            {
              role: "user",
              parts: [{ text: $prompt }]
            }
          ],
          generationConfig: {
            temperature: $temperature,
            topP: $top_p,
            topK: $top_k,
            maxOutputTokens: $max_tokens
          }
        }'
    )" || return 1
  else
    body="$(
      jq -n \
        --arg prompt "$prompt" \
        --argjson temperature "$temperature" \
        --argjson top_p "$top_p" \
        --argjson top_k "$top_k" \
        '{
          contents: [
            {
              role: "user",
              parts: [{ text: $prompt }]
            }
          ],
          generationConfig: {
            temperature: $temperature,
            topP: $top_p,
            topK: $top_k
          }
        }'
    )" || return 1
  fi

  response="$(
    curl --silent --show-error --fail \
      -H "Content-Type: application/json" \
      --data "$body" \
      "$url"
  )" || return 1

  if inferencer_response_has_error "$response"; then
    inferencer_print_error_response "$response"
    return 1
  fi

  text="$(inferencer_extract_gemini_text "$response")"

  [[ -n "$text" ]] || {
    echo "Error: Gemini API returned no text content." >&2
    inferencer_print_error_response "$response"
    return 1
  }

  printf '%s\n' "$text"
}

query_groq() {
  local prompt="$*"
  inferencer_require_prompt "$prompt" 'Usage: query_groq "your prompt"' || return 1
  inferencer_require_command jq || return 1
  inferencer_require_command curl || return 1

  local api_key="${GROQ_API_KEY:-}"
  local url="${GROQ_API_URL:-https://api.groq.com/openai/v1/chat/completions}"
  local model="${GROQ_MODEL:-groq/compound}"
  local temperature="${GROQ_TEMPERATURE:-1.0}"
  local top_p="${GROQ_TOP_P:-1.0}"
  local max_tokens="${GROQ_MAX_TOKENS:-1024}"
  local stream="${GROQ_STREAM:-false}"
  local body response text

  inferencer_require_api_key "$api_key" "GROQ_API_KEY" || return 1
  inferencer_require_bool "$stream" "GROQ_STREAM" || return 1

  body="$(
    jq -n \
      --arg prompt "$prompt" \
      --arg model "$model" \
      --argjson temperature "$temperature" \
      --argjson top_p "$top_p" \
      --argjson max_tokens "$max_tokens" \
      --argjson stream "$stream" \
      '{
        messages: [{ role: "user", content: $prompt }],
        model: $model,
        temperature: $temperature,
        top_p: $top_p,
        stream: $stream,
        max_tokens: $max_tokens
      }'
  )" || return 1

  response="$(
    curl --silent --show-error --fail \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $api_key" \
      --data "$body" \
      "$url"
  )" || return 1

  if inferencer_response_has_error "$response"; then
    inferencer_print_error_response "$response"
    return 1
  fi

  text="$(inferencer_extract_openai_text "$response")"

  [[ -n "$text" ]] || {
    echo "Error: Groq API returned no message content." >&2
    inferencer_print_error_response "$response"
    return 1
  }

  printf '%s\n' "$text"
}

query_openrouter() {
  local prompt="$*"
  inferencer_require_prompt "$prompt" 'Usage: query_openrouter "your prompt"' || return 1
  inferencer_require_command jq || return 1
  inferencer_require_command curl || return 1

  local api_key="${OPENROUTER_API_KEY:-}"
  local url="${OPENROUTER_API_URL:-https://openrouter.ai/api/v1/chat/completions}"
  local model="${OPENROUTER_MODEL:-openrouter/free}"
  local temperature="${OPENROUTER_TEMPERATURE:-0}"
  local top_p="${OPENROUTER_TOP_P:-1}"
  local max_tokens="${OPENROUTER_MAX_TOKENS:-2048}"
  local reasoning="${OPENROUTER_REASONING:-true}"
  local body response text

  inferencer_require_api_key "$api_key" "OPENROUTER_API_KEY" || return 1
  inferencer_require_bool "$reasoning" "OPENROUTER_REASONING" || return 1

  body="$(
    jq -n \
      --arg prompt "$prompt" \
      --arg model "$model" \
      --argjson temperature "$temperature" \
      --argjson top_p "$top_p" \
      --argjson max_tokens "$max_tokens" \
      --argjson reasoning "$reasoning" \
      '{
        model: $model,
        messages: [
          { role: "user", content: $prompt }
        ],
        temperature: $temperature,
        top_p: $top_p,
        max_tokens: $max_tokens,
        reasoning: {
          enabled: $reasoning
        }
      }'
  )" || return 1

  response="$(
    curl --silent --show-error --fail \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $api_key" \
      --data "$body" \
      "$url"
  )" || return 1

  if inferencer_response_has_error "$response"; then
    inferencer_print_error_response "$response"
    return 1
  fi

  inferencer_check_openrouter_truncation "$response" || {
    inferencer_print_error_response "$response"
    return 1
  }

  text="$(inferencer_extract_openai_text "$response")"

  [[ -n "$text" ]] || {
    echo "Error: OpenRouter API returned no message content." >&2
    inferencer_print_error_response "$response"
    return 1
  }

  printf '%s\n' "$text"
}

query_cerebras() {
  local prompt="$*"
  inferencer_require_prompt "$prompt" 'Usage: query_cerebras "your prompt"' || return 1
  inferencer_require_command jq || return 1
  inferencer_require_command curl || return 1

  local api_key="${CEREBRAS_API_KEY:-}"
  local url="${CEREBRAS_API_URL:-https://api.cerebras.ai/v1/chat/completions}"
  local model="${CEREBRAS_MODEL:-llama3.1-8b}"
  local temperature="${CEREBRAS_TEMPERATURE:-0}"
  local top_p="${CEREBRAS_TOP_P:-1}"
  local max_tokens="${CEREBRAS_MAX_TOKENS:--1}"
  local stream="${CEREBRAS_STREAM:-false}"
  local seed="${CEREBRAS_SEED:-0}"
  local body response text

  inferencer_require_api_key "$api_key" "CEREBRAS_API_KEY" || return 1
  inferencer_require_bool "$stream" "CEREBRAS_STREAM" || return 1

  body="$(
    jq -n \
      --arg prompt "$prompt" \
      --arg model "$model" \
      --argjson temperature "$temperature" \
      --argjson top_p "$top_p" \
      --argjson max_tokens "$max_tokens" \
      --argjson stream "$stream" \
      --argjson seed "$seed" \
      '{
        model: $model,
        stream: $stream,
        messages: [
          { role: "user", content: $prompt }
        ],
        temperature: $temperature,
        max_tokens: $max_tokens,
        seed: $seed,
        top_p: $top_p
      }'
  )" || return 1

  response="$(
    curl --silent --show-error --fail \
      --location \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $api_key" \
      --data "$body" \
      "$url"
  )" || return 1

  if inferencer_response_has_error "$response"; then
    inferencer_print_error_response "$response"
    return 1
  fi

  text="$(inferencer_extract_openai_text "$response")"

  [[ -n "$text" ]] || {
    echo "Error: Cerebras API returned no message content." >&2
    inferencer_print_error_response "$response"
    return 1
  }

  printf '%s\n' "$text"
}

query_ollama() {
  local prompt="$*"
  inferencer_require_prompt "$prompt" 'Usage: query_ollama "your prompt"' || return 1
  inferencer_require_command jq || return 1
  inferencer_require_command curl || return 1

  local api_key="${OLLAMA_API_KEY:-}"
  local url="${OLLAMA_API_URL:-https://ollama.com/api/chat}"
  local model="${OLLAMA_MODEL:-gpt-oss:120b}"
  local body response text

  inferencer_require_api_key "$api_key" "OLLAMA_API_KEY" || return 1

  body="$(
    jq -n \
      --arg prompt "$prompt" \
      --arg model "$model" \
      '{
        model: $model,
        messages: [
          { role: "user", content: $prompt }
        ],
        stream: false
      }'
  )" || return 1

  response="$(
    curl --silent --show-error --fail \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $api_key" \
      --data "$body" \
      "$url"
  )" || return 1

  if inferencer_response_has_error "$response"; then
    inferencer_print_error_response "$response"
    return 1
  fi

  text="$(printf '%s' "$response" | jq -r '.message.content // empty')"

  [[ -n "$text" ]] || {
    echo "Error: Ollama API returned no message content." >&2
    inferencer_print_error_response "$response"
    return 1
  }

  printf '%s\n' "$text"
}

query_fallback() {
  local prompt="$*"
  local output
  local err_file

  inferencer_require_prompt "$prompt" 'Usage: query_fallback "your prompt"' || return 1

  err_file="$(mktemp "${TMPDIR:-/tmp}/inferencer-fallback.XXXXXX")" || return 1

  output="$(
    GEMINI_MODEL="models/gemini-flash-latest" query_gemini "$prompt" 2>"$err_file"
  )"
  if [[ $? -eq 0 ]]; then
    rm -f "$err_file"
    printf '%s\n' "$output"
    return 0
  fi
  echo "Gemini fallback failed:" >&2
  cat "$err_file" >&2

  output="$(
    OPENROUTER_MODEL="openrouter/free" OPENROUTER_REASONING="false" query_openrouter "$prompt" 2>"$err_file"
  )"
  if [[ $? -eq 0 ]]; then
    rm -f "$err_file"
    printf '%s\n' "$output"
    return 0
  fi
  echo "OpenRouter fallback failed:" >&2
  cat "$err_file" >&2

  output="$(
    GROQ_MODEL="groq/compound" query_groq "$prompt" 2>"$err_file"
  )"
  if [[ $? -eq 0 ]]; then
    rm -f "$err_file"
    printf '%s\n' "$output"
    return 0
  fi
  echo "Groq fallback failed:" >&2
  cat "$err_file" >&2

  echo "Error: all fallback providers failed in order: Gemini, OpenRouter, Groq." >&2
  rm -f "$err_file"
  return 1
}

render_markdown_terminal() {
  emulate -L zsh
  setopt extendedglob

  local line text hashes level
  local hr
  hr=$(printf '%*s' 50 '')
  hr=${hr// /─}

  local RESET=$'\033[0m'
  local BOLD=$'\033[1m'
  local ITALIC=$'\033[3m'
  local UNDERLINE=$'\033[4m'
  local CYAN=$'\033[36m'
  local REVERSE=$'\033[7m'

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ([[:space:]]#'---'[[:space:]]#|[[:space:]]#'***'[[:space:]]#|[[:space:]]#'___'[[:space:]]#)
        print -r -- "$hr"
        continue
        ;;
    esac

    if [[ "$line" =~ '^#{1,}[[:space:]]' ]]; then
      hashes="${line%% *}"
      level=${#hashes}
      text="${line#"$hashes "}"

      case $level in
        1) print -r -- "${BOLD}${(U)text}${RESET}" ;;
        2) print -r -- "${BOLD}${text}${RESET}" ;;
        3) print -r -- "${UNDERLINE}${text}${RESET}" ;;
        *) print -r -- "${CYAN}${text}${RESET}" ;;
      esac
      continue
    fi

    while [[ "$line" == *\`[^\`]##\`* ]]; do
      line="${line/\`(#b)([^\`]##)\`/${REVERSE}${match[1]}${RESET}}"
    done

    while [[ "$line" == *\*\*[^*]##\*\** ]]; do
      line="${line/\*\*(#b)([^*]##)\*\*/${BOLD}${match[1]}${RESET}}"
    done

    while [[ "$line" == *\*[^*]##\** ]]; do
      line="${line/\*(#b)([^*]##)\*/${ITALIC}${match[1]}${RESET}}"
    done

    while [[ "$line" == *_[^_]##_* ]]; do
      line="${line/_(#b)([^_]##)_/${ITALIC}${match[1]}${RESET}}"
    done

    print -r -- "$line"
  done
}
