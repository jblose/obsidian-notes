#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/rollover-daily-todos.sh [TODAY] [YESTERDAY]

Move unfinished todo items from yesterday's daily note to today's note.
Dates must be in YYYY-MM-DD format.
Defaults:
  TODAY     = current date
  YESTERDAY = TODAY - 1 day
USAGE
}

is_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

create_daily_note_if_missing() {
  local target_date="$1"
  local target_file="$2"
  local template_file="$3"

  [[ -f "${target_file}" ]] && return 0

  if [[ ! -f "${template_file}" ]]; then
    echo "Error: daily template not found: ${template_file}" >&2
    exit 1
  fi

  sed "s|<% tp.date.now(\"YYYY-MM-DD\") %>|${target_date}|g" "${template_file}" > "${target_file}"
  echo "Created missing daily note: ${target_file}"
}

TODAY="${1:-$(date +%F)}"
YESTERDAY="${2:-$(date -d "${TODAY} -1 day" +%F)}"

if [[ "${TODAY}" == "-h" || "${TODAY}" == "--help" ]]; then
  usage
  exit 0
fi

if ! is_date "${TODAY}" || ! is_date "${YESTERDAY}"; then
  echo "Error: dates must use YYYY-MM-DD format." >&2
  usage >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAILY_DIR="${ROOT_DIR}/1_daily"
Y_FILE="${DAILY_DIR}/${YESTERDAY}.md"
T_FILE="${DAILY_DIR}/${TODAY}.md"
TEMPLATE_FILE="${ROOT_DIR}/0_templates/daily-note.md"

if [[ ! -f "${Y_FILE}" ]]; then
  echo "Error: yesterday file not found: ${Y_FILE}" >&2
  exit 1
fi

create_daily_note_if_missing "${TODAY}" "${T_FILE}" "${TEMPLATE_FILE}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

section_has_meaningful_content() {
  local file="$1"
  awk '
    {
      line = $0
      gsub(/[[:space:]]/, "", line)
      if (line != "" && line != "-") found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "${file}"
}

move_priority_section() {
  local source_file="$1"
  local source_out="$2"
  local moved_out="$3"

  : > "${moved_out}"

  awk -v src_out="${source_out}" -v moved_file="${moved_out}" '
{
  line = $0

  if (!in_section) {
    if (line ~ /^##[[:space:]].*Priorities/) {
      in_section = 1
      print line >> src_out
      next
    }
    print line >> src_out
    next
  }

  if (line ~ /^##[[:space:]]/) {
    in_section = 0
    print line >> src_out
    next
  }

  print line >> moved_file
}
' "${source_file}"
}

append_priority_section() {
  local target_file="$1"
  local moved_file="$2"
  local target_out="$3"

  awk -v moved_in="${moved_file}" -v t_out="${target_out}" '
function load_moved(   line) {
  if (moved_loaded) return
  moved_loaded = 1
  while ((getline line < moved_in) > 0) {
    moved[++moved_n] = line
  }
  close(moved_in)
  while (moved_n > 0 && moved[moved_n] == "") {
    delete moved[moved_n]
    moved_n--
  }
}
function body_has_meaningful_content(arr, count,   i, line) {
  for (i = 1; i <= count; i++) {
    line = arr[i]
    gsub(/[[:space:]]/, "", line)
    if (line != "" && line != "-") return 1
  }
  return 0
}
function body_contains_moved_block(   start, i, matched) {
  if (moved_n == 0 || body_n < moved_n) return 0
  for (start = 1; start <= body_n - moved_n + 1; start++) {
    matched = 1
    for (i = 1; i <= moved_n; i++) {
      if (body[start + i - 1] != moved[i]) {
        matched = 0
        break
      }
    }
    if (matched) return 1
  }
  return 0
}
function emit_priority_body(   i, existing_meaningful, already_present) {
  load_moved()
  existing_meaningful = body_has_meaningful_content(body, body_n)
  already_present = body_contains_moved_block()

  if (existing_meaningful) {
    for (i = 1; i <= body_n; i++) print body[i] >> t_out
    if (!already_present && body_n > 0 && body[body_n] != "") print "" >> t_out
  }

  if (!already_present) {
    for (i = 1; i <= moved_n; i++) print moved[i] >> t_out
  }

  delete body
  body_n = 0
}
{
  line = $0

  if (!in_section) {
    print line >> t_out
    if (line ~ /^##[[:space:]].*Priorities/) in_section = 1
    next
  }

  if (line ~ /^##[[:space:]]/) {
    emit_priority_body()
    in_section = 0
    print line >> t_out
    next
  }

  body[++body_n] = line
}
END {
  if (in_section) emit_priority_body()
}
' "${target_file}"
}

move_todo_items() {
  local source_file="$1"
  local source_out="$2"
  local moved_out="$3"

  : > "${moved_out}"

  awk -v src_out="${source_out}" -v moved_file="${moved_out}" '
function reset_item() {
  delete item
  item_n = 0
  item_first = ""
}
function is_blank_item(first, stripped) {
  stripped = first
  sub(/^- /, "", stripped)
  sub(/^\[[^]]*\][[:space:]]*/, "", stripped)
  gsub(/[[:space:]]/, "", stripped)
  return stripped == ""
}
function should_move_item() {
  if (item_n == 0) return 0
  if (is_blank_item(item_first)) return 0
  if (item_first ~ /^- \[[xX]\]/) return 0
  return 1
}
function flush_item(   i) {
  if (item_n == 0) return
  if (should_move_item()) {
    for (i = 1; i <= item_n; i++) print item[i] >> moved_file
  } else {
    for (i = 1; i <= item_n; i++) print item[i] >> src_out
  }
  reset_item()
}
{
  line = $0

  if (!in_section) {
    if (line ~ /^##[[:space:]].*Todos/) {
      in_section = 1
      print line >> src_out
      next
    }
    print line >> src_out
    next
  }

  if (line ~ /^##[[:space:]]/) {
    flush_item()
    in_section = 0
    print line >> src_out
    next
  }

  if (line ~ /^- /) {
    flush_item()
    item_n = 1
    item[1] = line
    item_first = line
    next
  }

  if (item_n > 0 && line ~ /^[ \t]+/) {
    item[++item_n] = line
    next
  }

  if (item_n > 0) flush_item()
  print line >> src_out
}
END {
  if (in_section) flush_item()
}
' "${source_file}"
}

append_todo_items() {
  local target_file="$1"
  local moved_file="$2"
  local target_out="$3"

  awk -v moved_in="${moved_file}" -v t_out="${target_out}" '
function reset_item() {
  delete item
  item_n = 0
  item_first = ""
}
function is_blank_item(first, stripped) {
  stripped = first
  sub(/^- /, "", stripped)
  sub(/^\[[^]]*\][[:space:]]*/, "", stripped)
  gsub(/[[:space:]]/, "", stripped)
  return stripped == ""
}
function item_key_from_array(arr, count,   i, key) {
  key = ""
  for (i = 1; i <= count; i++) key = key arr[i] "\n"
  return key
}
function load_moved_items(   line, key) {
  if (moved_loaded) return
  moved_loaded = 1
  while ((getline line < moved_in) > 0) {
    if (line ~ /^- / && moved_item_n > 0) {
      key = item_key_from_array(moved_item, moved_item_n)
      moved_keys[++moved_count] = key
      moved_seen[key] = moved_count
      delete moved_item
      moved_item_n = 0
    }
    moved_item[++moved_item_n] = line
  }
  close(moved_in)
  if (moved_item_n > 0) {
    key = item_key_from_array(moved_item, moved_item_n)
    moved_keys[++moved_count] = key
    moved_seen[key] = moved_count
  }
}
function print_item(   i, key, idx) {
  load_moved_items()
  key = item_key_from_array(item, item_n)
  idx = moved_seen[key]
  if (idx) moved_skip[idx] = 1
  for (i = 1; i <= item_n; i++) print item[i] >> t_out
}
function flush_item() {
  if (item_n == 0) return
  if (!is_blank_item(item_first)) print_item()
  reset_item()
}
function append_moved(   i, line, key) {
  if (did_append) return
  load_moved_items()
  for (i = 1; i <= moved_count; i++) {
    if (moved_skip[i]) continue
    key = moved_keys[i]
    n = split(key, moved_lines, "\n")
    for (line = 1; line < n; line++) print moved_lines[line] >> t_out
  }
  did_append = 1
}
{
  line = $0

  if (!in_section) {
    print line >> t_out
    if (line ~ /^##[[:space:]].*Todos/) in_section = 1
    next
  }

  if (line ~ /^##[[:space:]]/) {
    flush_item()
    append_moved()
    in_section = 0
    print line >> t_out
    next
  }

  if (line ~ /^- /) {
    flush_item()
    item_n = 1
    item[1] = line
    item_first = line
    next
  }

  if (item_n > 0 && line ~ /^[ \t]+/) {
    item[++item_n] = line
    next
  }

  if (item_n > 0) flush_item()
  print line >> t_out
}
END {
  if (in_section) {
    flush_item()
    append_moved()
  }
}
' "${target_file}"
}

Y_PRIORITIES_NEW="${TMP_DIR}/yesterday.priorities.new"
MOVED_PRIORITIES="${TMP_DIR}/moved.priorities"
T_PRIORITIES_NEW="${TMP_DIR}/today.priorities.new"

move_priority_section "${Y_FILE}" "${Y_PRIORITIES_NEW}" "${MOVED_PRIORITIES}"
if section_has_meaningful_content "${MOVED_PRIORITIES}"; then
  mv "${Y_PRIORITIES_NEW}" "${Y_FILE}"
  append_priority_section "${T_FILE}" "${MOVED_PRIORITIES}" "${T_PRIORITIES_NEW}"
  mv "${T_PRIORITIES_NEW}" "${T_FILE}"
else
  rm -f "${Y_PRIORITIES_NEW}" "${T_PRIORITIES_NEW}"
fi

Y_TODOS_NEW="${TMP_DIR}/yesterday.todos.new"
MOVED_TODOS="${TMP_DIR}/moved.todos"
T_TODOS_NEW="${TMP_DIR}/today.todos.new"

move_todo_items "${Y_FILE}" "${Y_TODOS_NEW}" "${MOVED_TODOS}"

if [[ ! -s "${MOVED_TODOS}" && ! -s "${MOVED_PRIORITIES}" ]]; then
  echo "No unfinished todos or priorities found in ${YESTERDAY}."
  exit 0
fi

if [[ -s "${MOVED_TODOS}" ]]; then
  mv "${Y_TODOS_NEW}" "${Y_FILE}"
  append_todo_items "${T_FILE}" "${MOVED_TODOS}" "${T_TODOS_NEW}"
  mv "${T_TODOS_NEW}" "${T_FILE}"
else
  rm -f "${Y_TODOS_NEW}" "${T_TODOS_NEW}"
fi

echo "Moved daily rollover items: ${YESTERDAY} -> ${TODAY}"
