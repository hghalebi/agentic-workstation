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
    nodejs golang-go \
    shellcheck sqlite3 netcat-openbsd git-lfs age tree rsync zip

  if ! have fd && have fdfind; then
    $SUDO ln -sf /usr/bin/fdfind /usr/local/bin/fd
  fi

  git lfs install --system || true

  log "Installing optional base helpers"
  $SUDO apt-get install -y postgresql-client redis-tools dnsutils || true
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
    amd64|386|arm|arm64) ;;
    *) echo "Unsupported 1Password CLI architecture: $ARCH" >&2; return 1 ;;
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

verify_tools() {
  log "Version checks"
  for cmd in git gh curl jq rg fd fzf tmux zellij direnv make task just gcc shellcheck yamllint sqlite3 psql redis-cli dig nc git-lfs age tree rsync pandoc pdftotext ffmpeg convert tesseract http python3 pipx node npm npx go rustc cargo uv uvx codex claude gemini copilot op gcloud hcloud neonctl clasp gws opencode openclaw aider llm openhands deepagents hf dvc semgrep snyk gitleaks ollama hc; do
    if have "$cmd"; then
      printf '%-10s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%-10s MISSING\n' "$cmd"
    fi
  done
}

main() {
  apt_install_base
  install_rust
  install_uv
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
  verify_tools

  log "Install pass complete. Run the auth commands in README.md next."
}

main "$@"
