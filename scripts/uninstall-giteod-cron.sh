#!/usr/bin/env bash
set -euo pipefail

TMP_CRON="$(mktemp)"

if crontab -l >/dev/null 2>&1; then
  crontab -l | sed '/obsidian-notes-eod-auto/d' | sed '/obsidian-notes-giteod-auto/d' > "${TMP_CRON}"
  crontab "${TMP_CRON}"
  echo "Removed obsidian-notes EOD automation cron entries."
else
  echo "No user crontab found."
fi

rm -f "${TMP_CRON}"
