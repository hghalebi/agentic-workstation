# Roadmap

This project installs tools first and configures machines second. Configuration must be explicit, reversible, and safe around existing dotfiles.

## Current Factory Features

- Profile installs through `profiles/*.env`.
- Dry-run and plan output through `--dry-run`, `--plan`, and `--json-plan`.
- Module selection with `--only` and `--skip`.
- Module metadata in `modules.yaml`.
- Resume markers under `/var/lib/agentic-workstation/installed`.
- Install manifest at `/var/lib/agentic-workstation/manifest.json`.
- Workspace hydration with `WORKSPACE_REPO`.
- Cloud-init rendering for first boot.
- Snapshot cleanup script.
- Docker smoke test.
- Typed Rust planner and lockfile validator.
- Lockfile-backed installer package pins and remote installer audit.
- JSON doctor output and expanded auth status.
- Devcontainer, Bats tests, and security workflow.

## Next Reliability Work

- Publish expected manifests for each profile.
- Add Nix CI coverage for `nix flake check`.
- Add release SBOM and checksum bundle.
- Add Packer image verification jobs.
- Publish first tagged release.

## Hetzner DX Work

- Add `.env.hcloud` defaults and ignored local state output.
- Add `just hcloud-doctor`, `hcloud-render`, `hcloud-create`, and `hcloud-list`.
- Add `just agent-new`, `agent-ssh`, `agent-health`, `agent-pull`, and `agent-destroy`.
- Label every Hetzner server and snapshot created by the repo.
- Store rendered cloud-init, server metadata, manifests, and pulled logs under ignored local state.
- Add per-agent Unix users and a systemd slice before adding heavier container runtimes.
- Add optional Incus support for multi-agent sessions on one larger Hetzner VM.

## Current Auto-Configuration

Enabled by default:

- Add a marked PATH and `mise` activation block to `.profile` and `.bashrc`.
- Add the same block to `.zshrc` when `.zshrc` already exists.
- Configure Git to use `delta` when no value is set for that Git key.
- Install local pre-commit hooks when `.pre-commit-config.yaml` exists.

Disable all of it:

```bash
SKIP_AUTO_CONFIG=1 ./install-agentic-tools.sh
```

## Planned Opt-In Flags

`CONFIGURE_SSH=1`

Create an SSH config include file. Do not rewrite an existing SSH config directly.

`CONFIGURE_GITHUB=1`

Set `gh` defaults after `gh auth login` has already completed.

`CONFIGURE_DIRS=1`

Create standard directories for workspaces, caches, artifacts, and scratch files.

`CONFIGURE_TMUX=1`

Install a minimal tmux config only when no tmux config exists.

`CONFIGURE_ZELLIJ=1`

Install a minimal zellij layout only when no zellij config exists.

`CONFIGURE_GIT_IDENTITY=1`

Set Git author identity from explicit `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL` values.

`CONFIGURE_SECRET_REFS=1`

Create documented 1Password reference placeholders. Do not create or store secrets.

## Non-Goals

- Do not automate login flows.
- Do not write tokens, API keys, or account-specific secrets.
- Do not overwrite dotfiles without an explicit backup and opt-in flag.
- Do not install daemon-level systems such as Docker or Kubernetes by default.
