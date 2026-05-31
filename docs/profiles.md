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

## Modules

The installer currently exposes these module names:

| Module | Purpose |
| --- | --- |
| `base` | apt packages and core shell/debug tools. |
| `runtimes` | Rust and uv. |
| `version-managers` | mise and aqua. |
| `git-helpers` | yq and delta. |
| `agents` | npm and Python agent CLIs. |
| `browser` | Playwright browser binaries. |
| `cloud` | hcloud and gcloud. |
| `terminal` | zellij. |
| `factory` | factory, security, tracing, and local-model tools when enabled by profile. |
| `onepassword` | 1Password CLI. |
| `harness` | Harness CLI. |
| `workspace` | local copy and Git workspace hydration. |
| `config` | shell, Git, and hook configuration. |
| `manifest` | `/var/lib/agentic-workstation/manifest.json`. |

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
