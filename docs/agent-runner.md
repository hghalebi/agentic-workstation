# Agent Runner

Use the `agent-runner` profile for headless coding-agent machines. It installs the agent CLIs and cloud tooling without browser binaries or interactive shell decoration.

## Install

```bash
./install-agentic-tools.sh --profile agent-runner
```

## Hydrate a Workspace

```bash
WORKSPACE_REPO=git@github.com:org/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

Set `WORKSPACE_REF` to a branch, tag, or commit. Use a tag or commit for repeatable runner images.

## Run as a Service

Optional systemd service files live in `systemd/`. Install them when the runner host is ready:

```bash
sudo install -m 0644 systemd/agentic-runner@.service /etc/systemd/system/
sudo install -m 0644 systemd/agentic-runner.env.example /etc/agentic-workstation/runner.env
sudo install -m 0755 scripts/agent-runner-start.sh /usr/local/bin/agentic-runner-start
sudo systemctl daemon-reload
```

## Inspect

```bash
./scripts/agent-runner-status.sh project
./scripts/agent-runner-logs.sh project
```

## Security Notes

- The service does not authenticate tools.
- The service does not write secrets.
- Run `./scripts/auth-status.sh` before starting long-running agent work.
