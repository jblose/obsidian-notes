#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
people_dir="${repo_root}/3_people"

find_top_meeting_date() {
  local file="$1"

  awk '
    /^## .*Meeting Log/ {
      in_meeting_log = 1
      next
    }

    in_meeting_log && /^### [[:space:]]*[0-9]{4}[.-][0-9]{2}[.-][0-9]{2}/ {
      date = $0
      sub(/^### [[:space:]]*/, "", date)
      match(date, /^[0-9]{4}[.-][0-9]{2}[.-][0-9]{2}/)
      date = substr(date, RSTART, RLENGTH)
      gsub(/\./, "-", date)
      print date
      exit
    }
  ' "$file"
}

update_last_met() {
  local file="$1"
  local last_met="$2"
  local tmp

  tmp="$(mktemp)"
  awk -v last_met="$last_met" '
    !updated && /^\*\*Last Met:\*\*/ {
      print "**Last Met:** " last_met "  "
      updated = 1
      next
    }

    { print }
  ' "$file" > "$tmp"

  if cmp -s "$file" "$tmp"; then
    rm "$tmp"
  else
    mv "$tmp" "$file"
    printf 'Updated %s -> %s\n' "${file#"$repo_root"/}" "$last_met"
  fi
}

while IFS= read -r -d '' file; do
  last_met="$(find_top_meeting_date "$file")"

  if [[ -z "$last_met" ]]; then
    printf 'Skipped %s: no Meeting Log date found\n' "${file#"$repo_root"/}"
    continue
  fi

  update_last_met "$file" "$last_met"
done < <(find "$people_dir" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)
