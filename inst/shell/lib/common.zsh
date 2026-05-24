#!/usr/bin/env zsh

inferencer_script_dir() {
  local source_path="${(%):-%x}"
  print -r -- "${source_path:A:h}"
}

inferencer_require_command() {
  local cmd="$1"

  command -v "$cmd" >/dev/null 2>&1 || {
    print -r -- "Error: required command '$cmd' is not available." >&2
    return 1
  }
}

inferencer_require_api_key() {
  local value="$1"
  local name="$2"

  [[ -n "$value" ]] || {
    print -r -- "Error: ${name} is not set." >&2
    return 1
  }
}

inferencer_require_prompt() {
  local prompt="$1"
  local usage="$2"

  [[ -n "$prompt" ]] || {
    print -r -- "$usage" >&2
    return 1
  }
}

inferencer_require_bool() {
  local value="$1"
  local name="$2"

  case "$value" in
    true|false) ;;
    *)
      print -r -- "Error: ${name} must be true or false." >&2
      return 1
      ;;
  esac
}

inferencer_parse_query_args() {
  local usage="$1"
  shift

  INFERENCER_JSON=false
  INFERENCER_PROMPT=""
  INFERENCER_MODEL=""

  while (( $# > 0 )); do
    case "$1" in
      --json)
        INFERENCER_JSON=true
        shift
        ;;
      --help|-h)
        print -r -- "$usage"
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        print -r -- "Error: unknown option '$1'." >&2
        print -r -- "$usage" >&2
        return 1
        ;;
      *)
        if [[ -z "$INFERENCER_PROMPT" ]]; then
          INFERENCER_PROMPT="$1"
        elif [[ -z "$INFERENCER_MODEL" ]]; then
          INFERENCER_MODEL="$1"
        else
          print -r -- "Error: too many positional arguments." >&2
          print -r -- "$usage" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  if (( $# > 0 )); then
    if [[ -z "$INFERENCER_PROMPT" ]]; then
      INFERENCER_PROMPT="$1"
      shift
    fi
    if (( $# > 0 )) && [[ -z "$INFERENCER_MODEL" ]]; then
      INFERENCER_MODEL="$1"
      shift
    fi
  fi

  inferencer_require_prompt "$INFERENCER_PROMPT" "$usage"
}

inferencer_parse_list_args() {
  local usage="$1"
  shift

  INFERENCER_JSON=false

  while (( $# > 0 )); do
    case "$1" in
      --json)
        INFERENCER_JSON=true
        shift
        ;;
      --help|-h)
        print -r -- "$usage"
        exit 0
        ;;
      *)
        print -r -- "Error: unknown argument '$1'." >&2
        print -r -- "$usage" >&2
        return 1
        ;;
    esac
  done
}

inferencer_normalize_gemini_model() {
  local model="$1"
  model="${model#models/}"
  print -r -- "$model"
}

inferencer_format_table() {
  jq -r '
    def cell($x): if $x == null then "" else ($x | tostring) end;
    (.data // .models // []) as $rows
    | if ($rows | type) == "array" then
        ($rows[] | [cell(.id // .name), cell(.displayName // .name // .owned_by // "")] | @tsv)
      else
        empty
      end
  ' | awk -F '\t' 'BEGIN { printf "%-45s %s\n", "id", "name"; printf "%-45s %s\n", "--", "----" } { printf "%-45s %s\n", $1, $2 }'
}
