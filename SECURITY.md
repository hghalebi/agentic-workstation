# Security Policy

## Reporting

Do not open a public issue for secrets, credential exposure, or installer command-injection concerns.

Until a dedicated security contact exists, report privately to the repository maintainer. Include:

- Affected file and command.
- Impact.
- Reproduction steps.
- Suggested fix, if available.

## Scope

Security-sensitive areas include:

- Remote installer commands.
- Shell quoting and environment-variable handling.
- Privileged writes to `/usr/local/bin`, `/usr/share/keyrings`, and apt source lists.
- Secret-management and auth instructions.

## Secrets

The installer must not collect, store, print, or transmit credentials. Auth commands belong in documentation only.
