# Release Pipeline

Releases are managed by Google's Release Please action.

## Automated Flow

When commits land on `main`, `.github/workflows/release-please.yml` runs `googleapis/release-please-action@v4`.

The workflow reads:

- `release-please-config.json` for release strategy.
- `.release-please-manifest.json` for the current released version.
- Conventional Commit messages since the latest release tag.

Release Please opens or updates a release PR. That PR updates `CHANGELOG.md`, bumps the Rust package version, and updates the release manifest. When the release PR is merged, Release Please creates the GitHub release and tag.

Use Conventional Commit prefixes so the release pipeline can classify changes:

```text
fix: repair installer dependency resolution
feat: add Nix e2e bootstrap smoke
docs: explain OpenClaw Nix boundary
chore: refresh release pipeline
```

Breaking changes use `!` or a `BREAKING CHANGE:` footer:

```text
feat!: change profile manifest schema
```

## Manual Pre-release Checks

Run these checks before merging a release PR or a large feature PR.

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
nix --extra-experimental-features 'nix-command flakes' run .#e2e
nix --extra-experimental-features 'nix-command flakes' flake check --no-build
nix --extra-experimental-features 'nix-command flakes' develop .#coding-agent --command true
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

## 5. Merge the Release PR

Confirm GitHub Actions are green, then merge the Release Please PR. Do not manually create a tag for the normal release path.

## 6. Verify Release Notes

Include:

- Supported profiles.
- Manifest schema changes.
- Known remote installer exceptions.
- Checksums or SBOM artifacts when available.
