#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WORKSPACE_REPO:-}" ]]; then
  echo "WORKSPACE_REPO is required" >&2
  exit 1
fi

repo_name="$(basename "$WORKSPACE_REPO" .git)"
workspace_target="${WORKSPACE_TARGET:-${HOME}/workspace/${repo_name}}"
workspace_ref="${WORKSPACE_REF:-main}"

mkdir -p "$(dirname "$workspace_target")"

if [[ ! -d "${workspace_target}/.git" ]]; then
  git clone "$WORKSPACE_REPO" "$workspace_target"
fi

git -C "$workspace_target" fetch --all --prune
git -C "$workspace_target" checkout "$workspace_ref"
git -C "$workspace_target" pull --ff-only || true

echo "$workspace_target"
