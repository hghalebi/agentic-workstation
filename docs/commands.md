# Commands

The root [commands.md](../commands.md) file is the install command reference. This page is the short operator command list.

## Install

```bash
./install-agentic-tools.sh
./install-agentic-tools.sh --profile minimal
./install-agentic-tools.sh --profile factory --resume
./install-agentic-tools.sh --only agents
./install-agentic-tools.sh --skip browser
```

## Health

```bash
./scripts/doctor.sh --profile coding-agent
./scripts/auth-status.sh
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

## Local Validation

```bash
bash -n install-agentic-tools.sh scripts/*.sh cloud/*.sh
shellcheck install-agentic-tools.sh scripts/*.sh cloud/*.sh
shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh cloud/*.sh
PRE_COMMIT_HOME=/tmp/pre-commit-cache pre-commit run --all-files
gitleaks detect --source . --no-git --redact --verbose
```
