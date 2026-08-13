#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/cleanup-unused-dailies.sh [--dry-run]

Delete daily notes in 1_daily/ that still only contain the daily-note template
scaffold. This is intended to run after daily rollover and before giteod so
unused auto-created daily notes do not get committed.

Options:
  --dry-run  Print files that would be deleted without removing them.
USAGE
}

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAILY_DIR="${ROOT_DIR}/1_daily"

if [[ ! -d "${DAILY_DIR}" ]]; then
  echo "Error: daily directory not found: ${DAILY_DIR}" >&2
  exit 1
fi

is_unused_daily() {
  local file="$1"
  local filename daily_date

  filename="$(basename "${file}")"
  daily_date="${filename%.md}"

  [[ "${filename}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]] || return 1

  awk -v daily_date="${daily_date}" '
function trim(value) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
  return value
}
function is_allowed_tags_line(line,   tags, count, i, tag) {
  sub(/^[[:space:]]*tags:[[:space:]]*/, "", line)
  count = split(line, tags, ",")

  for (i = 1; i <= count; i++) {
    tag = trim(tags[i])
    if (tag == "") continue
    if (tag == "#daily-note") continue
    if (tag == "#" daily_date) continue
    return 0
  }

  return 1
}
function is_scaffold_line(line) {
  line = trim(line)

  if (line == "") return 1
  if (line == "---") return 1
  if (line ~ /^tags:[[:space:]]*/) return is_allowed_tags_line(line)

  if (line == "## ☀️ Priorities") return 1
  if (line == "## 💬 Meetings") return 1
  if (line == "### {{meeting_title}}") return 1
  if (line == "- Notes:") return 1
  if (line == "- Actions:") return 1
  if (line == "- Decisions:") return 1
  if (line == "## ✍️ Notes / Ideas") return 1
  if (line == "## ✅ Todos") return 1

  if (line == "-") return 1

  return 0
}
{
  if (!is_scaffold_line($0)) meaningful = 1
}
END {
  exit meaningful ? 1 : 0
}
' "${file}"
}

shopt -s nullglob

removed_count=0
for file in "${DAILY_DIR}"/*.md; do
  if is_unused_daily "${file}"; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "Would delete unused daily: ${file}"
    else
      rm -f "${file}"
      echo "Deleted unused daily: ${file}"
    fi
    removed_count=$((removed_count + 1))
  fi
done

if [[ "${removed_count}" -eq 0 ]]; then
  echo "No unused daily notes found."
elif [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Unused daily notes found: ${removed_count}"
else
  echo "Deleted unused daily notes: ${removed_count}"
fi
