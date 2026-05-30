# Authentication

The installer does not automate login flows or write secrets.

Run the commands for the tools you use:

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

Check status:

```bash
./scripts/auth-status.sh
```

Expected output uses `ok` for available authenticated tools and `missing` for tools that are not installed or not authenticated.
