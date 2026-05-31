#!/usr/bin/env bash
set -euo pipefail

lockfile="${1:-agentic-tools.lock.yaml}"

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
