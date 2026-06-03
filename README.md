# Agentic Workstation

[![CI](https://github.com/hghalebi/agentic-workstation/actions/workflows/ci.yml/badge.svg)](https://github.com/hghalebi/agentic-workstation/actions/workflows/ci.yml)
[![Security](https://github.com/hghalebi/agentic-workstation/actions/workflows/security.yml/badge.svg)](https://github.com/hghalebi/agentic-workstation/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/ubuntu-22.04%20%7C%2024.04-orange.svg)](tests)

Build repeatable Ubuntu workstations for agentic software development.

The repo is a layered workstation factory:

```text
base image -> cloud-init -> profile install -> workspace hydration -> health checks
```

The Bash installer still works as the main entrypoint. Profiles, helper scripts, cloud-init, manifests, and snapshot cleanup make it usable across many VMs.

## Who This Is For

- Solo technical founders who want a fresh AI coding VM in minutes.
- Teams that need reproducible agent-runner machines.
- Security reviewers who need disposable supply-chain-analysis boxes.
- Platform engineers building golden images for AI-native development.

## What This Is Not

- Not a dotfiles manager.
- Not a secrets manager.
- Not a Kubernetes or Docker mega-bootstrapper by default.
- Not a replacement for devcontainers, Nix, or Packer. It can complement them.

## Requirements

- Ubuntu Linux on `amd64`.
- A root shell or a user with `sudo`.
- Network access to apt, npm, PyPI/uv, Go modules, Cargo, and vendor release endpoints.
- For first bootstrap, either `git` or `curl`/`wget` plus `tar`.

Other Linux distributions may work, but Ubuntu is the supported target.

## Install

On a fresh machine without Git installed yet, bootstrap from a GitHub archive:

```bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh | bash
```

Choose a profile without cloning first:

```bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh \
  | bash -s -- --profile minimal
```

Keep a local copy of the repo scripts without Git:

```bash
curl -fsSL https://raw.githubusercontent.com/hghalebi/agentic-workstation/main/scripts/bootstrap.sh \
  | bash -s -- --dir "$HOME/agentic-workstation"
```

Clone the repository:

```bash
git clone https://github.com/hghalebi/agentic-workstation.git
cd agentic-workstation
```

Run the default `coding-agent` profile:

```bash
./install-agentic-tools.sh
```

From a non-root shell:

```bash
sudo ./install-agentic-tools.sh
```

## Options

Install a named profile:

```bash
./install-agentic-tools.sh --profile minimal
./install-agentic-tools.sh --profile factory
./install-agentic-tools.sh --profile agent-runner
./install-agentic-tools.sh --profile openclaw-server
./scripts/install-openclaw-server.sh
```

Resume after a failed install:

```bash
./install-agentic-tools.sh --profile factory --resume
```

Run or skip specific modules:

```bash
./install-agentic-tools.sh --only agents
./install-agentic-tools.sh --skip browser
```

Inspect before mutating the machine:

```bash
./install-agentic-tools.sh --profile coding-agent --dry-run
./install-agentic-tools.sh --profile coding-agent --json-plan
```

Skip Playwright browser binaries:

```bash
SKIP_BROWSER_TOOLS=1 ./install-agentic-tools.sh
```

Install the factory layer:

```bash
INCLUDE_FACTORY_TOOLS=1 ./install-agentic-tools.sh
```

Install the factory layer and Ollama:

```bash
INCLUDE_FACTORY_TOOLS=1 INCLUDE_LOCAL_MODEL_RUNTIME=1 ./install-agentic-tools.sh
```

Install tools without shell, Git, or hook configuration:

```bash
SKIP_AUTO_CONFIG=1 ./install-agentic-tools.sh
```

Copy an existing workspace into the target machine:

```bash
WORKSPACE_SOURCE=/path/to/workspace ./install-agentic-tools.sh
```

Set the workspace destination:

```bash
WORKSPACE_SOURCE=/path/to/workspace WORKSPACE_TARGET="$HOME/workspace" ./install-agentic-tools.sh
```

Hydrate a Git workspace:

```bash
WORKSPACE_REPO=git@github.com:hghalebi/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

## Profiles

| Profile | Use case |
| --- | --- |
| `minimal` | Small reusable VM. |
| `base-image` | Snapshot source image. |
| `coding-agent` | Default interactive agent workstation. |
| `human-dev` | Larger human-operated development machine. |
| `agent-runner` | Lean autonomous agent runtime. |
| `factory` | Full software-factory environment. |
| `security` | Security review and supply-chain analysis. |
| `local-llm` | Local model runtime. |
| `openclaw-server` | OpenClaw server host with Docker, OpenTelemetry, Neon, Hetzner S3, and server hardening helpers. |

Decision tree:

| Need | Use |
| --- | --- |
| Normal AI development machine | `coding-agent` |
| Fast future VM boots | `base-image`, then snapshot |
| Autonomous agent machines | `agent-runner` |
| Security analysis | `security` |
| Every artifact and factory helper | `factory` |
| Ollama or local models | `local-llm` |
| OpenClaw server deployment base | `openclaw-server` |

## What Gets Installed

Default layer:

| Area | Tools |
| --- | --- |
| Core shell | `git`, `gh`, `curl`, `wget`, `jq`, `rg`, `fd`, `fzf`, `tmux`, `zellij`, `direnv`, `make`, `unzip`, `zip` |
| Build/runtime | compilers, `python3`, `pipx`, `node`, `npm`, `npx`, `go`, `rustup`, `rustc`, `cargo`, `uv`, `uvx` |
| Code quality | `shellcheck`, `shfmt`, `bats`, `pre-commit` |
| Data and services | `sqlite3`, `psql`, `redis-cli`, `dig`, `nc` |
| Debugging | `lsof`, `strace`, `ltrace`, `hyperfine`, `ncdu`, `duf` |
| Version managers | `mise`, `aqua` |
| Git/YAML | `delta`, `yq`, `git-lfs` |
| Secret management | `op` from 1Password CLI |
| Agent/model CLIs | `codex`, `claude`, `gemini`, `copilot`, `opencode`, `openclaw`, `openhands`, `aider`, `llm`, `codeagents` |
| Cloud/database | `gcloud`, `hcloud`, `neonctl`, `clasp`, `gws`, `hc` |
| Browser/MCP | `playwright`, `@modelcontextprotocol/inspector` |

Factory layer:

| Area | Tools |
| --- | --- |
| Task runners | `task`, `just` |
| Artifacts | `pandoc`, `poppler-utils`, `ffmpeg`, ImageMagick, Tesseract, `httpie` |
| Security | `semgrep`, `snyk`, `gitleaks`, `syft`, `grype`, `cosign`, `trivy`, `hadolint` |
| Tracing | `bpftrace`, `perf` |
| Data/model | `deepagents`, `dvc`, `hf` |
| Local models | `ollama`, when `INCLUDE_LOCAL_MODEL_RUNTIME=1` |

OpenClaw server layer:

| Area | Tools |
| --- | --- |
| Server base | `ufw`, `fail2ban`, `nginx`, `unattended-upgrades`, journald limits |
| Docker | `docker-ce`, `docker-ce-cli`, `containerd.io`, Buildx, Docker Compose plugin via Docker's official apt repository |
| Rust server tools | `sqlx-cli`, `cargo-nextest`, `cargo-watch` |
| Layout | `/opt/openclaw/{app,tools,repos,otel,secrets,backups,logs}` |
| Observability | OpenTelemetry Collector compose file and config under `/opt/openclaw/otel` |
| Neon | `postgresql-client`, `sqlx-cli`, `/opt/openclaw/app/.env.example` |
| Hetzner S3 | `awscli`, env template, bucket check script |
| 1Password SSH | `/opt/openclaw/tools/op-ssh-helper` |
| Dotfiles | optional clone of `https://github.com/hghalebi/dotfiles`; installer execution is opt-in |

## Auto-Configuration

By default, the installer:

- Adds a marked PATH and `mise` activation block to `.profile` and `.bashrc`.
- Adds the same block to `.zshrc` when `.zshrc` already exists.
- Configures Git to use `delta` when no existing value is set for that Git key.
- Installs local pre-commit hooks when `.pre-commit-config.yaml` exists.

Disable this with:

```bash
SKIP_AUTO_CONFIG=1 ./install-agentic-tools.sh
```

Planned opt-in configuration is tracked in [ROADMAP.md](ROADMAP.md).

## Health and Manifests

Run health checks:

```bash
./scripts/doctor.sh --profile coding-agent
./scripts/doctor.sh --profile coding-agent --json
./scripts/doctor.sh --profile openclaw-server
```

Check authentication status without handling secrets:

```bash
./scripts/auth-status.sh
```

Each install writes:

```text
/var/lib/agentic-workstation/manifest.json
```

The manifest records the profile, install time, host, OS, and key tool versions.

Compare manifests:

```bash
./scripts/diff-manifest.sh expected.json /var/lib/agentic-workstation/manifest.json
```

## VM Factory Flow

Build a base image:

```bash
./install-agentic-tools.sh --profile base-image --resume
./scripts/prepare-snapshot.sh
```

Create a snapshot from that VM. Future VMs start from the snapshot and run only the profile layer they need:

```bash
./install-agentic-tools.sh --profile agent-runner --resume
```

For unattended provisioning, use:

```bash
./scripts/render-cloud-init.sh \
  --user ubuntu \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --profile agent-runner \
  --ref v0.1.0 \
  > cloud-init.agent-runner.yaml
```

Create a Hetzner VM, generate/register SSH keys, render cloud-init, and start
the profile install automatically:

```bash
HCLOUD_TOKEN=... ./scripts/agent-vm-new.sh --name repo-fix --profile agent-runner
```

For local smoke testing, use:

```bash
docker build -f tests/Dockerfile.ubuntu-24.04 .
```

## Authenticate Tools

The installer does not automate auth. Run only the commands for services you use:

```bash
gh auth login
copilot auth login
codex --login
claude auth login
gemini auth login
op account add
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
hcloud context create default
neonctl auth
clasp login --no-localhost
gws auth setup
gws auth login
hc auth login
openclaw onboard --install-daemon
llm keys set openai
hf auth login
```

## Safety Model

- The script is designed to be rerunnable.
- Auth flows stay out of the installer.
- Secrets are not collected, written, or printed.
- Docker is installed by the `openclaw-server` profile, but not by the default workstation profiles. Kubernetes, Terraform/OpenTofu, AWS CLI v2, and Azure CLI are documented but not installed by default.
- Some tools use official remote install scripts. See [commands.md](commands.md) for the exact commands and source links.
- Remote installers are audited in [docs/remote-installers.md](docs/remote-installers.md).
- Tool pinning policy starts in [agentic-tools.lock.yaml](agentic-tools.lock.yaml).

## Validate Changes

Run:

```bash
bash -n install-agentic-tools.sh scripts/*.sh cloud/*.sh
shellcheck install-agentic-tools.sh scripts/*.sh cloud/*.sh
shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh cloud/*.sh
pre-commit run --all-files
```

## Docs

- [commands.md](commands.md): install commands and source links.
- [docs/profiles.md](docs/profiles.md): profile behavior.
- [docs/auth.md](docs/auth.md): auth commands and status checks.
- [docs/vm-lifecycle.md](docs/vm-lifecycle.md): snapshots, cloud-init, and workspace hydration.
- [docs/hetzner-dx.md](docs/hetzner-dx.md): Hetzner-focused operator DX design.
- [docs/architecture.md](docs/architecture.md): factory architecture.
- [docs/use-cases.md](docs/use-cases.md): common use cases.
- [docs/threat-model.md](docs/threat-model.md): security model.
- [docs/remote-installers.md](docs/remote-installers.md): remote installer audit policy.
- [docs/status.md](docs/status.md): project health targets.
- [docs/agent-runner.md](docs/agent-runner.md): optional headless runner service.
- [docs/release.md](docs/release.md): release checklist.
- [ROADMAP.md](ROADMAP.md): planned opt-in configuration.
- [CONTRIBUTING.md](CONTRIBUTING.md): contribution workflow.
- [SECURITY.md](SECURITY.md): vulnerability reporting.
- [CHANGELOG.md](CHANGELOG.md): release history.

## License

MIT. See [LICENSE](LICENSE).
