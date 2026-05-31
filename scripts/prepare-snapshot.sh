#!/usr/bin/env bash
set -euo pipefail

sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo journalctl --vacuum-time=1d || true
sudo cloud-init clean --logs --seed || true
sudo truncate -s 0 /etc/machine-id || true
sudo rm -f /var/lib/dbus/machine-id || true
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id || true

rm -rf "${HOME}/.cache"/* "${HOME}/.npm" "${HOME}/.cargo/registry" "${HOME}/.cache/pip" 2>/dev/null || true
history -c || true

cat <<'NOTE'
snapshot cleanup complete

Before publishing an image, review provider guidance for:
- SSH host key regeneration.
- cloud-init instance identity.
- machine-id regeneration.
- cached credentials in user home directories.
NOTE
