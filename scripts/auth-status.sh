#!/usr/bin/env bash
set -euo pipefail

check() {
  local name="$1"
  shift

  if command -v "$1" >/dev/null 2>&1 && "$@" >/dev/null 2>&1; then
    printf 'ok      %s\n' "$name"
  else
    printf 'missing %s\n' "$name"
  fi
}

check "GitHub CLI" gh auth status
check "1Password CLI" op vault list
check "Google Cloud" gcloud auth list
check "Neon" neonctl me
check "Hugging Face" hf auth whoami
