# Use Cases

## Solo Technical Founder

Use `coding-agent` for an interactive AI development VM.

```bash
./install-agentic-tools.sh --profile coding-agent
```

## Agent Runner Fleet

Use `base-image` for snapshots, then `agent-runner` for headless machines.

```bash
./install-agentic-tools.sh --profile base-image --resume
./scripts/prepare-snapshot.sh
```

## Security Review

Use `security` for disposable supply-chain and static-analysis work.

```bash
./install-agentic-tools.sh --profile security
```

## Full Factory

Use `factory` when a machine needs artifact extraction, model/data helpers, security scanners, browser tooling, and agent CLIs.

```bash
./install-agentic-tools.sh --profile factory
```

## Local Model Workstation

Use `local-llm` when Ollama and model/data tooling are needed.

```bash
./install-agentic-tools.sh --profile local-llm
```
