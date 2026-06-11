# Hetzner DX Design

This project should feel like a small Hetzner agent factory: create a machine,
hydrate a repo, run an agent, collect evidence, and delete the machine without
remembering provider details.

The current repo already has the right base pieces:

- `scripts/render-cloud-init.sh` renders first-boot user data.
- `cloud/hetzner-create-vm.sh` creates a Hetzner server.
- `images/packer-hcloud.pkr.hcl` builds a reusable Hetzner image.
- Profiles keep installs small and explicit.
- `doctor`, `auth-status`, and manifests make a VM auditable.

The DX goal is to wrap those pieces into clear operator flows, not replace them
with a large platform too early.

## Opinionated Defaults

Use these defaults unless a command overrides them:

| Setting | Default | Reason |
| --- | --- | --- |
| Provider | Hetzner Cloud | Current infra. |
| Region | `fsn1` | Existing script default. |
| Image | Ubuntu 24.04 or project snapshot | Matches supported target. |
| Base profile | `base-image` | Fast snapshot source. |
| Runner profile | `agent-runner` | Lean autonomous runtime. |
| Interactive profile | `coding-agent` | Human-operated development box. |
| Workspace root | `/workspace` | Existing runner convention. |
| Bootstrap ref | tag or commit | Reproducible cloud-init. |
| Secrets | never in cloud-init | Auth remains manual or reference based. |

## Golden Paths

### 1. First Setup

One command should validate local prerequisites without creating anything:

```bash
just hcloud-doctor
```

It should check:

- `hcloud` is installed.
- `HCLOUD_TOKEN` is available in the environment.
- The configured SSH key exists in Hetzner.
- The selected project ref is not `main` unless explicitly allowed.
- The local repo has no uncommitted changes when using a generated cloud-init ref.

### 2. Build Or Refresh The Base Snapshot

The snapshot path should be the preferred day-to-day flow because the repo
already treats VM startup time as a first-class concern.

```bash
just hcloud-image profile=base-image ref=v0.1.1
```

Desired behavior:

- Build with Packer against Hetzner.
- Install only the `base-image` profile.
- Run `scripts/prepare-snapshot.sh`.
- Name the image predictably, for example
  `agentic-base-ubuntu-24.04-<git-sha>`.
- Write image metadata to `state/hcloud/images/<name>.json`.

### 3. Create An Agent VM

The most common operation should not require remembering `hcloud` flags:

```bash
just agent-new name=repo-fix repo=git@github.com:org/project.git ref=main
```

The first implemented script for this flow is:

```bash
HCLOUD_TOKEN=... ./scripts/agent-vm-new.sh --name repo-fix --profile agent-runner
```

Desired behavior:

- Pick the latest known project snapshot if available.
- Fall back to Ubuntu 24.04 plus cloud-init when no snapshot exists.
- Render cloud-init into `state/hcloud/cloud-init/<name>.yaml`.
- Create the Hetzner server with labels:
  - `app=agentic-workstation`
  - `role=agent-runner`
  - `profile=agent-runner`
  - `owner=<local-user>`
  - `repo=<safe-repo-name>`
- Hydrate the workspace into `/workspace/<name>`.
- Print only the useful next commands: SSH, logs, status, destroy.

### 4. Connect To A VM

```bash
just agent-ssh name=repo-fix
```

Desired behavior:

- Resolve the server IP by label or state file.
- Use the configured SSH user.
- Refuse to connect if multiple matching servers exist unless `server_id` is
  provided.

### 5. Inspect Health

```bash
just agent-health name=repo-fix
```

Desired behavior:

- Run `doctor` remotely.
- Fetch `/var/lib/agentic-workstation/manifest.json`.
- Store it under `state/hcloud/manifests/<name>.json`.
- Show profile, image, repo, ref, and failed checks.

### 6. Collect Logs And Artifacts

```bash
just agent-pull name=repo-fix
```

Desired behavior:

- Pull the manifest.
- Pull selected logs from `/var/log/agentic-workstation`.
- Optionally pull `/workspace/<name>/artifacts`.
- Store output under `artifacts/hcloud/<name>/`.

### 7. Destroy A Disposable VM

```bash
just agent-destroy name=repo-fix
```

Desired behavior:

- Show server id, age, labels, public IP, and workspace repo before deletion.
- Require `CONFIRM=<name>` for non-interactive deletion.
- Leave local state and pulled artifacts intact.

## Command Shape

Prefer `just` as the human DX and small scripts as the implementation:

| Human command | Backing script |
| --- | --- |
| `just hcloud-doctor` | `scripts/hcloud-doctor.sh` |
| `just hcloud-render name=...` | `scripts/hcloud-render.sh` |
| `just hcloud-create name=...` | `cloud/hetzner-create-vm.sh` |
| `just agent-new name=...` | `scripts/agent-vm-new.sh` |
| `just agent-ssh name=...` | `scripts/agent-vm-ssh.sh` |
| `just agent-health name=...` | `scripts/agent-vm-health.sh` |
| `just agent-pull name=...` | `scripts/agent-vm-pull.sh` |
| `just agent-destroy name=...` | `scripts/agent-vm-destroy.sh` |

Keep scripts boring Bash. Use OpenTofu later only for long-lived fleets, not for
single disposable agent sessions.

## Local State Layout

Do not make the user search the Hetzner UI for routine operations.

```text
state/
  hcloud/
    servers/
      <name>.json
    cloud-init/
      <name>.yaml
    manifests/
      <name>.json
    images/
      <image-name>.json
artifacts/
  hcloud/
    <name>/
      manifest.json
      logs/
      workspace-artifacts/
```

Add `state/` and `artifacts/hcloud/` to `.gitignore`.

## Configuration

Use a single optional env file for local defaults:

```bash
.env.hcloud
```

Supported values:

```bash
HCLOUD_LOCATION=fsn1
HCLOUD_SERVER_TYPE=cx32
HCLOUD_IMAGE=ubuntu-24.04
HCLOUD_SSH_KEY=personal-laptop
AGENTIC_BOOTSTRAP_REF=v0.1.1
AGENTIC_HCLOUD_USER=ubuntu
AGENTIC_HCLOUD_LABEL_OWNER=hghalebi
```

Scripts should load `.env.hcloud` if present, then let explicit environment
variables override it.

## Isolation Model

Use layers:

1. Hetzner VM per trust boundary.
2. Unix user plus systemd slice per agent process.
3. Optional Incus or Podman runtime inside a VM for lower-cost multi-agent
   sessions.

Default recommendation for now:

- Use one Hetzner VM per important agent task.
- Add per-agent Unix users and systemd slices before introducing Incus.
- Add Incus only when you want several isolated Linux sessions inside one
  larger Hetzner server.

## Cost Controls

Add guardrails before adding more orchestration:

- Label every server created by this repo.
- Add `just hcloud-list` to show age, type, location, IP, and labels.
- Add `just hcloud-gc max_age=8h` for disposable runners.
- Never delete servers without the `app=agentic-workstation` label.
- Prefer snapshots for setup speed, but prune old snapshots by label.

## Security Controls

Cloud-init should stay secret-free:

- SSH public keys are allowed.
- Tokens, API keys, and 1Password session material are not allowed.
- Auth should happen after SSH or through documented external secret references.
- Rendered cloud-init files belong under ignored local `state/`.

Hetzner firewalls should become part of the create flow:

- Allow SSH only from configured operator CIDRs when provided.
- Allow no public inbound service ports by default.
- Record firewall id/name in the server state file.

## Implementation Order

1. Add `.env.hcloud` loading and state output to `cloud/hetzner-create-vm.sh`.
2. Add `just hcloud-doctor`, `hcloud-render`, `hcloud-create`, and
   `hcloud-list`.
3. Add `agent-new`, `agent-ssh`, `agent-health`, `agent-pull`, and
   `agent-destroy`.
4. Add labels to every Hetzner server and snapshot.
5. Add Packer snapshot naming and metadata output.
6. Add per-agent Unix users and a systemd slice.
7. Add optional Incus support for multiple agent sessions on one VM.
8. Add OpenTofu only after the script flow is stable and fleet state becomes
   painful to manage manually.

The near-term DX target is this:

```bash
just hcloud-doctor
just agent-new name=repo-fix repo=git@github.com:org/project.git ref=main
just agent-ssh name=repo-fix
just agent-health name=repo-fix
just agent-pull name=repo-fix
just agent-destroy name=repo-fix
```

That gives a fast, memorable loop while keeping the repo's current strengths:
plain Bash, explicit profiles, reproducible refs, Hetzner snapshots, and
auditable manifests.
