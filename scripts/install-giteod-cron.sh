#!/usr/bin/env bash
set -euo pipefail

TIME_SPEC="${1:-18:30}"
if [[ ! "${TIME_SPEC}" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  echo "Invalid time '${TIME_SPEC}'. Expected HH:MM (24-hour)." >&2
  exit 1
fi

HOUR="${TIME_SPEC%:*}"
MINUTE="${TIME_SPEC#*:}"

if [[ "${HOUR}" =~ ^[0-9]$ ]]; then
  HOUR="0${HOUR}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROLL_SCRIPT="${REPO_ROOT}/scripts/rollover-daily-todos.sh"
LAST_MET_SCRIPT="${REPO_ROOT}/scripts/update-person-last-met.sh"
EOD_SCRIPT="${REPO_ROOT}/scripts/eod-rollover-and-giteod.sh"
LOG_FILE="${REPO_ROOT}/.git/giteod-auto.log"
MARKER="# obsidian-notes-eod-auto"

if [[ ! -x "${ROLL_SCRIPT}" ]]; then
  echo "Missing executable script: ${ROLL_SCRIPT}" >&2
  exit 1
fi

if [[ ! -x "${LAST_MET_SCRIPT}" ]]; then
  echo "Missing executable script: ${LAST_MET_SCRIPT}" >&2
  exit 1
fi

if [[ ! -x "${EOD_SCRIPT}" ]]; then
  echo "Missing executable script: ${EOD_SCRIPT}" >&2
  exit 1
fi

CRON_CMD="${MINUTE} ${HOUR#0} * * * cd ${REPO_ROOT} && ${EOD_SCRIPT} >> ${LOG_FILE} 2>&1 ${MARKER}"
TMP_CRON="$(mktemp)"

if crontab -l >/dev/null 2>&1; then
  crontab -l | sed '/obsidian-notes-eod-auto/d' | sed '/obsidian-notes-giteod-auto/d' > "${TMP_CRON}"
else
  : > "${TMP_CRON}"
fi

echo "${CRON_CMD}" >> "${TMP_CRON}"
crontab "${TMP_CRON}"
rm -f "${TMP_CRON}"

echo "Installed obsidian-notes EOD rollover + giteod cron at ${HOUR}:${MINUTE}."
