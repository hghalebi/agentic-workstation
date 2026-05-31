# Security

Report security issues privately.

Do not open a public issue for:

- Secrets or credential exposure.
- Command injection.
- Unsafe remote installer usage.
- Privileged write problems.
- Auth-flow or secret-management bugs.

Until a dedicated security contact exists, report privately to the repository maintainer.

Include:

- Affected file and command.
- Impact.
- Reproduction steps.
- Suggested fix, if available.

## Scope

Security-sensitive areas:

- Remote installer commands.
- Lockfile policy in `agentic-tools.lock.yaml`.
- Module metadata in `modules.yaml`.
- Shell quoting and environment-variable handling.
- Writes to `/usr/local/bin`, `/usr/share/keyrings`, and apt source lists.
- Secret-management instructions.
- Auth instructions.
- Auto-configuration that mutates shell, Git, SSH, or tool config.
- Cloud-init user-data and snapshot cleanup.
- Manifest generation under `/var/lib/agentic-workstation`.

## Secret Handling

The installer must not collect, store, print, or transmit credentials.

Auth commands belong in documentation only. Use `op`, `gh`, cloud CLIs, and model CLIs through their own login flows.

## Supply Chain

Run:

```bash
./scripts/verify-lockfile.sh
./scripts/audit-remote-installers.sh
```

Every remote installer should be documented in `agentic-tools.lock.yaml` or removed. Prefer pinned package versions and reproducible image refs over moving `main` branches or `latest` package targets.
