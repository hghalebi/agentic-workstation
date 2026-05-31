#!/usr/bin/env bash
set -euo pipefail

runner_name="${1:?runner name is required}"
systemctl status "agentic-runner@${runner_name}.service"
