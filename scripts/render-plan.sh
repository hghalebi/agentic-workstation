#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_cli="${SCRIPT_DIR}/../target/debug/agentic-workstation"

if [[ -x "$repo_cli" ]]; then
  exec "$repo_cli" plan --json "$@"
fi

if command -v agentic-workstation >/dev/null 2>&1; then
  exec agentic-workstation plan --json "$@"
fi

exec "${SCRIPT_DIR}/../install-agentic-tools.sh" --json-plan "$@"
