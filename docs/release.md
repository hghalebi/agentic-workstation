# Release Checklist

Use this checklist before tagging a release.

## 1. Validate Locally

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets --all-features
cargo run -- verify-lockfile
PRE_COMMIT_HOME=/tmp/pre-commit-cache pre-commit run --all-files
gitleaks detect --source . --no-git --redact --verbose
./scripts/verify-lockfile.sh
./scripts/audit-remote-installers.sh
```

## 2. Validate with Nix

```bash
nix --extra-experimental-features 'nix-command flakes' build
nix --extra-experimental-features 'nix-command flakes' run .#check
nix --extra-experimental-features 'nix-command flakes' flake check --no-build
```

## 3. Inspect Plans

```bash
./install-agentic-tools.sh --profile coding-agent --json-plan | jq .
./install-agentic-tools.sh --profile factory --json-plan | jq .
```

## 4. Build Docker Smoke Tests

```bash
docker build -f tests/Dockerfile.ubuntu-22.04 .
docker build -f tests/Dockerfile.ubuntu-24.04 .
```

## 5. Tag

Confirm GitHub Actions are green, then create an annotated tag:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

## 6. Publish Notes

Include:

- Supported profiles.
- Manifest schema changes.
- Known remote installer exceptions.
- Checksums or SBOM artifacts when available.
