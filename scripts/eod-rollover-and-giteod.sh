#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TODAY="$(date +%F)"
TOMORROW="$(date -d "${TODAY} +1 day" +%F)"

cd "${REPO_ROOT}"

"${REPO_ROOT}/scripts/rollover-daily-todos.sh" "${TOMORROW}" "${TODAY}"
"${REPO_ROOT}/scripts/update-person-last-met.sh"
"${REPO_ROOT}/scripts/cleanup-unused-dailies.sh"
"${REPO_ROOT}/scripts/giteod.sh" "${1:-$(date "+%F-%H-%M-%S")}"
