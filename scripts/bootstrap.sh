#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Agentic Workstation bootstrapper

Fetch this repository without requiring git, then run install-agentic-tools.sh.

Usage:
  scripts/bootstrap.sh [--profile PROFILE] [--ref REF] [--resume] [--no-doctor]
  scripts/bootstrap.sh [--profile PROFILE] [--repo URL] [--archive-url URL]
  scripts/bootstrap.sh -- [installer args...]

Options:
  --profile NAME     Installer profile. Default: coding-agent
  --ref REF          GitHub ref to download as a tarball. Default: main
  --repo URL         GitHub repository URL. Default: project repo
  --archive-url URL  Explicit tar.gz archive URL. Overrides --repo and --ref
  --dir PATH         Directory where the repo archive should be unpacked
  --reuse-existing   Run an existing --dir checkout instead of downloading
  --resume           Pass --resume to the installer
  --no-doctor        Pass --no-doctor to the installer

No-git install examples:
  curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash
  curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash -s -- --profile minimal
  wget -qO- https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash -s -- --profile agent-runner --ref v0.1.0

Any arguments after -- are passed directly to install-agentic-tools.sh.
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

PROFILE="${PROFILE:-coding-agent}"
REF="${AGENTIC_BOOTSTRAP_REF:-main}"
REPO_URL="${AGENTIC_WORKSTATION_REPO:-https://github.com/hghalebi/agentic-workstation.git}"
ARCHIVE_URL="${AGENTIC_WORKSTATION_ARCHIVE_URL:-}"
TARGET_DIR="${AGENTIC_WORKSTATION_DIR:-}"
REUSE_EXISTING="${AGENTIC_BOOTSTRAP_REUSE_EXISTING:-0}"
INSTALLER_ARGS=()
INSTALLER_ARGC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
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
    --archive-url)
      [[ $# -ge 2 ]] || die "--archive-url requires a value"
      ARCHIVE_URL="$2"
      shift 2
      ;;
    --archive-url=*)
      ARCHIVE_URL="${1#*=}"
      shift
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
    --reuse-existing)
      REUSE_EXISTING=1
      shift
      ;;
    --resume)
      INSTALLER_ARGS+=("--resume")
      INSTALLER_ARGC=$((INSTALLER_ARGC + 1))
      shift
      ;;
    --no-doctor)
      INSTALLER_ARGS+=("--no-doctor")
      INSTALLER_ARGC=$((INSTALLER_ARGC + 1))
      shift
      ;;
    --)
      shift
      INSTALLER_ARGC=$((INSTALLER_ARGC + $#))
      INSTALLER_ARGS+=("$@")
      break
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ "$REF" == "main" ]]; then
  echo "warning: --ref main is not reproducible; prefer a tag or commit" >&2
fi

install_bootstrap_packages() {
  local packages=("$@")
  [[ "${#packages[@]}" -gt 0 ]] || return 0
  have apt-get || die "missing required tools (${packages[*]}) and apt-get is unavailable"

  log "Installing bootstrap packages: ${packages[*]}"
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update -y
    apt-get install -y "${packages[@]}"
  else
    sudo apt-get update -y
    sudo apt-get install -y "${packages[@]}"
  fi
}

ensure_bootstrap_tools() {
  local packages=()

  if ! have curl && ! have wget; then
    packages+=(curl)
  fi
  have tar || packages+=(tar)
  have gzip || packages+=(gzip)

  if [[ "${#packages[@]}" -gt 0 ]]; then
    packages+=(ca-certificates)
    install_bootstrap_packages "${packages[@]}"
  fi

  if ! have curl && ! have wget; then
    die "install curl or wget before bootstrapping"
  fi
  have tar || die "install tar before bootstrapping"
  have gzip || die "install gzip before bootstrapping"
}

github_archive_url() {
  local repo_url="$1"
  local ref="$2"
  local owner_repo

  case "$repo_url" in
    https://github.com/*)
      owner_repo="${repo_url#https://github.com/}"
      ;;
    git@github.com:*)
      owner_repo="${repo_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      owner_repo="${repo_url#ssh://git@github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  owner_repo="${owner_repo%%\?*}"
  owner_repo="${owner_repo%%#*}"
  owner_repo="${owner_repo%/}"
  owner_repo="${owner_repo%.git}"
  owner_repo="${owner_repo%/}"
  [[ "$owner_repo" == */* ]] || return 1

  printf 'https://codeload.github.com/%s/tar.gz/%s\n' "$owner_repo" "$ref"
}

download() {
  local url="$1"
  local output="$2"

  if have curl; then
    curl -fsSL "$url" -o "$output"
  else
    wget -qO "$output" "$url"
  fi
}

ensure_bootstrap_tools

if [[ -z "$ARCHIVE_URL" ]]; then
  ARCHIVE_URL="$(github_archive_url "$REPO_URL" "$REF")" || die "cannot derive archive URL from repo: $REPO_URL; pass --archive-url"
fi

if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentic-workstation.XXXXXXXX")"
else
  mkdir -p "$TARGET_DIR"
fi

if [[ -e "${TARGET_DIR}/install-agentic-tools.sh" ]]; then
  if [[ "$REUSE_EXISTING" != "1" ]]; then
    die "target directory already contains install-agentic-tools.sh: $TARGET_DIR; remove it or pass --reuse-existing"
  fi
  log "Using existing checkout at $TARGET_DIR"
else
  if [[ -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    die "target directory is not empty and does not contain install-agentic-tools.sh: $TARGET_DIR"
  fi

  archive_file="$(mktemp "${TMPDIR:-/tmp}/agentic-workstation-archive.XXXXXXXX")"
  log "Downloading $ARCHIVE_URL"
  download "$ARCHIVE_URL" "$archive_file"

  log "Unpacking into $TARGET_DIR"
  tar -xzf "$archive_file" --strip-components=1 -C "$TARGET_DIR"
  rm -f "$archive_file"
fi

[[ -x "${TARGET_DIR}/install-agentic-tools.sh" ]] || chmod +x "${TARGET_DIR}/install-agentic-tools.sh"

log "Running installer profile: $PROFILE"
cd "$TARGET_DIR"
if [[ "$INSTALLER_ARGC" -gt 0 ]]; then
  exec ./install-agentic-tools.sh --profile "$PROFILE" "${INSTALLER_ARGS[@]}"
else
  exec ./install-agentic-tools.sh --profile "$PROFILE"
fi
