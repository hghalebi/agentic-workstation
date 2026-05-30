# Profiles

Profiles choose which workstation layers to install.

Use:

```bash
./install-agentic-tools.sh --profile coding-agent
```

Profiles:

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

Resume a failed install:

```bash
./install-agentic-tools.sh --profile factory --resume
```

Run one module:

```bash
./install-agentic-tools.sh --only agents
```

Skip one module:

```bash
./install-agentic-tools.sh --skip browser
```
