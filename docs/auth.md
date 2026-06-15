# Authentication

The installer does not automate login flows or write secrets.

## Log In

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

Run only the commands for tools you use. Most CLIs store credentials in their own standard locations.

## Check Status

```bash
./scripts/auth-status.sh
./scripts/auth-status.sh --json
```

## Output

Human output uses:

| Status | Meaning |
| --- | --- |
| `ok` | The tool is installed and appears authenticated. |
| `missing` | The tool is missing or not authenticated. |

The human output also prints the next login command for missing checks. JSON output is intended for scripts and CI jobs.

## Security Notes

- Do not put tokens in profile files, cloud-init files, or manifests.
- Do not commit generated auth config.
- Prefer each vendor CLI's normal login flow.
