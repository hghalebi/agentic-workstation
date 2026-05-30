#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

usage() {
  cat <<'USAGE'
Agentic Workstation installer

Usage:
  ./install-agentic-tools.sh [--profile PROFILE] [--resume] [--only MODULES] [--skip MODULES]

Environment options:
  SKIP_BROWSER_TOOLS=1              Skip Playwright browser binary install.
  INCLUDE_FACTORY_TOOLS=1           Install optional software-factory helpers.
  INCLUDE_LOCAL_MODEL_RUNTIME=1     Install Ollama when factory tools are enabled.
  SKIP_AUTO_CONFIG=1                Skip shell, git, and local hook configuration.
  WORKSPACE_SOURCE=/path/to/workspace
                                    Copy a local workspace directory into WORKSPACE_TARGET.
  WORKSPACE_TARGET=/path/to/workspace
                                    Destination for workspace migration.
  WORKSPACE_REPO=git@example/repo.git
                                    Clone or update a Git workspace.
  WORKSPACE_REF=main                Branch, tag, or ref for WORKSPACE_REPO.

Examples:
  ./install-agentic-tools.sh
  ./install-agentic-tools.sh --profile minimal
  ./install-agentic-tools.sh --profile factory --resume
  ./install-agentic-tools.sh --only base,runtimes,agents
  SKIP_BROWSER_TOOLS=1 ./install-agentic-tools.sh --profile coding-agent
USAGE
}

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
  HOME_DIR="/root"
else
  SUDO="sudo"
  HOME_DIR="${HOME}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${PROFILE:-coding-agent}"
ONLY_MODULES=""
SKIP_MODULES=""
RESUME=0
RUN_DOCTOR=1
STATE_DIR="${STATE_DIR:-/var/lib/agentic-workstation}"
MANIFEST_PATH="${MANIFEST_PATH:-${STATE_DIR}/manifest.json}"

log() {
  printf '\n==> %s\n' "$*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

die() {
  echo "error: $*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --profile)
        [[ $# -ge 2 ]] || die "--profile requires a value"
        PROFILE="$2"
        shift 2
        ;;
      --profile=*)
        PROFILE="${1#*=}"
        shift
        ;;
      --only)
        [[ $# -ge 2 ]] || die "--only requires a comma-separated module list"
        ONLY_MODULES="$2"
        shift 2
        ;;
      --only=*)
        ONLY_MODULES="${1#*=}"
        shift
        ;;
      --skip)
        [[ $# -ge 2 ]] || die "--skip requires a comma-separated module list"
        SKIP_MODULES="$2"
        shift 2
        ;;
      --skip=*)
        SKIP_MODULES="${1#*=}"
        shift
        ;;
      --resume)
        RESUME=1
        shift
        ;;
      --no-doctor)
        RUN_DOCTOR=0
        shift
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

load_profile() {
  local profile_path="${SCRIPT_DIR}/profiles/${PROFILE}.env"
  [[ -f "$profile_path" ]] || die "unknown profile: ${PROFILE}"

  log "Loading profile: ${PROFILE}"
  # shellcheck disable=SC1090
  source "$profile_path"

  if [[ "${INCLUDE_FACTORY_TOOLS:-0}" == "1" ]]; then
    INSTALL_FACTORY_TOOLS=1
    INSTALL_SECURITY_TOOLS=1
  fi
  if [[ "${INCLUDE_LOCAL_MODEL_RUNTIME:-0}" == "1" ]]; then
    INSTALL_FACTORY_TOOLS=1
    INSTALL_LOCAL_MODEL_RUNTIME=1
  fi
  if [[ "${SKIP_BROWSER_TOOLS:-0}" == "1" ]]; then
    INSTALL_BROWSER_TOOLS=0
  fi
  if [[ "${SKIP_AUTO_CONFIG:-0}" == "1" ]]; then
    AUTO_CONFIG=0
  fi
}

csv_contains() {
  local list="$1"
  local value="$2"
  [[ ",${list}," == *",${value},"* ]]
}

should_run_module() {
  local module="$1"
  if [[ -n "$ONLY_MODULES" ]] && ! csv_contains "$ONLY_MODULES" "$module"; then
    return 1
  fi
  if [[ -n "$SKIP_MODULES" ]] && csv_contains "$SKIP_MODULES" "$module"; then
    return 1
  fi
  return 0
}

module_marker() {
  printf '%s/installed/%s' "$STATE_DIR" "$1"
}

mark_done() {
  local module="$1"
  $SUDO mkdir -p "${STATE_DIR}/installed"
  date -Is | $SUDO tee "$(module_marker "$module")" >/dev/null
}

is_done() {
  [[ -f "$(module_marker "$1")" ]]
}

run_module() {
  local module="$1"
  local fn="$2"
  shift 2

  if ! should_run_module "$module"; then
    log "Skipping module: ${module}"
    return
  fi

  if [[ "$RESUME" == "1" ]] && is_done "$module"; then
    log "Skipping completed module: ${module}"
    return
  fi

  "$fn" "$@"
  mark_done "$module"
}

apt_install_base() {
  log "Installing base Ubuntu CLI packages"
  $SUDO apt-get update -y
  $SUDO apt-get install -y \
    ca-certificates gnupg lsb-release curl wget unzip git gh jq ripgrep fd-find fzf tmux direnv \
    make build-essential pkg-config libssl-dev python3 python3-pip python3-venv pipx \
    nodejs npm golang-go \
    shellcheck sqlite3 netcat-openbsd git-lfs age tree rsync zip \
    lsof strace ltrace ncdu

  if ! have fd && have fdfind; then
    $SUDO ln -sf /usr/bin/fdfind /usr/local/bin/fd
  fi

  git lfs install --system || true

  log "Installing optional base helpers"
  $SUDO apt-get install -y postgresql-client redis-tools dnsutils || true

  log "Installing best-effort developer diagnostics"
  for pkg in bats shfmt hyperfine duf pre-commit; do
    $SUDO apt-get install -y "$pkg" || log "Could not install optional apt package: $pkg"
  done
}

install_rust() {
  if have rustup && have cargo && have rustc; then
    log "Rust already installed"
    rustc --version || true
    return
  fi

  log "Installing Rust with rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile default
  export PATH="${HOME_DIR}/.cargo/bin:${PATH}"
  rustup default stable
}

install_uv() {
  if have uv && have uvx; then
    log "uv already installed"
    uv --version || true
    return
  fi

  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME_DIR}/.local/bin:${PATH}"
}

install_runtimes() {
  install_rust
  install_uv
}

install_mise() {
  if have mise; then
    log "mise already installed"
    mise --version || true
    return
  fi

  log "Installing mise"
  if [[ "$(id -u)" -eq 0 ]]; then
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
  else
    curl -fsSL https://mise.run | sh
    if [[ -x "${HOME_DIR}/.local/bin/mise" ]]; then
      $SUDO ln -sf "${HOME_DIR}/.local/bin/mise" /usr/local/bin/mise
    fi
  fi
}

install_aqua() {
  if have aqua; then
    log "aqua already installed"
    aqua --version || true
    return
  fi

  log "Installing aqua"
  tmpdir="$(mktemp -d)"
  curl -fsSLo "${tmpdir}/aqua-installer" "https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.2/aqua-installer"
  echo "98b883756cdd0a6807a8c7623404bfc3bc169275ad9064dc23a6e24ad398f43d  ${tmpdir}/aqua-installer" | sha256sum -c -
  chmod +x "${tmpdir}/aqua-installer"

  if [[ "$(id -u)" -eq 0 ]]; then
    AQUA_ROOT_DIR=/opt/aquaproj-aqua "${tmpdir}/aqua-installer"
    $SUDO ln -sf /opt/aquaproj-aqua/bin/aqua /usr/local/bin/aqua
  else
    "${tmpdir}/aqua-installer"
    if [[ -x "${HOME_DIR}/.local/share/aquaproj-aqua/bin/aqua" ]]; then
      $SUDO ln -sf "${HOME_DIR}/.local/share/aquaproj-aqua/bin/aqua" /usr/local/bin/aqua
    fi
  fi

  rm -rf "$tmpdir"
}

install_version_managers() {
  install_mise
  install_aqua
}

install_yaml_and_git_helpers() {
  if have yq; then
    log "yq already installed"
    yq --version || true
  else
    log "Installing yq"
    go install github.com/mikefarah/yq/v4@latest
    if [[ -x "${HOME_DIR}/go/bin/yq" ]]; then
      $SUDO ln -sf "${HOME_DIR}/go/bin/yq" /usr/local/bin/yq
    fi
  fi

  if have delta; then
    log "delta already installed"
    delta --version || true
  else
    log "Installing delta"
    cargo install --locked git-delta
    if [[ -x "${HOME_DIR}/.cargo/bin/delta" ]]; then
      $SUDO ln -sf "${HOME_DIR}/.cargo/bin/delta" /usr/local/bin/delta
    fi
  fi
}

install_node_globals() {
  log "Installing npm global agent and Workspace CLIs"
  $SUDO npm install -g \
    @openai/codex \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @github/copilot \
    @google/clasp \
    @googleworkspace/cli \
    neonctl \
    @modelcontextprotocol/inspector \
    playwright \
    opencode-ai \
    openclaw@latest \
    codeagents
}

install_python_agent_tools() {
  log "Installing Python agent helper tools"
  python3 -m pip install --user --break-system-packages --upgrade codeagents
  export PATH="${HOME_DIR}/.local/bin:${PATH}"
  uv tool install --force --python python3.12 --with pip aider-chat@latest
  uv tool install --force llm
  uv tool install --force openhands --python 3.12
}

install_agent_clis() {
  install_node_globals
  install_python_agent_tools
}

install_browser_helpers() {
  if [[ "${INSTALL_BROWSER_TOOLS:-0}" != "1" ]]; then
    log "Skipping Playwright browser install for profile ${PROFILE}"
    return
  fi

  log "Installing Playwright Chromium browser and OS dependencies"
  if ! npx -y playwright install --with-deps chromium; then
    log "Playwright Chromium install failed or is unsupported on this OS; continuing without browser binaries"
  fi
}

install_cloud_provider_helpers() {
  if have hcloud; then
    log "Hetzner hcloud CLI already installed"
    hcloud version || true
  else
    log "Installing Hetzner hcloud CLI"
    go install github.com/hetznercloud/cli/cmd/hcloud@latest
    if [[ -x "${HOME_DIR}/go/bin/hcloud" ]]; then
      $SUDO ln -sf "${HOME_DIR}/go/bin/hcloud" /usr/local/bin/hcloud
    fi
  fi
}

install_cloud_clis() {
  install_cloud_provider_helpers
  install_gcloud_cli
}

install_terminal_workspace_helpers() {
  if have zellij; then
    log "Zellij already installed"
    zellij --version || true
    return
  fi

  log "Installing Zellij"
  cargo install --locked zellij
  if [[ -x "${HOME_DIR}/.cargo/bin/zellij" ]]; then
    $SUDO ln -sf "${HOME_DIR}/.cargo/bin/zellij" /usr/local/bin/zellij
  fi
}

install_factory_helpers() {
  if [[ "${INSTALL_FACTORY_TOOLS:-0}" != "1" ]]; then
    log "Skipping software factory helpers for profile ${PROFILE}"
    return
  fi

  log "Installing software factory helper CLIs"
  $SUDO apt-get update -y
  $SUDO apt-get install -y pandoc poppler-utils ffmpeg imagemagick tesseract-ocr httpie shellcheck yamllint
  for pkg in bpftrace linux-tools-common linux-tools-generic; do
    $SUDO apt-get install -y "$pkg" || log "Could not install optional apt package: $pkg"
  done

  $SUDO npm install -g @go-task/cli snyk

  uv tool install --force semgrep
  uv tool install --force dvc
  uv tool install --force deepagents-cli

  cargo install --locked just
  go install github.com/zricethezav/gitleaks/v8@latest

  if [[ -x "${HOME_DIR}/.cargo/bin/just" ]]; then
    $SUDO ln -sf "${HOME_DIR}/.cargo/bin/just" /usr/local/bin/just
  fi
  if [[ -x "${HOME_DIR}/go/bin/gitleaks" ]]; then
    $SUDO ln -sf "${HOME_DIR}/go/bin/gitleaks" /usr/local/bin/gitleaks
  fi

  if ! have hf; then
    curl -LsSf https://hf.co/cli/install.sh | bash
  fi

  if [[ "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" == "1" ]] && ! have ollama; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi

  if [[ "${INSTALL_SECURITY_TOOLS:-0}" == "1" ]]; then
    install_supply_chain_helpers
  fi
}

install_supply_chain_helpers() {
  log "Installing supply-chain and container analysis helpers"

  if ! have syft; then
    curl -sSfL https://get.anchore.io/syft | $SUDO sh -s -- -b /usr/local/bin
  fi

  if ! have grype; then
    curl -sSfL https://get.anchore.io/grype | $SUDO sh -s -- -b /usr/local/bin
  fi

  if ! have cosign; then
    go install github.com/sigstore/cosign/v3/cmd/cosign@latest
    if [[ -x "${HOME_DIR}/go/bin/cosign" ]]; then
      $SUDO ln -sf "${HOME_DIR}/go/bin/cosign" /usr/local/bin/cosign
    fi
  fi

  if ! have trivy; then
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | $SUDO gpg --dearmor -o /usr/share/keyrings/trivy.gpg
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | $SUDO tee /etc/apt/sources.list.d/trivy.list >/dev/null
    $SUDO apt-get update -y
    $SUDO apt-get install -y trivy
  fi

  if ! have hadolint; then
    case "$(uname -m)" in
      x86_64 | amd64) hadolint_asset="hadolint-Linux-x86_64" ;;
      aarch64 | arm64) hadolint_asset="hadolint-Linux-arm64" ;;
      *)
        echo "Unsupported hadolint architecture: $(uname -m)" >&2
        return 1
        ;;
    esac
    tmpdir="$(mktemp -d)"
    curl -fsSLo "${tmpdir}/hadolint" "https://github.com/hadolint/hadolint/releases/latest/download/${hadolint_asset}"
    chmod +x "${tmpdir}/hadolint"
    $SUDO mv "${tmpdir}/hadolint" /usr/local/bin/hadolint
    rm -rf "$tmpdir"
  fi
}

install_1password_cli() {
  if have op; then
    log "1Password CLI already installed"
    op --version || true
    return
  fi

  log "Installing 1Password CLI server binary"
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    amd64 | 386 | arm | arm64) ;;
    *)
      echo "Unsupported 1Password CLI architecture: $ARCH" >&2
      return 1
      ;;
  esac

  OP_VERSION="v$(curl -fsSL https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  tmpdir="$(mktemp -d)"
  curl -fsSLo "${tmpdir}/op.zip" "https://cache.agilebits.com/dist/1P/op2/pkg/${OP_VERSION}/op_linux_${ARCH}_${OP_VERSION}.zip"
  $SUDO unzip -o "${tmpdir}/op.zip" -d /usr/local/bin/
  rm -rf "$tmpdir"
  $SUDO groupadd -f onepassword-cli
  $SUDO chgrp onepassword-cli /usr/local/bin/op
  $SUDO chmod g+s /usr/local/bin/op
}

install_gcloud_cli() {
  if have gcloud; then
    log "Google Cloud CLI already installed"
    gcloud --version || true
    return
  fi

  log "Installing Google Cloud CLI"
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | $SUDO tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y google-cloud-cli
}

install_harness_cli() {
  if have hc; then
    log "Harness CLI already installed"
    hc version || true
    return
  fi

  log "Installing Harness CLI v1"
  curl -fsSL https://raw.githubusercontent.com/harness/harness-cli/v2/install | sh

  if [[ -x ./hc && ! -x /usr/local/bin/hc ]]; then
    $SUDO mv ./hc /usr/local/bin/hc
  fi
}

migrate_workspace() {
  if [[ -z "${WORKSPACE_SOURCE:-}" ]]; then
    log "Skipping workspace migration; set WORKSPACE_SOURCE=/path/to/workspace to enable"
  else
    local workspace_target="${WORKSPACE_TARGET:-${HOME_DIR}/workspace}"

    if [[ ! -e "$WORKSPACE_SOURCE" ]]; then
      echo "WORKSPACE_SOURCE does not exist: $WORKSPACE_SOURCE" >&2
      return 1
    fi

    if [[ -e "$workspace_target" ]]; then
      log "$workspace_target already exists; skipping workspace migration"
    else
      log "Migrating workspace to $workspace_target"
      $SUDO cp -a "$WORKSPACE_SOURCE" "$workspace_target"
    fi
  fi
}

hydrate_workspace_repo() {
  if [[ -z "${WORKSPACE_REPO:-}" ]]; then
    log "Skipping workspace repo hydration; set WORKSPACE_REPO to enable"
    return
  fi

  local repo_name
  repo_name="$(basename "$WORKSPACE_REPO" .git)"
  local workspace_target="${WORKSPACE_TARGET:-${HOME_DIR}/workspace/${repo_name}}"
  local workspace_ref="${WORKSPACE_REF:-main}"

  mkdir -p "$(dirname "$workspace_target")"

  if [[ ! -d "${workspace_target}/.git" ]]; then
    log "Cloning workspace repo into $workspace_target"
    git clone "$WORKSPACE_REPO" "$workspace_target"
  fi

  log "Updating workspace repo to ${workspace_ref}"
  git -C "$workspace_target" fetch --all --prune
  git -C "$workspace_target" checkout "$workspace_ref"
  git -C "$workspace_target" pull --ff-only || log "Workspace pull skipped or not fast-forwardable"
}

hydrate_workspace() {
  migrate_workspace
  hydrate_workspace_repo
}

append_shell_block() {
  local profile_path="$1"
  local shell_name="$2"

  if [[ -f "$profile_path" ]] && grep -q "agentic-workstation begin" "$profile_path"; then
    return
  fi

  mkdir -p "$(dirname "$profile_path")"
  cat >>"$profile_path" <<EOF

# agentic-workstation begin
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$HOME/go/bin:\$PATH"
if command -v mise >/dev/null 2>&1; then
  eval "\$(mise activate ${shell_name})"
fi
# agentic-workstation end
EOF
}

configure_shell_environment() {
  log "Configuring shell PATH and mise activation"
  append_shell_block "${HOME_DIR}/.profile" bash
  append_shell_block "${HOME_DIR}/.bashrc" bash

  if [[ -f "${HOME_DIR}/.zshrc" ]]; then
    append_shell_block "${HOME_DIR}/.zshrc" zsh
  fi
}

git_config_if_unset() {
  local key="$1"
  local value="$2"

  if ! git config --global --get "$key" >/dev/null 2>&1; then
    git config --global "$key" "$value"
  fi
}

configure_git_defaults() {
  if ! have git || ! have delta; then
    return
  fi

  log "Configuring git defaults for delta"
  git_config_if_unset core.pager "delta"
  git_config_if_unset interactive.diffFilter "delta --color-only"
  git_config_if_unset delta.navigate true
  git_config_if_unset merge.conflictStyle zdiff3
}

configure_local_hooks() {
  if [[ -f .pre-commit-config.yaml ]] && have pre-commit && [[ -d .git ]]; then
    log "Installing local pre-commit hooks"
    pre-commit install || log "pre-commit hook installation failed; continuing"
  fi
}

configure_workstation() {
  if [[ "${AUTO_CONFIG:-1}" != "1" ]]; then
    log "Skipping auto configuration for profile ${PROFILE}"
    return
  fi

  configure_shell_environment
  configure_git_defaults
  configure_local_hooks
}

verify_tool_group() {
  log "$1"
  shift
  for cmd in "$@"; do
    if have "$cmd"; then
      printf '%-10s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%-10s MISSING\n' "$cmd"
    fi
  done
}

verify_tools() {
  verify_tool_group "Default tool checks" \
    git gh curl wget jq yq rg fd fzf tmux zellij direnv make gcc shellcheck shfmt bats sqlite3 psql redis-cli dig nc lsof strace ltrace git-lfs age tree rsync zip ncdu duf hyperfine pre-commit delta \
    python3 pipx node npm npx go rustc cargo uv uvx mise aqua \
    codex claude gemini copilot op gcloud hcloud neonctl clasp gws opencode openclaw aider llm openhands codeagents hc

  if [[ "${INSTALL_FACTORY_TOOLS:-0}" == "1" ]]; then
    verify_tool_group "Factory tool checks" \
      task just yamllint pandoc pdftotext ffmpeg convert tesseract http deepagents hf dvc semgrep snyk gitleaks syft grype cosign trivy hadolint bpftrace perf
  fi

  if [[ "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" == "1" ]]; then
    verify_tool_group "Local model runtime checks" ollama
  fi
}

tool_version() {
  local cmd="$1"
  shift
  if have "$cmd"; then
    "$@" 2>/dev/null | head -n1 || true
  fi
}

write_manifest() {
  log "Writing install manifest"
  $SUDO mkdir -p "$STATE_DIR"

  local os_id="unknown"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    os_id="${ID:-unknown}-${VERSION_ID:-unknown}"
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  jq -n \
    --arg profile "$PROFILE" \
    --arg installed_at "$(date -Is)" \
    --arg hostname "$(hostname)" \
    --arg os "$os_id" \
    --arg git "$(tool_version git git --version)" \
    --arg node "$(tool_version node node --version)" \
    --arg npm "$(tool_version npm npm --version)" \
    --arg python "$(tool_version python3 python3 --version)" \
    --arg uv "$(tool_version uv uv --version)" \
    --arg go "$(tool_version go go version)" \
    --arg rustc "$(tool_version rustc rustc --version)" \
    --arg cargo "$(tool_version cargo cargo --version)" \
    --arg gh "$(tool_version gh gh --version)" \
    --arg op "$(tool_version op op --version)" \
    --arg codex "$(tool_version codex codex --version)" \
    --arg claude "$(tool_version claude claude --version)" \
    '{
      profile: $profile,
      installed_at: $installed_at,
      hostname: $hostname,
      os: $os,
      tools: {
        git: $git,
        node: $node,
        npm: $npm,
        python: $python,
        uv: $uv,
        go: $go,
        rustc: $rustc,
        cargo: $cargo,
        gh: $gh,
        op: $op,
        codex: $codex,
        claude: $claude
      }
    }' >"$tmpfile"

  $SUDO install -m 0644 "$tmpfile" "$MANIFEST_PATH"
  rm -f "$tmpfile"
}

run_doctor() {
  if [[ "$RUN_DOCTOR" != "1" ]]; then
    return
  fi
  if [[ -x "${SCRIPT_DIR}/scripts/doctor.sh" ]]; then
    "${SCRIPT_DIR}/scripts/doctor.sh" --profile "$PROFILE"
  fi
}

main() {
  parse_args "$@"
  load_profile

  [[ "${INSTALL_BASE:-0}" == "1" ]] && run_module base apt_install_base
  [[ "${INSTALL_RUNTIMES:-0}" == "1" ]] && run_module runtimes install_runtimes
  [[ "${INSTALL_VERSION_MANAGERS:-0}" == "1" ]] && run_module version-managers install_version_managers
  [[ "${INSTALL_GIT_HELPERS:-0}" == "1" ]] && run_module git-helpers install_yaml_and_git_helpers
  [[ "${INSTALL_AGENT_CLIS:-0}" == "1" ]] && run_module agents install_agent_clis
  [[ "${INSTALL_BROWSER_TOOLS:-0}" == "1" ]] && run_module browser install_browser_helpers
  [[ "${INSTALL_CLOUD_CLIS:-0}" == "1" ]] && run_module cloud install_cloud_clis
  [[ "${INSTALL_TERMINAL_TOOLS:-0}" == "1" ]] && run_module terminal install_terminal_workspace_helpers
  if [[ "${INSTALL_FACTORY_TOOLS:-0}" == "1" || "${INSTALL_SECURITY_TOOLS:-0}" == "1" || "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" == "1" ]]; then
    run_module factory install_factory_helpers
  fi
  [[ "${INSTALL_ONEPASSWORD:-0}" == "1" ]] && run_module onepassword install_1password_cli
  [[ "${INSTALL_HARNESS:-0}" == "1" ]] && run_module harness install_harness_cli
  run_module workspace hydrate_workspace
  run_module config configure_workstation
  run_module manifest write_manifest
  verify_tools
  run_doctor

  log "Install pass complete. Open a new shell, then run scripts/auth-status.sh after login."
}

main "$@"
