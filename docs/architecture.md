# Architecture

Agentic Workstation is a layered Ubuntu workstation factory. Each layer has one job: install tools, hydrate workspaces, verify state, or report readiness.

```text
Ubuntu base VM
  -> base-image profile
  -> provider snapshot
  -> cloud-init first boot
  -> profile install
  -> workspace hydration
  -> manifest + doctor checks
  -> auth-status inspection
```

## Core Flow

1. Select a profile from `profiles/*.env`.
2. Resolve enabled modules.
3. Install each module idempotently.
4. Write `/var/lib/agentic-workstation/manifest.json`.
5. Run `scripts/doctor.sh`.
6. Run auth checks manually with `scripts/auth-status.sh`.

## Layers

| Layer | Responsibility |
| --- | --- |
| `profiles/*.env` | Select enabled installer modules. |
| `modules.yaml` | Document module metadata, verification commands, and package sources. |
| `install-agentic-tools.sh` | Orchestrate modules and write the manifest. |
| `src/` | Typed Rust CLI for read-only planning and lockfile validation. |
| `config/` | Hold mise and aqua configuration. |
| `cloud/` | Provide cloud-init examples and rendered user-data. |
| `images/` | Hold Packer image stubs. |
| `scripts/doctor.sh` | Verify installed tools. |
| `scripts/auth-status.sh` | Inspect auth readiness without handling secrets. |

## Design Rules

- Profiles decide what to install.
- Modules do the work.
- Auth is never automated.
- Secrets are never written by the installer.
- Plans should be inspectable before mutation.
- Manifests should make installed state auditable after mutation.
- Raw profile, lockfile, and environment input should be converted into typed Rust domain values before read-only policy decisions.

## Nix Boundary

The flake builds the Rust CLI and validation tools. It does not replace the full Ubuntu bootstrap because the installer mutates system package state, shell config, service files, and optional workspace hydration.
