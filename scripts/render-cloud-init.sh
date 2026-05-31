#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

USER_NAME="ubuntu"
SSH_KEY_FILE=""
SSH_KEY_VALUE=""
PROFILE="agent-runner"
REPO_URL="https://github.com/hghalebi/agentic-workstation.git"
REF="main"
TEMPLATE="${REPO_DIR}/cloud/cloud-init.yaml.tmpl"
WORKSPACE_REPO=""
WORKSPACE_REF="main"
WORKSPACE_TARGET=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/render-cloud-init.sh --ssh-key PATH [options]

Options:
  --user NAME       Linux user to create. Default: ubuntu
  --ssh-key PATH    SSH public key file.
  --ssh-key-value   SSH public key string.
  --profile NAME    Installer profile. Default: agent-runner
  --repo URL        Agentic Workstation Git URL.
  --ref REF         Git ref to checkout. Prefer a tag or commit for images.
  --workspace-repo URL
                    Workspace Git repo to hydrate during install.
  --workspace-ref REF
                    Workspace ref. Default: main
  --workspace-target PATH
                    Workspace target path.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY_FILE="$2"
      shift 2
      ;;
    --ssh-key-value)
      SSH_KEY_VALUE="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --repo)
      REPO_URL="$2"
      shift 2
      ;;
    --ref)
      REF="$2"
      shift 2
      ;;
    --workspace-repo)
      WORKSPACE_REPO="$2"
      shift 2
      ;;
    --workspace-ref)
      WORKSPACE_REF="$2"
      shift 2
      ;;
    --workspace-target)
      WORKSPACE_TARGET="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$SSH_KEY_FILE" ]]; then
  SSH_KEY_VALUE="$(<"$SSH_KEY_FILE")"
fi

if [[ -z "$SSH_KEY_VALUE" ]]; then
  echo "provide --ssh-key or --ssh-key-value" >&2
  exit 2
fi

if [[ "$REF" == "main" ]]; then
  echo "warning: --ref main is not reproducible; prefer a tag or commit" >&2
fi

shell_quote() {
  local value="$1"

  printf "'"
  while [[ "$value" == *"'"* ]]; do
    printf "%s%s" "${value%%\'*}" "'\\''"
    value="${value#*\'}"
  done
  printf "%s'" "$value"
}

workspace_exports() {
  if [[ -z "$WORKSPACE_REPO" ]]; then
    printf ''
    return 0
  fi

  printf '      export WORKSPACE_REPO=%s\n' "$(shell_quote "$WORKSPACE_REPO")"
  printf '      export WORKSPACE_REF=%s\n' "$(shell_quote "$WORKSPACE_REF")"
  if [[ -n "$WORKSPACE_TARGET" ]]; then
    printf '      export WORKSPACE_TARGET=%s\n' "$(shell_quote "$WORKSPACE_TARGET")"
  fi
}

WORKSPACE_EXPORTS="$(workspace_exports)"

sed \
  -e "s|__USER__|${USER_NAME}|g" \
  -e "s|__SSH_KEY__|${SSH_KEY_VALUE}|g" \
  -e "s|__PROFILE__|${PROFILE}|g" \
  -e "s|__REPO__|${REPO_URL}|g" \
  -e "s|__REF__|${REF}|g" \
  "$TEMPLATE" |
  while IFS= read -r line; do
    if [[ "$line" == "__WORKSPACE_EXPORTS__" ]]; then
      printf '%s' "$WORKSPACE_EXPORTS"
    else
      printf '%s\n' "$line"
    fi
  done
