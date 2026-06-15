# Use Cases

Choose the smallest profile that matches the machine's job. Smaller profiles install faster, snapshot better, and reduce credential and daemon surface area.

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

Then run the runner layer on each new VM:

```bash
./install-agentic-tools.sh --profile agent-runner --resume
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

## OpenClaw Server

Use `openclaw-server` for an Ubuntu host that needs Docker, OpenTelemetry Collector files, Neon helpers, Hetzner S3 helpers, and server hardening tools.

```bash
./install-agentic-tools.sh --profile openclaw-server
./scripts/doctor.sh --profile openclaw-server
```
