#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
AGENTIC_PROFILE="${AGENTIC_PROFILE:-coding-agent}"
REPO_URL="${AGENTIC_WORKSTATION_REPO:-https://github.com/hghalebi/agentic-workstation.git}"
TARGET_DIR="${AGENTIC_WORKSTATION_DIR:-/opt/agentic-workstation/repo}"

apt-get update -y
apt-get install -y git curl ca-certificates

if [[ ! -d "${TARGET_DIR}/.git" ]]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

git -C "$TARGET_DIR" pull --ff-only || true
"${TARGET_DIR}/install-agentic-tools.sh" --profile "$AGENTIC_PROFILE" --resume
