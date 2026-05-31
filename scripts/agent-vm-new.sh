#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'USAGE'
Create a Hetzner agent VM, register SSH access, and run the workstation installer.

Usage:
  scripts/agent-vm-new.sh [options]

Options:
  --name NAME              Server name. Default: agentic-<utc timestamp>
  --profile NAME           Installer profile for cloud-init. Default: agent-runner
  --ref REF                Agentic Workstation ref for cloud-init. Default: main
  --repo URL               Agentic Workstation repo URL.
  --user NAME              Linux user to create. Default: ubuntu
  --server-type TYPE       Hetzner server type. Default: cx32
  --image IMAGE            Hetzner image or snapshot. Default: ubuntu-24.04
  --location LOCATION      Hetzner location. Default: fsn1
  --ssh-key PATH           Local private SSH key path. Default: ~/.ssh/agentic-workstation_ed25519
  --ssh-key-name NAME      Hetzner SSH key name. Default: agentic-workstation-<hostname>
  --workspace-repo URL     Repo to hydrate on the VM.
  --workspace-ref REF      Workspace ref to checkout. Default: main
  --workspace-target PATH  Workspace target on the VM. Default: /workspace/<server-name>
  --label KEY=VALUE        Extra Hetzner label. May be repeated.
  --dry-run                Render files and print the hcloud command without creating a VM.

Environment:
  HCLOUD_TOKEN must be available to hcloud.
  .env.hcloud is loaded when present and can set defaults.

Examples:
  scripts/agent-vm-new.sh --name repo-fix
  scripts/agent-vm-new.sh --name repo-fix --profile coding-agent --server-type cx42
  scripts/agent-vm-new.sh --name repo-fix --workspace-repo git@github.com:org/project.git
USAGE
}

log() {
  printf '\n==> %s\n' "$*" >&2
}

die() {
  echo "error: $*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

load_env_file() {
  local env_file="${REPO_DIR}/.env.hcloud"
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
}

sanitize_label_value() {
  local value="$1"
  value="$(printf '%s' "$value" | tr -c 'A-Za-z0-9_.-' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
  printf '%.63s' "${value:-unknown}"
}

require_hcloud_auth() {
  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    hcloud server list >/dev/null 2>&1 || die "HCLOUD_TOKEN is not set and hcloud is not authenticated"
  fi
}

ensure_local_ssh_key() {
  local private_key="$1"
  local public_key="${private_key}.pub"

  mkdir -p "$(dirname "$private_key")"
  chmod 700 "$(dirname "$private_key")"

  if [[ -f "$private_key" && ! -f "$public_key" ]]; then
    log "Deriving missing public key: $public_key"
    ssh-keygen -y -f "$private_key" >"$public_key"
  fi

  if [[ ! -f "$private_key" ]]; then
    log "Generating SSH key: $private_key"
    ssh-keygen -t ed25519 -N "" -C "agentic-workstation" -f "$private_key"
  fi

  chmod 600 "$private_key"
  chmod 644 "$public_key"
}

ensure_hcloud_ssh_key() {
  local key_name="$1"
  local public_key="$2"
  local existing_key_json
  local existing_public_key
  local local_public_key

  if existing_key_json="$(hcloud ssh-key describe "$key_name" --output json 2>/dev/null)"; then
    if have jq; then
      existing_public_key="$(jq -r '.public_key // .ssh_key.public_key // empty' <<<"$existing_key_json")"
      local_public_key="$(<"$public_key")"
      if [[ -n "$existing_public_key" && "$existing_public_key" != "$local_public_key" ]]; then
        die "Hetzner SSH key '$key_name' exists but does not match $public_key; pass --ssh-key-name with a new name"
      fi
    else
      echo "warning: jq is missing; cannot verify existing Hetzner SSH key material" >&2
    fi
    log "Using existing Hetzner SSH key: $key_name"
    return 0
  fi

  log "Creating Hetzner SSH key: $key_name"
  hcloud ssh-key create \
    --name "$key_name" \
    --public-key-from-file "$public_key" \
    --label app=agentic-workstation \
    --label role=operator-access \
    >/dev/null
}

write_cloud_init() {
  local output="$1"
  local public_key="$2"
  local render_args=()

  if [[ -n "$WORKSPACE_REPO" ]]; then
    render_args+=(
      --workspace-repo "$WORKSPACE_REPO"
      --workspace-ref "$WORKSPACE_REF"
      --workspace-target "$WORKSPACE_TARGET"
    )
  fi

  "${SCRIPT_DIR}/render-cloud-init.sh" \
    --user "$USER_NAME" \
    --ssh-key "$public_key" \
    --profile "$PROFILE" \
    --repo "$REPO_URL" \
    --ref "$REF" \
    "${render_args[@]}" \
    >"$output"
}

load_env_file

SERVER_NAME="${HCLOUD_SERVER_NAME:-agentic-$(date -u +%Y%m%d-%H%M%S)}"
PROFILE="${AGENTIC_PROFILE:-agent-runner}"
REF="${AGENTIC_BOOTSTRAP_REF:-main}"
REPO_URL="${AGENTIC_WORKSTATION_REPO:-https://github.com/hghalebi/agentic-workstation.git}"
USER_NAME="${AGENTIC_HCLOUD_USER:-ubuntu}"
SERVER_TYPE="${HCLOUD_SERVER_TYPE:-cx32}"
IMAGE="${HCLOUD_IMAGE:-ubuntu-24.04}"
LOCATION="${HCLOUD_LOCATION:-fsn1}"
SSH_KEY_PATH="${AGENTIC_HCLOUD_SSH_KEY_PATH:-${HOME}/.ssh/agentic-workstation_ed25519}"
SSH_KEY_NAME="${HCLOUD_SSH_KEY_NAME:-agentic-workstation-$(hostname -s 2>/dev/null || echo local)}"
WORKSPACE_REPO="${WORKSPACE_REPO:-}"
WORKSPACE_REF="${WORKSPACE_REF:-main}"
WORKSPACE_TARGET="${WORKSPACE_TARGET:-}"
DRY_RUN=0
EXTRA_LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --name)
      [[ $# -ge 2 ]] || die "--name requires a value"
      SERVER_NAME="$2"
      shift 2
      ;;
    --name=*)
      SERVER_NAME="${1#*=}"
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
      shift
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "--ref requires a value"
      REF="$2"
      shift 2
      ;;
    --ref=*)
      REF="${1#*=}"
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || die "--repo requires a value"
      REPO_URL="$2"
      shift 2
      ;;
    --repo=*)
      REPO_URL="${1#*=}"
      shift
      ;;
    --user)
      [[ $# -ge 2 ]] || die "--user requires a value"
      USER_NAME="$2"
      shift 2
      ;;
    --user=*)
      USER_NAME="${1#*=}"
      shift
      ;;
    --server-type)
      [[ $# -ge 2 ]] || die "--server-type requires a value"
      SERVER_TYPE="$2"
      shift 2
      ;;
    --server-type=*)
      SERVER_TYPE="${1#*=}"
      shift
      ;;
    --image)
      [[ $# -ge 2 ]] || die "--image requires a value"
      IMAGE="$2"
      shift 2
      ;;
    --image=*)
      IMAGE="${1#*=}"
      shift
      ;;
    --location)
      [[ $# -ge 2 ]] || die "--location requires a value"
      LOCATION="$2"
      shift 2
      ;;
    --location=*)
      LOCATION="${1#*=}"
      shift
      ;;
    --ssh-key)
      [[ $# -ge 2 ]] || die "--ssh-key requires a value"
      SSH_KEY_PATH="$2"
      shift 2
      ;;
    --ssh-key=*)
      SSH_KEY_PATH="${1#*=}"
      shift
      ;;
    --ssh-key-name)
      [[ $# -ge 2 ]] || die "--ssh-key-name requires a value"
      SSH_KEY_NAME="$2"
      shift 2
      ;;
    --ssh-key-name=*)
      SSH_KEY_NAME="${1#*=}"
      shift
      ;;
    --workspace-repo)
      [[ $# -ge 2 ]] || die "--workspace-repo requires a value"
      WORKSPACE_REPO="$2"
      shift 2
      ;;
    --workspace-repo=*)
      WORKSPACE_REPO="${1#*=}"
      shift
      ;;
    --workspace-ref)
      [[ $# -ge 2 ]] || die "--workspace-ref requires a value"
      WORKSPACE_REF="$2"
      shift 2
      ;;
    --workspace-ref=*)
      WORKSPACE_REF="${1#*=}"
      shift
      ;;
    --workspace-target)
      [[ $# -ge 2 ]] || die "--workspace-target requires a value"
      WORKSPACE_TARGET="$2"
      shift 2
      ;;
    --workspace-target=*)
      WORKSPACE_TARGET="${1#*=}"
      shift
      ;;
    --label)
      [[ $# -ge 2 ]] || die "--label requires KEY=VALUE"
      EXTRA_LABELS+=("$2")
      shift 2
      ;;
    --label=*)
      EXTRA_LABELS+=("${1#*=}")
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ -z "$WORKSPACE_TARGET" ]]; then
  WORKSPACE_TARGET="/workspace/${SERVER_NAME}"
fi

if [[ "$REF" == "main" ]]; then
  echo "warning: --ref main is not reproducible; prefer a tag or commit" >&2
fi
if [[ "$WORKSPACE_REPO" == git@* || "$WORKSPACE_REPO" == ssh://* ]]; then
  echo "warning: SSH workspace repos need credentials on the VM; this script does not copy private keys or tokens" >&2
fi

have hcloud || die "missing hcloud; install the cloud profile first or run ./install-agentic-tools.sh --only cloud"
have ssh-keygen || die "missing ssh-keygen"

STATE_DIR="${AGENTIC_STATE_DIR:-${REPO_DIR}/state/hcloud}"
CLOUD_INIT_DIR="${STATE_DIR}/cloud-init"
SERVER_STATE_DIR="${STATE_DIR}/servers"
mkdir -p "$CLOUD_INIT_DIR" "$SERVER_STATE_DIR"

SSH_KEY_PATH="${SSH_KEY_PATH/#\~/${HOME}}"
SSH_PUBLIC_KEY="${SSH_KEY_PATH}.pub"
CLOUD_INIT_FILE="${CLOUD_INIT_DIR}/${SERVER_NAME}.yaml"
SERVER_STATE_FILE="${SERVER_STATE_DIR}/${SERVER_NAME}.json"

ensure_local_ssh_key "$SSH_KEY_PATH"
write_cloud_init "$CLOUD_INIT_FILE" "$SSH_PUBLIC_KEY"

LABEL_ARGS=(
  --label "app=agentic-workstation"
  --label "role=agent-runner"
  --label "profile=$(sanitize_label_value "$PROFILE")"
  --label "owner=$(sanitize_label_value "${AGENTIC_HCLOUD_LABEL_OWNER:-${USER:-operator}}")"
)

if [[ -n "$WORKSPACE_REPO" ]]; then
  LABEL_ARGS+=(--label "repo=$(sanitize_label_value "$WORKSPACE_REPO")")
fi

for label in "${EXTRA_LABELS[@]}"; do
  LABEL_ARGS+=(--label "$label")
done

CREATE_CMD=(
  hcloud server create
  --name "$SERVER_NAME"
  --type "$SERVER_TYPE"
  --image "$IMAGE"
  --location "$LOCATION"
  --ssh-key "$SSH_KEY_NAME"
  --user-data-from-file "$CLOUD_INIT_FILE"
  --output json
  "${LABEL_ARGS[@]}"
)

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'cloud-init: %s\n' "$CLOUD_INIT_FILE"
  printf 'ssh-key:    %s (%s)\n' "$SSH_KEY_NAME" "$SSH_PUBLIC_KEY"
  printf 'command:'
  printf ' %q' "${CREATE_CMD[@]}"
  printf '\n'
  exit 0
fi

require_hcloud_auth
ensure_hcloud_ssh_key "$SSH_KEY_NAME" "$SSH_PUBLIC_KEY"

log "Creating Hetzner server: $SERVER_NAME"
"${CREATE_CMD[@]}" >"$SERVER_STATE_FILE"

SERVER_IPV4=""
if have jq; then
  SERVER_IPV4="$(jq -r '.server.public_net.ipv4.ip // empty' "$SERVER_STATE_FILE")"
fi

log "Server state written: $SERVER_STATE_FILE"
printf 'name:       %s\n' "$SERVER_NAME"
printf 'profile:    %s\n' "$PROFILE"
printf 'image:      %s\n' "$IMAGE"
printf 'type:       %s\n' "$SERVER_TYPE"
printf 'location:   %s\n' "$LOCATION"
printf 'cloud-init: %s\n' "$CLOUD_INIT_FILE"
if [[ -n "$SERVER_IPV4" ]]; then
  printf 'ssh:        ssh -i %q %s@%s\n' "$SSH_KEY_PATH" "$USER_NAME" "$SERVER_IPV4"
else
  printf 'ssh:        resolve IP from %s\n' "$SERVER_STATE_FILE"
fi
printf 'status:     hcloud server describe %q\n' "$SERVER_NAME"
