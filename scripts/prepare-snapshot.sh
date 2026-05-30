#!/usr/bin/env bash
set -euo pipefail

sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo journalctl --vacuum-time=1d || true

rm -rf "${HOME}/.cache"/*
history -c || true

echo "snapshot cleanup complete"
