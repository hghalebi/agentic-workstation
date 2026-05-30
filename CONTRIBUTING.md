# Contributing

Contributions are welcome if they keep the installer practical, auditable, and safe to rerun.

## Development

Validate shell syntax:

```bash
bash -n install-agentic-tools.sh
```

Run ShellCheck when available:

```bash
shellcheck install-agentic-tools.sh
```

Run the installer in a disposable Ubuntu VM or container before proposing install changes.

## Guidelines

- Prefer official vendor install commands and link the source in `commands.md`.
- Keep destructive or daemon-level installs opt-in.
- Make install steps idempotent when practical.
- Do not automate auth flows or write secrets into files.
- Avoid hardcoded personal paths, tokens, account IDs, or organization names.
- Update `README.md`, `commands.md`, and `CHANGELOG.md` for user-facing changes.

## Pull Requests

Include:

- What tool or behavior changed.
- Why it belongs in the default layer or factory layer.
- How you tested it.
- Any known platform limitations.
