# Remote Installer Audit

Some tools are installed through vendor-hosted scripts or direct release downloads. These are security-sensitive because they execute code fetched at install time.

Run:

```bash
./scripts/audit-remote-installers.sh
./scripts/verify-lockfile.sh
cargo run -- verify-lockfile
```

Current policy:

- Prefer apt packages, pinned npm versions, pinned uv versions, pinned Go versions, pinned Cargo versions, or aqua-managed releases.
- Installer package commands must read pinned versions from `agentic-tools.lock.yaml`.
- Remote shell installers require a documented exception in `agentic-tools.lock.yaml`.
- Remote downloads should use checksums when vendors provide a stable artifact.
- Default release installs should not use `@latest`; use `ALLOW_LATEST=1` only when explicitly accepting moving targets.
- The Rust validator is the typed lockfile policy boundary. The shell verifier delegates to it when the compiled CLI is available.

Known documented exceptions are tracked in `agentic-tools.lock.yaml` under `remote_installers`.
