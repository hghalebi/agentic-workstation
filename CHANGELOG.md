# Changelog

## Unreleased

- Nothing yet.

## v0.1.1 - 2026-06-12

- Added a typed Rust CLI for read-only install planning and lockfile validation.
- Added Nix flake packaging for the Rust CLI and kept `.#check` for the shell/static validation graph.
- Enforced `agentic-tools.lock.yaml` pins from installer package commands instead of using the lockfile only as documentation.
- Pinned previously moving npm, uv, pip, Go, Cargo, and Hadolint install targets.
- Added installer `--dry-run`, `--plan`, and `--json-plan`.
- Added `modules.yaml`, `agentic-tools.lock.yaml`, lockfile verification, and remote installer audit tooling.
- Added JSON output for `scripts/doctor.sh` and expanded auth readiness reporting.
- Added cloud-init rendering, agent-runner service scaffolding, devcontainer support, issue templates, security workflow, Bats tests, and Docker 22.04 smoke test.
- Added architecture, use-case, threat-model, remote-installer, status, and agent-runner docs.
- Added profile-based installation with `--profile`, `--only`, `--skip`, and `--resume`.
- Added install markers and `/var/lib/agentic-workstation/manifest.json`.
- Added workspace Git hydration through `WORKSPACE_REPO`, `WORKSPACE_REF`, and `WORKSPACE_TARGET`.
- Added `scripts/doctor.sh`, `scripts/auth-status.sh`, `scripts/prepare-snapshot.sh`, and module wrapper scripts.
- Added cloud-init, Hetzner VM creation helper, Packer stubs, Docker smoke test, and `justfile`.
- Added `profiles/`, `config/mise.toml`, and `config/aqua.yaml`.
- Added docs for profiles, auth, and VM lifecycle.
- Added `mise`, `aqua`, `yq`, `delta`, `pre-commit`, `shfmt`, `bats`, diagnostics, and disk inspection tools.
- Added factory-layer supply-chain tooling: Syft, Grype, Cosign, Trivy, Hadolint, `bpftrace`, and `perf`.
- Added low-risk auto-configuration with `SKIP_AUTO_CONFIG=1`.
- Added local pre-commit hooks.
- Added `ROADMAP.md` for planned opt-in configuration.
- Added open-source project metadata and policies.
- Added the default installer for agentic coding CLIs, cloud/database CLIs, terminal workspace tools, 1Password CLI, Harness CLI, and Google tooling.
- Added the optional factory layer for artifact extraction, security scanning, DVC, Hugging Face CLI, DeepAgents, Task, Just, and Gitleaks.
- Documented heavier optional tooling such as Docker, Kubernetes, Terraform/OpenTofu, AWS CLI, Azure CLI, Trivy, and Ollama.
