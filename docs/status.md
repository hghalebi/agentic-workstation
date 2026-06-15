# Status

This page tracks the reliability targets for the installer, planner, and image workflows.

## Targets

| Metric | Target | Current |
| --- | --- | --- |
| Fresh minimal install success | 100% in CI | Planned Docker install job |
| Fresh agent-runner install success | 100% in CI | Planned Docker install job |
| Heavy factory install success | Nightly tracked | Planned nightly |
| Unpinned external installs | Trending to 0 | Installer package commands consume lockfile pins; remote scripts remain documented exceptions |
| Remote installers documented | 100% | `docs/remote-installers.md` |
| Manifest schema coverage | 100% of installed modules | Initial manifest present |
| Doctor JSON support | Yes | Implemented |
| Typed read-only planner | Yes | Rust CLI matches Bash `--json-plan` for checked-in profiles |
| Nix package build | Yes | `nix build`, `.#check`, named dev shells, and `.#e2e` are covered by CI |
| Packer image verification | Yes | Planned |
| OpenSSF Scorecard | Published | Workflow added |
| First tagged release | `v0.1.0` | Released |
| Latest release | `v0.1.1` | Current |

## Update Rules

- Update this page when a target changes.
- Keep `Current` factual and testable.
- Link to the command, workflow, or document that proves the status when the table needs more detail.
