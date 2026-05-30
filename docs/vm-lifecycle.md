# VM Lifecycle

Use layers instead of reinstalling every tool on every VM.

## Base Image

Create a clean Ubuntu VM, then run:

```bash
./install-agentic-tools.sh --profile base-image --resume
./scripts/prepare-snapshot.sh
```

Create a provider snapshot from that VM.

## New VM

Create future VMs from the snapshot. At first boot, run only the profile-specific layer:

```bash
./install-agentic-tools.sh --profile coding-agent --resume
```

For unattended bootstrapping, pass `cloud/cloud-init.yaml` to the provider.

## Workspace Hydration

Clone a workspace during install:

```bash
WORKSPACE_REPO=git@github.com:hghalebi/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

## Health

After install:

```bash
./scripts/doctor.sh --profile coding-agent
./scripts/auth-status.sh
```

The installer writes `/var/lib/agentic-workstation/manifest.json` with the selected profile, install time, host, OS, and important tool versions.
