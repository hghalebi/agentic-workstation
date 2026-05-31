#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/diff-manifest.sh expected.json actual.json
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

expected="${1:-}"
actual="${2:-}"

if [[ -z "$expected" || -z "$actual" ]]; then
  usage >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 2
}

tmp_expected="$(mktemp)"
tmp_actual="$(mktemp)"
trap 'rm -f "$tmp_expected" "$tmp_actual"' EXIT

jq -S . "$expected" >"$tmp_expected"
jq -S . "$actual" >"$tmp_actual"

if diff -u "$tmp_expected" "$tmp_actual"; then
  echo "manifest matches"
else
  echo "manifest differs" >&2
  exit 1
fi
