#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lockfile="${1:-agentic-tools.lock.yaml}"
repo_cli="${SCRIPT_DIR}/../target/debug/agentic-workstation"

if [[ -x "$repo_cli" ]]; then
  exec "$repo_cli" verify-lockfile "$lockfile"
fi

if command -v agentic-workstation >/dev/null 2>&1; then
  exec agentic-workstation verify-lockfile "$lockfile"
fi

if [[ ! -f "$lockfile" ]]; then
  echo "missing lockfile: $lockfile" >&2
  exit 1
fi

if grep -En '(<pinned-version>|TODO|FIXME)' "$lockfile"; then
  echo "lockfile contains placeholders" >&2
  exit 1
fi

if grep -En '@latest|: latest|latest$' "$lockfile"; then
  echo "lockfile contains moving latest targets" >&2
  exit 1
fi

echo "lockfile verified: $lockfile"
