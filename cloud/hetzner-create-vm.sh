#!/usr/bin/env bash
set -euo pipefail

: "${HCLOUD_SERVER_NAME:=agentic-workstation}"
: "${HCLOUD_SERVER_TYPE:=cx32}"
: "${HCLOUD_IMAGE:=ubuntu-24.04}"
: "${HCLOUD_LOCATION:=fsn1}"
: "${HCLOUD_SSH_KEY:?set HCLOUD_SSH_KEY to an existing Hetzner SSH key name or ID}"

hcloud server create \
  --name "$HCLOUD_SERVER_NAME" \
  --type "$HCLOUD_SERVER_TYPE" \
  --image "$HCLOUD_IMAGE" \
  --location "$HCLOUD_LOCATION" \
  --ssh-key "$HCLOUD_SSH_KEY" \
  --user-data-from-file cloud/cloud-init.yaml
