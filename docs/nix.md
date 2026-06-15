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

## Terminal Behavior

Nix does not make every package global by default. It gives you reproducible terminal environments on demand.

Inside a dev shell, the shell `PATH` contains the packages declared by that shell:

```bash
nix --extra-experimental-features 'nix-command flakes' develop .#coding-agent
agentic-workstation plan --profile coding-agent --json
cargo test
shellcheck scripts/*.sh
```

When you exit that shell, your normal terminal environment is unchanged. This keeps project tooling reproducible without mutating the whole machine.

Use `nix run` when you want one command without opening a shell:

```bash
nix --extra-experimental-features 'nix-command flakes' run .#plan -- --profile coding-agent
nix --extra-experimental-features 'nix-command flakes' run .#check
```

Use `nix profile add` when you want a package available in normal terminals:

```bash
nix --extra-experimental-features 'nix-command flakes' profile add github:hghalebi/agentic-workstation
agentic-workstation --help
```

Profile installs are for user-facing tools such as the typed CLI. Prefer `nix develop` for project build tools so the repository controls exact versions.

## Development Workflow

For reproducible development, start work inside the shell that matches the task:

```bash
nix --extra-experimental-features 'nix-command flakes' develop .#coding-agent
```

Then run normal development commands inside that shell:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets --all-features
nix run .#check
```

The important change is dependency ownership. Instead of asking each developer to install Rust, shellcheck, shfmt, Bats, jq, and other check tools manually, the flake supplies them from `flake.lock`. Updating tool versions becomes a repository change instead of a hidden machine setup step.

To preload the current Linux package outputs and all named shells on a machine:

```bash
nix --extra-experimental-features 'nix-command flakes' build .#default .#check .#e2e
nix --extra-experimental-features 'nix-command flakes' develop .#minimal --command true
nix --extra-experimental-features 'nix-command flakes' develop .#coding-agent --command true
nix --extra-experimental-features 'nix-command flakes' develop .#factory --command true
nix --extra-experimental-features 'nix-command flakes' develop .#security --command true
```

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
nix --extra-experimental-features 'nix-command flakes' profile add github:hghalebi/agentic-workstation
agentic-workstation plan --profile coding-agent --json
```

Use this when you only need the typed CLI. Use `./install-agentic-tools.sh` for full Ubuntu workstation setup.

## OpenClaw

Use Nix to inspect, validate, and develop the OpenClaw server profile reproducibly:

```bash
nix --extra-experimental-features 'nix-command flakes' run .#plan -- --profile openclaw-server
nix --extra-experimental-features 'nix-command flakes' run .#doctor -- --profile openclaw-server
nix --extra-experimental-features 'nix-command flakes' develop .#factory
```

Use the Bash installer when you want to run OpenClaw on the machine:

```bash
sudo ./install-agentic-tools.sh --profile openclaw-server
```

That boundary is intentional. Nix supplies reproducible development tools and validation commands. The `openclaw-server` installer profile still owns privileged machine changes such as Docker setup, `/opt/openclaw` layout, service files, secrets templates, and server-side filesystem permissions.

The current flake does not package or launch the OpenClaw service itself. If the `openclaw` CLI or daemon is needed on a host, install it through the `openclaw-server` profile until a dedicated Nix package is added.

## Local Shortcuts

```bash
just nix-check
just nix-e2e
just nix-shell coding-agent
```

These commands wrap the same flake apps used by CI.

## Boundary

Nix owns reproducible development inputs, CLI packaging, and repository validation. The Bash installer still owns privileged machine mutation: apt packages, shell configuration, system services, manifests, and optional workspace hydration.
