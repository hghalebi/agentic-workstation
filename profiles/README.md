# Profiles

Profiles are shell environment files consumed by `install-agentic-tools.sh`.

Use:

```bash
./install-agentic-tools.sh --profile coding-agent
./install-agentic-tools.sh --profile factory
./install-agentic-tools.sh --profile agent-runner
```

Available profiles:

- `minimal`: small reusable workstation.
- `base-image`: snapshot base image.
- `coding-agent`: default interactive agent workstation.
- `human-dev`: larger human development workstation.
- `agent-runner`: lean autonomous agent runtime.
- `factory`: full software-factory profile.
- `security`: security review tooling.
- `local-llm`: local model runtime profile.
