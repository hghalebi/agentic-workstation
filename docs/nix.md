# Nix Workflow

Use Nix for reproducible repository development, validation, and CLI packaging.

## One-command Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap-nix.sh | bash
```

The bootstrapper installs Nix with apt when it is missing, clones the repo into `$HOME/agentic-workstation`, builds the CLI, runs `nix run .#check`, and realizes the default development shell packages.

## Development Shells

```bash
nix --extra-experimental-features 'nix-command flakes' develop
nix --extra-experimental-features 'nix-command flakes' develop .#minimal
nix --extra-experimental-features 'nix-command flakes' develop .#coding-agent
nix --extra-experimental-features 'nix-command flakes' develop .#factory
nix --extra-experimental-features 'nix-command flakes' develop .#security
```

Use `.#minimal` for lightweight validation, `.#coding-agent` for normal project work, `.#factory` for broader operational tooling, and `.#security` for supply-chain review tooling.

## Apps

```bash
nix --extra-experimental-features 'nix-command flakes' run .#plan -- --profile coding-agent
nix --extra-experimental-features 'nix-command flakes' run .#doctor -- --profile coding-agent
nix --extra-experimental-features 'nix-command flakes' run .#check
nix --extra-experimental-features 'nix-command flakes' run .#e2e
nix --extra-experimental-features 'nix-command flakes' run .#docker-smoke
```

`.#e2e` clones the repository through `scripts/bootstrap-nix.sh` into a temporary directory, builds the CLI with Nix, and verifies the generated CLI can render a minimal profile plan.

## Package Install

```bash
nix --extra-experimental-features 'nix-command flakes' profile install github:hghalebi/agentic-workstation
agentic-workstation plan --profile coding-agent --json
```

Use this when you only need the typed CLI. Use `./install-agentic-tools.sh` for full Ubuntu workstation setup.

## Local Shortcuts

```bash
just nix-check
just nix-e2e
just nix-shell coding-agent
```

These commands wrap the same flake apps used by CI.

## Boundary

Nix owns reproducible development inputs, CLI packaging, and repository validation. The Bash installer still owns privileged machine mutation: apt packages, shell configuration, system services, manifests, and optional workspace hydration.
