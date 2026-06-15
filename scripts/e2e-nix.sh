#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Agentic Workstation Nix end-to-end smoke test

Clone this repository into a temporary directory through scripts/bootstrap-nix.sh,
build the Nix CLI package, then verify the generated CLI can render a plan.

Usage:
  scripts/e2e-nix.sh [--full] [--keep]

Options:
  --full   Also run `nix run .#check` and realize `nix develop --command true`.
  --keep   Keep the temporary checkout and print its path.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="${AGENTIC_E2E_REPO:-}"
run_full="${AGENTIC_E2E_FULL:-0}"
keep_tmp=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --full)
      run_full=1
      shift
      ;;
    --keep)
      keep_tmp=1
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v nix >/dev/null 2>&1 || die "nix is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

if [[ -z "$repo_root" ]]; then
  if [[ -f "$PWD/scripts/bootstrap-nix.sh" ]]; then
    repo_root="$PWD"
  else
    repo_root="$script_root"
  fi
fi

[[ -f "$repo_root/scripts/bootstrap-nix.sh" ]] || die "missing scripts/bootstrap-nix.sh in $repo_root"
[[ -f "$repo_root/flake.nix" ]] || die "missing flake.nix in $repo_root"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/agentic-workstation-e2e.XXXXXX")"
source_dir="${work_dir}/source"
checkout_dir="${work_dir}/agentic-workstation"

cleanup() {
  if [[ "$keep_tmp" == "1" ]]; then
    printf 'Kept e2e checkout: %s\n' "$checkout_dir"
  else
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT

mkdir -p "$source_dir"
(
  cd "$repo_root"
  tar \
    --exclude ./.cache \
    --exclude ./.direnv \
    --exclude ./.git \
    --exclude ./result \
    --exclude ./target \
    --exclude ./tmp \
    -cf - .
) | (
  cd "$source_dir"
  tar -xf -
)

git -C "$source_dir" init -q
git -C "$source_dir" config user.email "agentic-workstation-e2e@example.invalid"
git -C "$source_dir" config user.name "Agentic Workstation E2E"
git -C "$source_dir" add .
git -C "$source_dir" commit -qm "e2e snapshot"
git -C "$source_dir" branch -M e2e-snapshot

bootstrap_args=(
  --dir "$checkout_dir"
  --ref e2e-snapshot
  --repo "$source_dir"
)

if [[ "$run_full" != "1" ]]; then
  bootstrap_args+=(--skip-check --skip-develop)
fi

"$repo_root/scripts/bootstrap-nix.sh" "${bootstrap_args[@]}"

"$checkout_dir/result/bin/agentic-workstation" plan --profile minimal --json |
  jq -e '.profile == "minimal"' >/dev/null

printf 'Nix e2e smoke passed: %s\n' "$checkout_dir"
