#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Agentic Workstation Nix bootstrapper

Install Nix when needed, fetch this repository, then use the flake to download
and build the repository CLI and validation environment.

Usage:
  scripts/bootstrap-nix.sh [--dir DIR] [--ref REF] [--repo URL]
  scripts/bootstrap-nix.sh [--skip-check] [--skip-develop]

One-line install:
  curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap-nix.sh | bash

Options:
  --dir PATH       Checkout directory. Default: $HOME/agentic-workstation
  --ref REF        Git ref to checkout when cloning. Default: main
  --repo URL       Git repository URL. Default: project repo
  --skip-check     Skip `nix run .#check`
  --skip-develop   Skip realizing the dev shell with `nix develop --command true`

Environment:
  AGENTIC_WORKSTATION_DIR   Default checkout directory
  AGENTIC_BOOTSTRAP_REF     Default Git ref
  AGENTIC_WORKSTATION_REPO  Default Git repository URL
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

apt_package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

run_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    have sudo || die "sudo is required to install bootstrap packages"
    sudo "$@"
  fi
}

TARGET_DIR="${AGENTIC_WORKSTATION_DIR:-${HOME}/agentic-workstation}"
REF="${AGENTIC_BOOTSTRAP_REF:-main}"
REPO_URL="${AGENTIC_WORKSTATION_REPO:-https://github.com/hghalebi/agentic-workstation.git}"
RUN_CHECK=1
REALIZE_DEVELOP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dir)
      [[ $# -ge 2 ]] || die "--dir requires a value"
      TARGET_DIR="$2"
      shift 2
      ;;
    --dir=*)
      TARGET_DIR="${1#*=}"
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
    --skip-check)
      RUN_CHECK=0
      shift
      ;;
    --skip-develop)
      REALIZE_DEVELOP=0
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ "$REF" == "main" ]]; then
  echo "warning: --ref main is not reproducible; prefer a tag or commit" >&2
fi

ensure_apt_packages() {
  local packages=("$@")
  [[ "${#packages[@]}" -gt 0 ]] || return 0

  have apt-get || die "missing required tools (${packages[*]}) and apt-get is unavailable"
  log "Installing bootstrap packages: ${packages[*]}"
  run_sudo apt-get update -y
  run_sudo apt-get install -y "${packages[@]}"
}

ensure_base_tools() {
  local packages=()

  have git || packages+=(git)
  have curl || packages+=(curl)
  apt_package_installed ca-certificates || packages+=(ca-certificates)

  ensure_apt_packages "${packages[@]}"
}

ensure_nix() {
  if have nix; then
    log "Nix already installed"
    nix --version
    return
  fi

  have apt-get || die "Nix is not installed and this bootstrapper currently installs it with apt-get"
  log "Installing Nix from Ubuntu packages"
  run_sudo apt-get update -y
  run_sudo apt-get install -y nix-bin nix-setup-systemd

  export PATH="/nix/var/nix/profiles/default/bin:${HOME}/.nix-profile/bin:/usr/bin:${PATH}"
  have nix || die "Nix package installed, but nix is not available on PATH"
  nix --version
}

enable_flakes_for_user() {
  local nix_config_dir="${HOME}/.config/nix"
  local nix_config="${nix_config_dir}/nix.conf"

  mkdir -p "$nix_config_dir"
  touch "$nix_config"

  if ! grep -Eq '(^|[[:space:]])experimental-features[[:space:]]*=' "$nix_config"; then
    log "Enabling nix-command and flakes for this user"
    printf '\nexperimental-features = nix-command flakes\n' >>"$nix_config"
  fi
}

fetch_repo() {
  if [[ -f "${TARGET_DIR}/flake.nix" ]]; then
    log "Using existing checkout at ${TARGET_DIR}"
    return
  fi

  if [[ -e "$TARGET_DIR" && -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    die "target directory exists and is not an Agentic Workstation checkout: $TARGET_DIR"
  fi

  log "Cloning ${REPO_URL} into ${TARGET_DIR}"
  git clone "$REPO_URL" "$TARGET_DIR"

  if [[ "$REF" != "main" ]]; then
    log "Checking out ${REF}"
    git -C "$TARGET_DIR" fetch origin "$REF"
    git -C "$TARGET_DIR" checkout FETCH_HEAD
  fi
}

nix_cmd() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

run_nix_bootstrap() {
  cd "$TARGET_DIR"

  log "Building Agentic Workstation CLI with Nix"
  nix_cmd build

  log "Verifying built CLI"
  ./result/bin/agentic-workstation --help >/dev/null

  if [[ "$RUN_CHECK" == "1" ]]; then
    log "Running Nix validation bundle"
    nix_cmd run .#check
  fi

  if [[ "$REALIZE_DEVELOP" == "1" ]]; then
    log "Realizing Nix development shell packages"
    nix_cmd develop --command true
  fi

  log "Nix bootstrap complete"
  printf 'Checkout: %s\n' "$TARGET_DIR"
  printf 'CLI: %s/result/bin/agentic-workstation\n' "$TARGET_DIR"
}

ensure_base_tools
ensure_nix
enable_flakes_for_user
fetch_repo
run_nix_bootstrap
