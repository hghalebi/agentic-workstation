# Agent Runner

`agent-runner` is the headless profile for autonomous coding agents.

Install:

```bash
./install-agentic-tools.sh --profile agent-runner
```

Hydrate a workspace:

```bash
WORKSPACE_REPO=git@github.com:org/project.git \
WORKSPACE_REF=main \
WORKSPACE_TARGET=/workspace/project \
./install-agentic-tools.sh --profile agent-runner
```

Optional systemd service files live in `systemd/`.

Install them manually when you are ready to run an agent as a service:

```bash
sudo install -m 0644 systemd/agentic-runner@.service /etc/systemd/system/
sudo install -m 0644 systemd/agentic-runner.env.example /etc/agentic-workstation/runner.env
sudo install -m 0755 scripts/agent-runner-start.sh /usr/local/bin/agentic-runner-start
sudo systemctl daemon-reload
```

Check status and logs:

```bash
./scripts/agent-runner-status.sh project
./scripts/agent-runner-logs.sh project
```

The service does not perform authentication and does not write secrets.
