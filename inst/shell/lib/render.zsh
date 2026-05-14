#!/usr/bin/env zsh

inferencer_trim() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  print -r -- "$text"
}

inferencer_strip_markdown_markers() {
  local text="$1"
  text="${text//\*\*/}"
  text="${text//\*/}"
  text="${text//_/}"
  text="${text//\`/}"
  print -r -- "$text"
}

inferencer_repeat_char() {
  local char="$1"
  local count="$2"
  local out=""

  while (( ${#out} < count )); do
    out+="$char"
  done

  printf '%s' "$out"
}

inferencer_render_inline_markdown() {
  emulate -L zsh
  setopt extendedglob

  local line="$1"
  local RESET=$'\033[0m'
  local BOLD=$'\033[1m'
  local ITALIC=$'\033[3m'
  local REVERSE=$'\033[7m'

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
}

inferencer_is_table_line() {
  [[ "$1" =~ '^[[:space:]]*\|.*\|[[:space:]]*$' ]]
}

inferencer_is_table_separator() {
  local line cell
  local -a cells

  line="$(inferencer_trim "$1")"
  [[ "$line" == \|*\| ]] || return 1

  line="${line#|}"
  line="${line%|}"
  local IFS='|'
  read -rA cells <<< "$line"

  for cell in "${cells[@]}"; do
    cell="$(inferencer_trim "$cell")"
    [[ "$cell" =~ '^:?-{3,}:?$' ]] || return 1
  done
}

inferencer_render_table() {
  emulate -L zsh
  setopt extendedglob

  local sep=$'\x1f'
  local line trimmed row_text plain padded
  local -a rows widths cells
  local i cell_count row_index

  cell_count=0

  for line in "$@"; do
    if inferencer_is_table_separator "$line"; then
      continue
    fi

    trimmed="$(inferencer_trim "$line")"
    trimmed="${trimmed#|}"
    trimmed="${trimmed%|}"
    local IFS='|'
    read -rA cells <<< "$trimmed"
    (( ${#cells} > cell_count )) && cell_count=${#cells}

    for (( i = 1; i <= ${#cells}; i++ )); do
      cells[$i]="$(inferencer_trim "${cells[$i]}")"
      plain="$(inferencer_strip_markdown_markers "${cells[$i]}")"
      if [[ -z "${widths[$i]:-}" ]] || (( ${#plain} > widths[$i] )); then
        widths[$i]=${#plain}
      fi
    done

    rows+=("${(j:$sep:)cells}")
  done

  (( ${#rows} > 0 )) || return 0

  row_index=1
  for line in "${rows[@]}"; do
    cells=("${(@s:$sep:)line}")
    row_text=""

    for (( i = 1; i <= cell_count; i++ )); do
      local cell="${cells[$i]:-}"
      plain="$(inferencer_strip_markdown_markers "$cell")"
      padded="$cell$(inferencer_repeat_char ' ' $(( widths[$i] - ${#plain} )))"
      row_text+="| $(inferencer_render_inline_markdown "$padded") "
    done
    row_text+="|"
    print -r -- "$row_text"

    if (( row_index == 1 && ${#rows} > 1 )); then
      row_text=""
      for (( i = 1; i <= cell_count; i++ )); do
        row_text+="| $(inferencer_repeat_char '-' "${widths[$i]}") "
      done
      row_text+="|"
      print -r -- "$row_text"
    fi

    (( row_index++ ))
  done
}

render_markdown_terminal_main() {
  emulate -L zsh
  setopt extendedglob

  local line text hashes level bullet_indent bullet_text
  local -a table_lines
  local hr
  hr=$(printf '%*s' 50 '')
  hr=${hr// /-}

  local RESET=$'\033[0m'
  local BOLD=$'\033[1m'
  local UNDERLINE=$'\033[4m'
  local CYAN=$'\033[36m'

  while IFS= read -r line || [[ -n "$line" ]]; do
    if inferencer_is_table_line "$line"; then
      table_lines+=("$line")
      continue
    fi

    if (( ${#table_lines} > 0 )); then
      inferencer_render_table "${table_lines[@]}"
      table_lines=()
    fi

    case "$line" in
      ([[:space:]]#'---'[[:space:]]#|[[:space:]]#'***'[[:space:]]#|[[:space:]]#'___'[[:space:]]#)
        print -r -- "$hr"
        continue
        ;;
    esac

    if [[ "$line" =~ '^#{1,}[[:space:]]' ]]; then
      hashes="${line%% *}"
      level=${#hashes}
      text="$(inferencer_render_inline_markdown "${line#"$hashes "}")"

      case $level in
        1) print -r -- "${BOLD}${(U)text}${RESET}" ;;
        2) print -r -- "${BOLD}${text}${RESET}" ;;
        3) print -r -- "${UNDERLINE}${text}${RESET}" ;;
        *) print -r -- "${CYAN}${text}${RESET}" ;;
      esac
      continue
    fi

    if [[ "$line" =~ '^([[:space:]]*)\*[[:space:]]+(.*)$' ]]; then
      bullet_indent="${match[1]}"
      bullet_text="$(inferencer_render_inline_markdown "${match[2]}")"
      print -r -- "${bullet_indent}* ${bullet_text}"
      continue
    fi

    print -r -- "$(inferencer_render_inline_markdown "$line")"
  done

  if (( ${#table_lines} > 0 )); then
    inferencer_render_table "${table_lines[@]}"
  fi
}
