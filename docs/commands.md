# Commands

The root [commands.md](../commands.md) file is the install command reference. This page is the short operator command list.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash -s -- --profile minimal
./install-agentic-tools.sh
./install-agentic-tools.sh --profile minimal
./install-agentic-tools.sh --profile factory --resume
./install-agentic-tools.sh --only agents
./install-agentic-tools.sh --skip browser
./install-agentic-tools.sh --profile coding-agent --dry-run
./install-agentic-tools.sh --profile coding-agent --json-plan
```

## Health

```bash
./scripts/doctor.sh --profile coding-agent
./scripts/doctor.sh --profile coding-agent --json
./scripts/auth-status.sh
./scripts/auth-status.sh --json
```

## Workspace

```bash
WORKSPACE_REPO=git@github.com:hghalebi/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

## Snapshot

```bash
./install-agentic-tools.sh --profile base-image --resume
./scripts/prepare-snapshot.sh
```

## Cloud-Init

```bash
./scripts/render-cloud-init.sh \
  --user ubuntu \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --profile agent-runner \
  --ref v0.1.0 \
  > cloud-init.agent-runner.yaml
```

## Hetzner Agent VM

```bash
HCLOUD_TOKEN=... ./scripts/agent-vm-new.sh --name repo-fix --profile agent-runner
HCLOUD_TOKEN=... ./scripts/agent-vm-new.sh --name repo-fix --workspace-repo git@github.com:org/project.git
just agent-new repo-fix
```

## Local Validation

```bash
bash -n install-agentic-tools.sh scripts/*.sh cloud/*.sh
shellcheck install-agentic-tools.sh scripts/*.sh cloud/*.sh
shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh cloud/*.sh
PRE_COMMIT_HOME=/tmp/pre-commit-cache pre-commit run --all-files
gitleaks detect --source . --no-git --redact --verbose
./scripts/verify-lockfile.sh
./scripts/audit-remote-installers.sh
```
