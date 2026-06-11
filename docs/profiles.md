# Profiles

Profiles are environment files in `profiles/*.env`. They turn installer modules on or off.

Use a profile:

```bash
./install-agentic-tools.sh --profile coding-agent
```

Resume a failed profile install:

```bash
./install-agentic-tools.sh --profile factory --resume
```

Run or skip a module:

```bash
./install-agentic-tools.sh --only agents
./install-agentic-tools.sh --skip browser
```

Inspect a plan before install:

```bash
./install-agentic-tools.sh --profile coding-agent --plan
./install-agentic-tools.sh --profile coding-agent --json-plan | jq .
cargo run -- plan --profile coding-agent --json | jq .
```

## Available Profiles

| Profile | Use case | Notes |
| --- | --- | --- |
| `minimal` | Small reusable VM. | Core OS tools, runtimes, version managers, Git helpers, 1Password CLI. |
| `base-image` | Snapshot source image. | Similar to `minimal`, intended for provider snapshots. |
| `coding-agent` | Default interactive agent workstation. | Agent CLIs, browser helpers, cloud CLIs, terminal tools, Harness. |
| `human-dev` | Larger human-operated development machine. | `coding-agent` plus factory and security tooling. |
| `agent-runner` | Lean autonomous runtime. | Agent CLIs and cloud CLIs without shell decoration or browser tools. |
| `factory` | Full software-factory environment. | Agent, cloud, artifact, security, tracing, and terminal tools. |
| `security` | Security review and supply-chain analysis. | Factory/security tools without agent CLIs. |
| `local-llm` | Local model runtime. | Agent CLIs plus factory tooling and Ollama. |
| `openclaw-server` | OpenClaw server host. | Server base, official Docker Engine, Rust server tools, OpenTelemetry Collector compose files, Neon and Hetzner S3 helpers, 1Password SSH helper, and optional dotfiles clone. |

## Modules

The installer currently exposes these module names:

| Module | Purpose |
| --- | --- |
| `base` | apt packages and core shell/debug tools. |
| `server-base` | `ufw`, `fail2ban`, `nginx`, `unattended-upgrades`, and journald limits. |
| `docker` | Docker Engine via Docker's official Ubuntu apt repository. |
| `runtimes` | Rust and uv. |
| `rust-server-tools` | `sqlx-cli`, `cargo-nextest`, and `cargo-watch`. |
| `version-managers` | mise and aqua. |
| `git-helpers` | yq and delta. |
| `agents` | npm and Python agent CLIs. |
| `browser` | Playwright browser binaries. |
| `cloud` | hcloud and gcloud. |
| `terminal` | zellij. |
| `factory` | factory, security, tracing, and local-model tools when enabled by profile. |
| `onepassword` | 1Password CLI. |
| `harness` | Harness CLI. |
| `openclaw-layout` | `/opt/openclaw/{app,tools,repos,otel,secrets,backups,logs}`. |
| `opentelemetry` | OpenTelemetry Collector Docker Compose file and collector config. |
| `neon` | `postgresql-client`, `sqlx-cli`, and `/opt/openclaw/app/.env.example`. |
| `hetzner-s3` | `awscli`, Hetzner S3 env template, and bucket check script. |
| `onepassword-ssh` | Helper script to export a 1Password SSH public key and configure SSH. |
| `dotfiles` | Optional dotfiles clone; installer hooks run only when explicitly enabled. |
| `workspace` | local copy and Git workspace hydration. |
| `config` | shell, Git, and hook configuration. |
| `manifest` | `/var/lib/agentic-workstation/manifest.json`. |

## OpenClaw Server

The `openclaw-server` profile is intended for an Ubuntu server that runs OpenClaw services without installing a local Postgres server:

```bash
./install-agentic-tools.sh --profile openclaw-server
./scripts/doctor.sh --profile openclaw-server
```

Docker is installed through Docker's official apt repository with `docker-ce`, `docker-ce-cli`, `containerd.io`, Buildx, and the Docker Compose plugin.

OpenTelemetry is configured as a Docker Compose stack under `/opt/openclaw/otel`. The default collector config accepts OTLP on ports `4317` and `4318` and exports to the collector debug exporter until a production backend is added.

Neon support uses normal Postgres connection strings. The profile installs `postgresql-client` and `sqlx-cli`, then writes `/opt/openclaw/app/.env.example` for `DATABASE_URL` and Postgres environment keys.

Hetzner S3 support installs `awscli`, writes `/opt/openclaw/secrets/hetzner-s3.env.example`, and provides `/opt/openclaw/tools/check-hetzner-s3-bucket.sh`.

The profile clones `https://github.com/hghalebi/dotfiles` into `/root/.dotfiles`. It does not run a dotfiles installer unless `DOTFILES_RUN_INSTALL=1` is set.

Module metadata lives in `modules.yaml`.

## Profile Compatibility Flags

These legacy environment flags still work:

```bash
INCLUDE_FACTORY_TOOLS=1
INCLUDE_LOCAL_MODEL_RUNTIME=1
SKIP_BROWSER_TOOLS=1
SKIP_AUTO_CONFIG=1
```

Prefer profiles for new automation.
