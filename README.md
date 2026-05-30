# Agentic Workstation

Agentic Workstation is a non-interactive Ubuntu setup script for installing the CLI tools commonly used to build, operate, and debug agentic software systems.

It focuses on coding agents, model CLIs, cloud/database CLIs, secret management, code search, terminal workspaces, static analysis, artifact extraction, and optional software-factory tooling.

## Supported Platform

- Ubuntu Linux on `amd64`.
- Root or sudo-capable user.
- Network access to apt repositories, npm, PyPI/uv, Go modules, Cargo, and vendor download endpoints.

Other Linux distributions may work after adapting package-manager commands, but they are not the current target.

## Quick Start

```bash
git clone git@github.com:hghalebi/agentic-workstation.git
cd agentic-workstation
./install-agentic-tools.sh
```

If running as a non-root user:

```bash
sudo ./install-agentic-tools.sh
```

## Install Modes

Default install:

```bash
./install-agentic-tools.sh
```

Skip Playwright browser binaries:

```bash
SKIP_BROWSER_TOOLS=1 ./install-agentic-tools.sh
```

Install the broader software-factory helper layer:

```bash
INCLUDE_FACTORY_TOOLS=1 ./install-agentic-tools.sh
```

Install the factory layer plus Ollama local model runtime:

```bash
INCLUDE_FACTORY_TOOLS=1 INCLUDE_LOCAL_MODEL_RUNTIME=1 ./install-agentic-tools.sh
```

Optionally migrate a local workspace directory:

```bash
WORKSPACE_SOURCE=/path/to/workspace ./install-agentic-tools.sh
```

Set an explicit target if needed:

```bash
WORKSPACE_SOURCE=/path/to/workspace WORKSPACE_TARGET="$HOME/workspace" ./install-agentic-tools.sh
```

## What It Installs

Default layer:

- Core tools: `git`, `gh`, `curl`, `wget`, `jq`, `rg`, `fd`, `fzf`, `tmux`, `zellij`, `direnv`, `make`, compilers, `unzip`, `python3`, `pipx`, `node`, `npm`, `npx`, `go`.
- Code intelligence helpers: `shellcheck`, `sqlite3`, `psql`, `redis-cli`, `dig`, `nc`, `git-lfs`, `age`, `tree`, `rsync`.
- Rust and Python tooling: `rustup`, `rustc`, `cargo`, `uv`, `uvx`.
- AI coding tools: `codex`, `claude`, `gemini`, `copilot`, `opencode`, `openclaw`, `openhands`, `aider`, `llm`, `codeagents`.
- Cloud and database CLIs: `gcloud`, `hcloud`, `neonctl`.
- Google Workspace/App Script: `gws`, `clasp`.
- Secret management: `op` from 1Password CLI.
- MCP and browser helpers: `@modelcontextprotocol/inspector`, `playwright`.
- Harness: `hc` Harness CLI v1.

Factory layer:

- Build/task orchestration: `task`, `just`.
- Artifact and research extraction: `pandoc`, `poppler-utils`, `ffmpeg`, ImageMagick, Tesseract, `httpie`.
- Security/static analysis: `semgrep`, `snyk`, `gitleaks`.
- Agent/data/model helpers: `deepagents`, `dvc`, `hf`.
- Optional local model runtime: `ollama`.

## Post-Install Auth

Authentication is intentionally not automated because it requires account credentials, browser/device flows, or secrets.

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

## Notes

- Docker, Kubernetes, cloud, and security tools can alter host networking, install daemons, require privileged groups, or need paid accounts. Heavy daemon-based tools are documented in [commands.md](commands.md) instead of installed by default.
- Playwright may not provide browser binaries for the newest Ubuntu releases immediately. The installer logs a warning and continues if Chromium install is unsupported.
- The script is designed to be rerunnable. Some vendor installers may still update existing tools.

## Documentation

- [commands.md](commands.md): direct install commands and source links.
- [CONTRIBUTING.md](CONTRIBUTING.md): contribution workflow.
- [SECURITY.md](SECURITY.md): vulnerability reporting.
- [CHANGELOG.md](CHANGELOG.md): release history.

## License

MIT. See [LICENSE](LICENSE).
