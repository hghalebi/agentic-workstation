#!/usr/bin/env bash
set -euo pipefail

runner_name="${1:?runner name is required}"
workspace="/workspace/${runner_name}"

if [[ ! -d "$workspace/.git" ]]; then
  echo "not a Git workspace: $workspace" >&2
  exit 1
fi

git -C "$workspace" clean -fdx
git -C "$workspace" reset --hard
