#!/usr/bin/env bash
set -euo pipefail

runner_name="${1:?runner name is required}"
workspace="/workspace/${runner_name}"
agent_command="${AGENT_COMMAND:-codex}"
agent_args="${AGENT_ARGS:-}"
log_dir="${AGENT_LOG_DIR:-/var/log/agentic-workstation}"
args=()

mkdir -p "$log_dir"

if [[ ! -d "$workspace" ]]; then
  echo "workspace does not exist: $workspace" >&2
  exit 1
fi

cd "$workspace"
if [[ -n "$agent_args" ]]; then
  read -r -a args <<<"$agent_args"
fi
exec "$agent_command" "${args[@]}"
