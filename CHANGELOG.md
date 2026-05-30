# Changelog

## Unreleased

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
