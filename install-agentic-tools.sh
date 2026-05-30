#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

usage() {
  cat <<'USAGE'
Agentic Workstation installer

Usage:
  ./install-agentic-tools.sh

Environment options:
  SKIP_BROWSER_TOOLS=1              Skip Playwright browser binary install.
  INCLUDE_FACTORY_TOOLS=1           Install optional software-factory helpers.
  INCLUDE_LOCAL_MODEL_RUNTIME=1     Install Ollama when factory tools are enabled.
  SKIP_AUTO_CONFIG=1                Skip shell, git, and local hook configuration.
  WORKSPACE_SOURCE=/path/to/workspace
                                    Copy a local workspace directory into WORKSPACE_TARGET.
  WORKSPACE_TARGET=/path/to/workspace
                                    Destination for workspace migration.

Examples:
  ./install-agentic-tools.sh
  SKIP_BROWSER_TOOLS=1 ./install-agentic-tools.sh
  INCLUDE_FACTORY_TOOLS=1 ./install-agentic-tools.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
  HOME_DIR="/root"
else
  SUDO="sudo"
  HOME_DIR="${HOME}"
fi

log() {
  printf '\n==> %s\n' "$*"
}

have() {
  command -v "$1" >/dev/null 2>&1
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

install_browser_helpers() {
  if [[ "${SKIP_BROWSER_TOOLS:-0}" == "1" ]]; then
    log "Skipping Playwright browser install because SKIP_BROWSER_TOOLS=1"
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
  if [[ "${INCLUDE_FACTORY_TOOLS:-0}" != "1" ]]; then
    log "Skipping software factory helpers; set INCLUDE_FACTORY_TOOLS=1 to enable"
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

  if [[ "${INCLUDE_LOCAL_MODEL_RUNTIME:-0}" == "1" ]] && ! have ollama; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi

  install_supply_chain_helpers
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
    return
  fi

  local workspace_target="${WORKSPACE_TARGET:-${HOME_DIR}/workspace}"

  if [[ ! -e "$WORKSPACE_SOURCE" ]]; then
    echo "WORKSPACE_SOURCE does not exist: $WORKSPACE_SOURCE" >&2
    return 1
  fi

  if [[ -e "$workspace_target" ]]; then
    log "$workspace_target already exists; skipping workspace migration"
    return
  fi

  log "Migrating workspace to $workspace_target"
  $SUDO cp -a "$WORKSPACE_SOURCE" "$workspace_target"
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
  if [[ "${SKIP_AUTO_CONFIG:-0}" == "1" ]]; then
    log "Skipping auto configuration because SKIP_AUTO_CONFIG=1"
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

  if [[ "${INCLUDE_FACTORY_TOOLS:-0}" == "1" ]]; then
    verify_tool_group "Factory tool checks" \
      task just yamllint pandoc pdftotext ffmpeg convert tesseract http deepagents hf dvc semgrep snyk gitleaks syft grype cosign trivy hadolint bpftrace perf
  fi

  if [[ "${INCLUDE_LOCAL_MODEL_RUNTIME:-0}" == "1" ]]; then
    verify_tool_group "Local model runtime checks" ollama
  fi
}

main() {
  apt_install_base
  install_rust
  install_uv
  install_mise
  install_aqua
  install_yaml_and_git_helpers
  install_node_globals
  install_python_agent_tools
  install_browser_helpers
  install_cloud_provider_helpers
  install_terminal_workspace_helpers
  install_factory_helpers
  install_1password_cli
  install_gcloud_cli
  install_harness_cli
  migrate_workspace
  configure_workstation
  verify_tools

  log "Install pass complete. Open a new shell, then run the auth commands in README.md."
}

main "$@"
