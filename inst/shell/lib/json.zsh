#!/usr/bin/env zsh

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
              (.text // .content // .output_text // "")
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
      print -r -- "Error: OpenRouter response was truncated (${finish_reason}). Increase OPENROUTER_MAX_TOKENS and retry." >&2
      return 1
      ;;
  esac
}
