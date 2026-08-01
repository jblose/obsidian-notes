#!/usr/bin/env bash
set -euo pipefail

# Install the community plugins used by this vault by downloading release assets
# into .obsidian/plugins/. This is optional: users can also install these from
# Obsidian Settings -> Community plugins -> Browse.
#
# The versions below mirror the tested configuration committed in this repo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_DIR="${REPO_ROOT}/.obsidian/plugins"

mkdir -p "${PLUGIN_DIR}"

usage() {
  cat <<'USAGE'
Usage: scripts/install-obsidian-plugins.sh [--force]

Downloads tested Obsidian community plugin release assets into this vault:
  - Calendar
  - Dataview
  - Tasks
  - Templater

Options:
  --force   Overwrite existing plugin main.js/styles.css/manifest.json files.
USAGE
}

FORCE=0
case "${1:-}" in
  "") ;;
  --force) FORCE=1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
esac

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd curl

install_plugin() {
  local id="$1"
  local repo="$2"
  local tag="$3"
  shift 3

  local dest="${PLUGIN_DIR}/${id}"
  mkdir -p "${dest}"

  echo "Installing ${id} ${tag} from ${repo}"
  for asset in "$@"; do
    local url="https://github.com/${repo}/releases/download/${tag}/${asset}"
    local out="${dest}/${asset}"

    if [[ -f "${out}" && "${FORCE}" -ne 1 ]]; then
      echo "  exists: ${asset} (use --force to overwrite)"
      continue
    fi

    echo "  downloading: ${asset}"
    if ! curl -fsSL "${url}" -o "${out}"; then
      if [[ "${asset}" == "styles.css" ]]; then
        echo "  optional asset not available for ${id}: ${asset}"
        rm -f "${out}"
      else
        echo "Failed to download ${url}" >&2
        exit 1
      fi
    fi
  done
}

install_plugin "calendar" "liamcain/obsidian-calendar-plugin" "1.5.10" \
  "main.js" "manifest.json" "styles.css"
install_plugin "dataview" "blacksmithgu/obsidian-dataview" "0.5.68" \
  "main.js" "manifest.json" "styles.css"
install_plugin "obsidian-tasks-plugin" "obsidian-tasks-group/obsidian-tasks" "7.22.0" \
  "main.js" "manifest.json" "styles.css"
install_plugin "templater-obsidian" "SilentVoid13/Templater" "2.16.2" \
  "main.js" "manifest.json" "styles.css"

echo "Done. Restart Obsidian, then enable community plugins if prompted."
