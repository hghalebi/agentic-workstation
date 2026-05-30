#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROFILE="coding-agent"

usage() {
  cat <<'USAGE'
Usage:
  scripts/doctor.sh [--profile PROFILE]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
      shift
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

profile_path="${REPO_DIR}/profiles/${PROFILE}.env"
if [[ -f "$profile_path" ]]; then
  # shellcheck disable=SC1090
  source "$profile_path"
else
  echo "unknown profile: ${PROFILE}" >&2
  exit 1
fi

failures=0

need() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'ok      %s\n' "$cmd"
  else
    printf 'missing %s\n' "$cmd"
    failures=$((failures + 1))
  fi
}

need_group() {
  local enabled="$1"
  shift
  [[ "$enabled" == "1" ]] || return 0
  for cmd in "$@"; do
    need "$cmd"
  done
}

need_group "${INSTALL_BASE:-0}" git gh curl jq rg fd fzf tmux python3 node npm go op
need_group "${INSTALL_RUNTIMES:-0}" uv rustc cargo
need_group "${INSTALL_VERSION_MANAGERS:-0}" mise aqua
need_group "${INSTALL_GIT_HELPERS:-0}" yq delta
need_group "${INSTALL_AGENT_CLIS:-0}" codex claude gemini copilot opencode openclaw aider llm openhands
need_group "${INSTALL_CLOUD_CLIS:-0}" gcloud hcloud neonctl clasp gws
need_group "${INSTALL_TERMINAL_TOOLS:-0}" zellij
need_group "${INSTALL_FACTORY_TOOLS:-0}" task just pandoc pdftotext ffmpeg tesseract http dvc hf
need_group "${INSTALL_SECURITY_TOOLS:-0}" semgrep snyk gitleaks syft grype cosign trivy hadolint
need_group "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" ollama
need_group "${INSTALL_HARNESS:-0}" hc

if [[ -f /var/lib/agentic-workstation/manifest.json ]]; then
  printf 'ok      manifest\n'
else
  printf 'missing manifest\n'
  failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
  echo "doctor failed: ${failures} missing checks" >&2
  exit 1
fi

echo "doctor passed for profile: ${PROFILE}"
