#!/usr/bin/env bash
set -euo pipefail

runner_name="${1:?runner name is required}"
journalctl -u "agentic-runner@${runner_name}.service" -f
