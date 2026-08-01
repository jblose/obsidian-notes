#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: ${REPO_ROOT}" >&2
  exit 1
fi

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

COMMIT_MSG="${1:-$(date "+%F-%H-%M-%S")}"

git commit -m "${COMMIT_MSG}"
git push

echo "Committed and pushed: ${COMMIT_MSG}"
