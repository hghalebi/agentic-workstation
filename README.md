# Agentic Workstation

Install a practical Ubuntu workstation for agentic software development.

The installer is a single Bash script. It installs coding agents, model CLIs, cloud/database CLIs, shell tooling, debuggers, security scanners, and documentation/artifact tools. It also applies a small set of reversible local defaults.

## Requirements

- Ubuntu Linux on `amd64`.
- A root shell or a user with `sudo`.
- Network access to apt, npm, PyPI/uv, Go modules, Cargo, and vendor release endpoints.

Other Linux distributions may work, but Ubuntu is the supported target.

## Install

Clone the repository:

```bash
git clone https://github.com/hghalebi/agentic-workstation.git
cd agentic-workstation
```

Run the default installer:

```bash
./install-agentic-tools.sh
```

From a non-root shell:

```bash
sudo ./install-agentic-tools.sh
```

## Options

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
- Docker, Kubernetes, Terraform/OpenTofu, AWS CLI, and Azure CLI are documented but not installed by default.
- Some tools use official remote install scripts. See [commands.md](commands.md) for the exact commands and source links.

## Validate Changes

Run:

```bash
bash -n install-agentic-tools.sh
shellcheck install-agentic-tools.sh
shfmt -i 2 -ci -d install-agentic-tools.sh
pre-commit run --all-files
```

## Docs

- [commands.md](commands.md): install commands and source links.
- [ROADMAP.md](ROADMAP.md): planned opt-in configuration.
- [CONTRIBUTING.md](CONTRIBUTING.md): contribution workflow.
- [SECURITY.md](SECURITY.md): vulnerability reporting.
- [CHANGELOG.md](CHANGELOG.md): release history.

## License

MIT. See [LICENSE](LICENSE).
