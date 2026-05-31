# VM Lifecycle

Use layers instead of reinstalling every tool on every VM.

## 1. Build a Base Image

Create a clean Ubuntu VM:

```bash
git clone https://github.com/hghalebi/agentic-workstation.git
cd agentic-workstation
./install-agentic-tools.sh --profile base-image --resume
./scripts/prepare-snapshot.sh
```

Create a provider snapshot from that VM.

## 2. Start a New VM

Create new VMs from the snapshot. Run only the profile-specific layer:

```bash
./install-agentic-tools.sh --profile agent-runner --resume
```

## 3. Provision With Cloud-Init

Render cloud-init user data for first boot:

```bash
./scripts/render-cloud-init.sh \
  --user ubuntu \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --profile agent-runner \
  --repo https://github.com/hghalebi/agentic-workstation.git \
  --ref v0.1.0 \
  > cloud-init.agent-runner.yaml
```

Prefer a tag or commit for `--ref`. `main` is convenient, but not reproducible.

Hetzner helper:

```bash
HCLOUD_SSH_KEY=my-key-name \
HCLOUD_SERVER_NAME=agent-01 \
./cloud/hetzner-create-vm.sh
```

## 4. Hydrate a Workspace

Clone a workspace during install:

```bash
WORKSPACE_REPO=git@github.com:hghalebi/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

Copy a local directory:

```bash
WORKSPACE_SOURCE=/path/to/workspace \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile coding-agent
```

## 5. Check Health

After install:

```bash
./scripts/doctor.sh --profile coding-agent
./scripts/auth-status.sh
```

The installer writes:

```text
/var/lib/agentic-workstation/manifest.json
```

The manifest records the selected profile, install time, host, OS, and important tool versions.

## 6. Test Locally

Static Docker smoke test:

```bash
docker build -f tests/Dockerfile.ubuntu-24.04 .
```

Opt-in full install test:

```bash
docker build --build-arg RUN_INSTALL=1 -f tests/Dockerfile.ubuntu-24.04 .
```
