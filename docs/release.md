# Release Checklist

Before tagging a release:

1. Run local validation.

   ```bash
   PRE_COMMIT_HOME=/tmp/pre-commit-cache pre-commit run --all-files
   gitleaks detect --source . --no-git --redact --verbose
   ./scripts/verify-lockfile.sh
   ./scripts/audit-remote-installers.sh
   ```

2. Render and inspect install plans.

   ```bash
   ./install-agentic-tools.sh --profile coding-agent --json-plan | jq .
   ./install-agentic-tools.sh --profile factory --json-plan | jq .
   ```

3. Build Docker smoke tests.

   ```bash
   docker build -f tests/Dockerfile.ubuntu-22.04 .
   docker build -f tests/Dockerfile.ubuntu-24.04 .
   ```

4. Confirm GitHub Actions are green.

5. Create an annotated tag.

   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```

6. Publish release notes with:

   - Supported profiles.
   - Manifest schema changes.
   - Known remote installer exceptions.
   - Checksums or SBOM artifacts when available.
