# Contributing

Keep the installer practical, auditable, and safe to rerun.

## Develop

Run the local checks:

```bash
bash -n install-agentic-tools.sh
shellcheck install-agentic-tools.sh scripts/*.sh
shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets --all-features
cargo run -- verify-lockfile
pre-commit run --all-files
```

For installer changes, test in a disposable Ubuntu VM or container before opening a pull request.

```bash
docker build -f tests/Dockerfile.ubuntu-24.04 .
```

## Change Rules

- Prefer official vendor install commands.
- Link every non-apt install source in `commands.md`.
- Keep daemon-level or destructive tools opt-in.
- Make steps idempotent when practical.
- Keep read-only planning and lockfile policy in the Rust CLI when possible.
- Do not automate auth flows.
- Do not write credentials to disk.
- Do not add personal paths, account IDs, tokens, or organization names.
- Update `README.md`, `commands.md`, `docs/`, and `CHANGELOG.md` for user-facing changes.

## Pull Requests

Include:

- What changed.
- Why it belongs in the default layer or factory layer.
- How you tested it.
- Known platform limits or follow-up work.
