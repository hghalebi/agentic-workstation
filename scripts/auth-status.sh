#!/usr/bin/env bash
set -euo pipefail

JSON=0
RESULTS=()
NEXT=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/auth-status.sh [--json]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON=1
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

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

record() {
  local name="$1"
  local status="$2"
  local next="$3"
  RESULTS+=("${name}:${status}")
  [[ "$status" == "ok" || -z "$next" ]] || NEXT+=("$next")

  if [[ "$JSON" != "1" ]]; then
    printf '%-7s %s\n' "$status" "$name"
  fi
}

check() {
  local name="$1"
  local next="$2"
  shift 2

  if command -v "$1" >/dev/null 2>&1 && timeout 6 "$@" >/dev/null 2>&1; then
    record "$name" ok "$next"
  else
    record "$name" missing "$next"
  fi
}

write_json() {
  printf '{\n'
  printf '  "checks": [\n'
  local first=1 item name status
  for item in "${RESULTS[@]}"; do
    name="${item%:*}"
    status="${item##*:}"
    if [[ "$first" == "1" ]]; then
      first=0
    else
      printf ',\n'
    fi
    printf '    {"name": '
    json_string "$name"
    printf ', "status": '
    json_string "$status"
    printf '}'
  done
  printf '\n  ],\n'
  printf '  "next": [\n'
  first=1
  local next
  for next in "${NEXT[@]}"; do
    if [[ "$first" == "1" ]]; then
      first=0
    else
      printf ',\n'
    fi
    printf '    '
    json_string "$next"
  done
  printf '\n  ]\n'
  printf '}\n'
}

check "GitHub CLI" "gh auth login" gh auth status
check "GitHub Copilot" "copilot auth login" copilot auth status
check "Codex" "codex --login" codex --version
check "Claude" "claude auth login" claude auth status
check "Gemini" "gemini auth login" gemini auth status
check "1Password CLI" "op account add" op vault list
check "Google Cloud" "gcloud auth login --no-launch-browser" gcloud auth list
check "Hetzner Cloud" "hcloud context create default" hcloud context list
check "Neon" "neonctl auth" neonctl me
check "Apps Script clasp" "clasp login --no-localhost" clasp login --status
check "Google Workspace CLI" "gws auth login" gws auth status
check "Harness CLI" "hc auth login" hc user current
check "OpenClaw" "openclaw onboard --install-daemon" openclaw --version
check "llm" "llm keys set openai" llm keys list
check "Hugging Face" "hf auth login" hf auth whoami

if [[ "$JSON" == "1" ]]; then
  write_json
else
  if [[ "${#NEXT[@]}" -gt 0 ]]; then
    printf '\nNext:\n'
    for next in "${NEXT[@]}"; do
      printf '  %s\n' "$next"
    done
  fi
fi
