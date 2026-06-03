#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROFILE="coding-agent"
JSON=0
RESULTS=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/doctor.sh [--profile PROFILE] [--json]
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

profile_path="${REPO_DIR}/profiles/${PROFILE}.env"
if [[ -f "$profile_path" ]]; then
  # shellcheck disable=SC1090
  source "$profile_path"
else
  echo "unknown profile: ${PROFILE}" >&2
  exit 1
fi

failures=0

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
  RESULTS+=("${name}:${status}")

  if [[ "$JSON" != "1" ]]; then
    printf '%-7s %s\n' "$status" "$name"
  fi
}

need() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    record "$cmd" ok
  else
    record "$cmd" missing
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

need_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    record "$path" ok
  else
    record "$path" missing
    failures=$((failures + 1))
  fi
}

need_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    record "$path" ok
  else
    record "$path" missing
    failures=$((failures + 1))
  fi
}

need_service() {
  local service="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    record "service:${service}" unknown
    return 0
  fi
  if systemctl is-active --quiet "$service" >/dev/null 2>&1; then
    record "service:${service}" ok
  else
    record "service:${service}" inactive
    failures=$((failures + 1))
  fi
}

need_docker_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    record "docker compose" ok
  else
    record "docker compose" missing
    failures=$((failures + 1))
  fi
}

write_json() {
  printf '{\n'
  printf '  "profile": '
  json_string "$PROFILE"
  printf ',\n'
  printf '  "ok": %s,\n' "$(if [[ "$failures" -eq 0 ]]; then printf true; else printf false; fi)"
  printf '  "failures": %s,\n' "$failures"
  printf '  "checks": [\n'

  local first=1
  local item name status
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
  printf '\n  ]\n'
  printf '}\n'
}

need_group "${INSTALL_BASE:-0}" git gh curl jq rg fd fzf tmux python3 node npm go op shellcheck shfmt bats
need_group "${INSTALL_SERVER_BASE:-0}" ufw fail2ban-client nginx
need_group "${INSTALL_DOCKER:-0}" docker
[[ "${INSTALL_DOCKER:-0}" == "1" ]] && need_docker_compose
need_group "${INSTALL_RUNTIMES:-0}" uv rustc cargo
need_group "${INSTALL_RUST_SERVER_TOOLS:-0}" sqlx cargo-nextest cargo-watch
need_group "${INSTALL_VERSION_MANAGERS:-0}" mise aqua
need_group "${INSTALL_GIT_HELPERS:-0}" yq delta
need_group "${INSTALL_AGENT_CLIS:-0}" codex claude gemini copilot opencode openclaw aider llm openhands
need_group "${INSTALL_CLOUD_CLIS:-0}" gcloud hcloud neonctl clasp gws
need_group "${INSTALL_TERMINAL_TOOLS:-0}" zellij
need_group "${INSTALL_FACTORY_TOOLS:-0}" task just pandoc pdftotext ffmpeg tesseract http dvc hf
need_group "${INSTALL_SECURITY_TOOLS:-0}" semgrep snyk gitleaks syft grype cosign trivy hadolint
need_group "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" ollama
need_group "${INSTALL_HARNESS:-0}" hc
need_group "${INSTALL_HETZNER_S3:-0}" aws

if [[ "${INSTALL_SERVER_BASE:-0}" == "1" ]]; then
  need_service fail2ban
  need_service nginx
  need_service unattended-upgrades
fi

if [[ "${INSTALL_OPENCLAW_LAYOUT:-0}" == "1" ]]; then
  need_dir /opt/openclaw/app
  need_dir /opt/openclaw/tools
  need_dir /opt/openclaw/repos
  need_dir /opt/openclaw/otel
  need_dir /opt/openclaw/secrets
  need_dir /opt/openclaw/backups
  need_dir /opt/openclaw/logs
fi

if [[ "${INSTALL_OPENTELEMETRY:-0}" == "1" ]]; then
  need_file /opt/openclaw/otel/docker-compose.yaml
  need_file /opt/openclaw/otel/collector.yaml
fi

if [[ "${INSTALL_NEON_SUPPORT:-0}" == "1" ]]; then
  need_file /opt/openclaw/app/.env.example
fi

if [[ "${INSTALL_HETZNER_S3:-0}" == "1" ]]; then
  need_file /opt/openclaw/secrets/hetzner-s3.env.example
  need_file /opt/openclaw/tools/check-hetzner-s3-bucket.sh
fi

if [[ "${INSTALL_ONEPASSWORD_SSH:-0}" == "1" ]]; then
  need_file /opt/openclaw/tools/op-ssh-helper
fi

if [[ -n "${DOTFILES_REPO:-}" ]]; then
  need_dir "${DOTFILES_TARGET:-${HOME}/.dotfiles}"
fi

if [[ -f /var/lib/agentic-workstation/manifest.json ]]; then
  record manifest ok
else
  record manifest missing
  failures=$((failures + 1))
fi

if [[ "$JSON" == "1" ]]; then
  write_json
fi

if [[ "$failures" -gt 0 ]]; then
  [[ "$JSON" == "1" ]] || echo "doctor failed: ${failures} missing checks" >&2
  exit 1
fi

[[ "$JSON" == "1" ]] || echo "doctor passed for profile: ${PROFILE}"
