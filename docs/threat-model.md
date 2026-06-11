# Threat Model

Agentic Workstation installs privileged developer tooling. The highest-risk areas are supply chain, shell execution, secrets, and cloud bootstrap data.

## Assets

- Host root access.
- User shell configuration.
- Git and cloud credentials.
- 1Password access.
- Workspace source code.
- Generated manifests and logs.

## Main Risks

| Risk | Mitigation |
| --- | --- |
| Remote installer compromise | Track remote installers in `agentic-tools.lock.yaml`, validate with the Rust lockfile validator, and audit with `scripts/audit-remote-installers.sh`. |
| Moving package versions | Installer package commands consume lockfile-pinned versions; documented remote installer exceptions stay explicit. |
| Secret leakage | Do not automate auth; run `scripts/auth-status.sh` for readiness only. |
| Dotfile damage | Use marked shell blocks and `SKIP_AUTO_CONFIG=1`. |
| Cloud-init exposure | Render cloud-init from explicit inputs; do not commit real SSH keys or secrets. |
| Snapshot credential carryover | Run `scripts/prepare-snapshot.sh` and review provider-specific snapshot guidance. |
| Planning drift | Compare typed Rust plan output against Bash `--json-plan` behavior before changing install semantics. |

## Non-Goals

- Managing secrets.
- Replacing 1Password, cloud IAM, or GitHub auth flows.
- Hardening Kubernetes or Docker hosts by default.
