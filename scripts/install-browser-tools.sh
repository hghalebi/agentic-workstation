#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BROWSER_TOOLS=1 exec "${SCRIPT_DIR}/../install-agentic-tools.sh" --only browser "$@"
