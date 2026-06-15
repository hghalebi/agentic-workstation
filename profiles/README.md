# Profile Files

Each `*.env` file sets installer booleans consumed by `install-agentic-tools.sh`.

## Use a Profile

```bash
./install-agentic-tools.sh --profile agent-runner
```

The installer sources `profiles/<name>.env`, applies compatibility overrides such as `SKIP_BROWSER_TOOLS=1`, then runs the enabled modules.

## Authoring Rules

- Use `0` or `1` values.
- Do not run commands.
- Do not include secrets.
- Keep profile intent documented in `docs/profiles.md`.

## Verify

```bash
./install-agentic-tools.sh --profile agent-runner --json-plan | jq .
./scripts/doctor.sh --profile agent-runner
```
