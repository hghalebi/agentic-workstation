#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

usage() {
  cat <<'USAGE'
Agentic Workstation installer

Usage:
  ./install-agentic-tools.sh [--profile PROFILE] [--resume] [--only MODULES] [--skip MODULES]
  ./install-agentic-tools.sh [--profile PROFILE] --dry-run
  ./install-agentic-tools.sh [--profile PROFILE] --plan
  ./install-agentic-tools.sh [--profile PROFILE] --json-plan

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
  ./install-agentic-tools.sh --profile coding-agent --dry-run
  ./install-agentic-tools.sh --profile coding-agent --json-plan
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
LOCKFILE_PATH="${LOCKFILE_PATH:-${SCRIPT_DIR}/agentic-tools.lock.yaml}"
PROFILE="${PROFILE:-coding-agent}"
ONLY_MODULES=""
SKIP_MODULES=""
RESUME=0
RUN_DOCTOR=1
PLAN_ONLY=0
JSON_PLAN=0
DRY_RUN=0
STATE_DIR="${STATE_DIR:-/var/lib/agentic-workstation}"
MANIFEST_PATH="${MANIFEST_PATH:-${STATE_DIR}/manifest.json}"
MODULE_ORDER=(
  base
  server-base
  docker
  runtimes
  rust-server-tools
  version-managers
  git-helpers
  agents
  browser
  cloud
  terminal
  factory
  onepassword
  harness
  openclaw-layout
  opentelemetry
  neon
  hetzner-s3
  onepassword-ssh
  dotfiles
  workspace
  config
  manifest
)

log() {
  printf '\n==> %s\n' "$*" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

die() {
  echo "error: $*" >&2
  exit 1
}

locked_tool_version() {
  local section="$1"
  local tool="$2"
  local version

  [[ -f "$LOCKFILE_PATH" ]] || die "missing lockfile: ${LOCKFILE_PATH}"

  version="$(awk -v section="$section" -v tool="$tool" '
    $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" {
      in_section = 1
      next
    }
    in_section && $0 ~ "^[^[:space:]][^:]*:" {
      exit
    }
    in_section {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == "" || line ~ /^#/) {
        next
      }
      key = line
      sub(/:.*/, "", key)
      gsub(/^"|"$/, "", key)
      if (key == tool) {
        value = line
        sub(/^[^:]+:[[:space:]]*/, "", value)
        sub(/[[:space:]]+#.*/, "", value)
        gsub(/^"|"$/, "", value)
        print value
        exit
      }
    }
  ' "$LOCKFILE_PATH")"

  [[ -n "$version" ]] || die "missing pinned version in ${LOCKFILE_PATH}: ${section}.${tool}"

  case "$version" in
    latest | *@latest | *"<pinned-version>"* | *TODO* | *FIXME*)
      die "invalid moving or placeholder version in ${LOCKFILE_PATH}: ${section}.${tool}=${version}"
      ;;
  esac

  printf '%s' "$version"
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
      --dry-run)
        DRY_RUN=1
        PLAN_ONLY=1
        shift
        ;;
      --plan)
        PLAN_ONLY=1
        shift
        ;;
      --json-plan)
        JSON_PLAN=1
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

module_description() {
  case "$1" in
    base) printf 'Core Ubuntu CLI and debugging tools' ;;
    server-base) printf 'Server firewall, web, updates, intrusion prevention, and journal limits' ;;
    docker) printf 'Docker Engine from the official Docker apt repository' ;;
    runtimes) printf 'Rust and uv runtime tooling' ;;
    rust-server-tools) printf 'Rust server development tools' ;;
    version-managers) printf 'mise and aqua tool version managers' ;;
    git-helpers) printf 'YAML and Git diff helpers' ;;
    agents) printf 'Agent and model CLIs' ;;
    browser) printf 'Playwright browser binaries' ;;
    cloud) printf 'Cloud and database CLIs' ;;
    terminal) printf 'Terminal workspace tools' ;;
    factory) printf 'Factory, security, artifact, tracing, and model helper tools' ;;
    onepassword) printf '1Password CLI' ;;
    harness) printf 'Harness CLI' ;;
    openclaw-layout) printf 'OpenClaw server directory layout' ;;
    opentelemetry) printf 'OpenTelemetry Collector Docker Compose stack' ;;
    neon) printf 'Neon Postgres client support and env validation template' ;;
    hetzner-s3) printf 'Hetzner S3 awscli support and bucket validation helper' ;;
    onepassword-ssh) printf '1Password SSH public-key export and SSH client helper' ;;
    dotfiles) printf 'Optional dotfiles clone and install hook' ;;
    workspace) printf 'Workspace copy and Git hydration' ;;
    config) printf 'Shell, Git, and hook auto-configuration' ;;
    manifest) printf 'Install manifest generation' ;;
    *) printf 'Unknown module' ;;
  esac
}

module_requires_sudo() {
  case "$1" in
    base | server-base | docker | version-managers | git-helpers | agents | browser | cloud | terminal | factory | onepassword | harness | openclaw-layout | opentelemetry | neon | hetzner-s3 | onepassword-ssh | dotfiles | workspace | config | manifest) return 0 ;;
    runtimes | rust-server-tools) return 1 ;;
    *) return 1 ;;
  esac
}

module_profile_enabled() {
  case "$1" in
    base) [[ "${INSTALL_BASE:-0}" == "1" ]] ;;
    server-base) [[ "${INSTALL_SERVER_BASE:-0}" == "1" ]] ;;
    docker) [[ "${INSTALL_DOCKER:-0}" == "1" ]] ;;
    runtimes) [[ "${INSTALL_RUNTIMES:-0}" == "1" ]] ;;
    rust-server-tools) [[ "${INSTALL_RUST_SERVER_TOOLS:-0}" == "1" ]] ;;
    version-managers) [[ "${INSTALL_VERSION_MANAGERS:-0}" == "1" ]] ;;
    git-helpers) [[ "${INSTALL_GIT_HELPERS:-0}" == "1" ]] ;;
    agents) [[ "${INSTALL_AGENT_CLIS:-0}" == "1" ]] ;;
    browser) [[ "${INSTALL_BROWSER_TOOLS:-0}" == "1" ]] ;;
    cloud) [[ "${INSTALL_CLOUD_CLIS:-0}" == "1" ]] ;;
    terminal) [[ "${INSTALL_TERMINAL_TOOLS:-0}" == "1" ]] ;;
    factory) [[ "${INSTALL_FACTORY_TOOLS:-0}" == "1" || "${INSTALL_SECURITY_TOOLS:-0}" == "1" || "${INSTALL_LOCAL_MODEL_RUNTIME:-0}" == "1" ]] ;;
    onepassword) [[ "${INSTALL_ONEPASSWORD:-0}" == "1" ]] ;;
    harness) [[ "${INSTALL_HARNESS:-0}" == "1" ]] ;;
    openclaw-layout) [[ "${INSTALL_OPENCLAW_LAYOUT:-0}" == "1" ]] ;;
    opentelemetry) [[ "${INSTALL_OPENTELEMETRY:-0}" == "1" ]] ;;
    neon) [[ "${INSTALL_NEON_SUPPORT:-0}" == "1" ]] ;;
    hetzner-s3) [[ "${INSTALL_HETZNER_S3:-0}" == "1" ]] ;;
    onepassword-ssh) [[ "${INSTALL_ONEPASSWORD_SSH:-0}" == "1" ]] ;;
    dotfiles) [[ -n "${DOTFILES_REPO:-}" ]] ;;
    workspace) [[ -n "${WORKSPACE_SOURCE:-}" || -n "${WORKSPACE_REPO:-}" ]] ;;
    config) [[ "${AUTO_CONFIG:-1}" == "1" ]] ;;
    manifest) return 0 ;;
    *) return 1 ;;
  esac
}

module_plan_enabled() {
  local module="$1"
  module_profile_enabled "$module" || return 1
  should_run_module "$module" || return 1
  if [[ "$RESUME" == "1" ]] && is_done "$module"; then
    return 1
  fi
  return 0
}

module_plan_reason() {
  local module="$1"
  if ! module_profile_enabled "$module"; then
    printf 'profile-disabled'
  elif [[ -n "$ONLY_MODULES" ]] && ! csv_contains "$ONLY_MODULES" "$module"; then
    printf 'only-filter'
  elif [[ -n "$SKIP_MODULES" ]] && csv_contains "$SKIP_MODULES" "$module"; then
    printf 'skip-filter'
  elif [[ "$RESUME" == "1" ]] && is_done "$module"; then
    printf 'resume-marker'
  else
    printf 'profile'
  fi
}

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

json_bool() {
  if "$@"; then
    printf 'true'
  else
    printf 'false'
  fi
}

json_bool_value() {
  if [[ "${1:-0}" == "1" || "${1:-false}" == "true" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

write_json_plan() {
  printf '{\n'
  printf '  "profile": '
  json_string "$PROFILE"
  printf ',\n'
  printf '  "dry_run": %s,\n' "$(json_bool_value "$DRY_RUN")"
  printf '  "mutates_dotfiles": %s,\n' "$(json_bool_value "${AUTO_CONFIG:-1}")"
  printf '  "requires_sudo": true,\n'
  printf '  "modules": [\n'
  local first=1
  local module
  for module in "${MODULE_ORDER[@]}"; do
    if [[ "$first" == "1" ]]; then
      first=0
    else
      printf ',\n'
    fi
    printf '    {"name": '
    json_string "$module"
    printf ', "description": '
    json_string "$(module_description "$module")"
    printf ', "enabled": %s' "$(json_bool module_plan_enabled "$module")"
    printf ', "reason": '
    json_string "$(module_plan_reason "$module")"
    printf ', "requires_sudo": %s}' "$(json_bool module_requires_sudo "$module")"
  done
  printf '\n  ],\n'
  printf '  "remote_installers": [\n'
  printf '    "https://sh.rustup.rs",\n'
  printf '    "https://astral.sh/uv/install.sh",\n'
  printf '    "https://mise.run",\n'
  printf '    "https://raw.githubusercontent.com/aquaproj/aqua-installer",\n'
  printf '    "https://get.anchore.io/syft",\n'
  printf '    "https://get.anchore.io/grype",\n'
  printf '    "https://hf.co/cli/install.sh",\n'
  printf '    "https://ollama.com/install.sh",\n'
  printf '    "https://raw.githubusercontent.com/harness/harness-cli",\n'
  printf '    "https://app-updates.agilebits.com",\n'
  printf '    "https://cache.agilebits.com"\n'
  printf '  ]\n'
  printf '}\n'
}

write_human_plan() {
  printf 'Agentic Workstation install plan\n'
  printf 'profile: %s\n' "$PROFILE"
  printf 'dry_run: %s\n' "$DRY_RUN"
  printf 'mutates_dotfiles: %s\n' "$(if [[ "${AUTO_CONFIG:-1}" == "1" ]]; then printf yes; else printf no; fi)"
  printf 'requires_sudo: yes\n\n'
  printf 'Modules:\n'
  local module
  for module in "${MODULE_ORDER[@]}"; do
    local enabled="no"
    module_plan_enabled "$module" && enabled="yes"
    printf '  %-17s enabled=%-3s reason=%-16s %s\n' "$module" "$enabled" "$(module_plan_reason "$module")" "$(module_description "$module")"
  done
  printf '\nRemote installers are listed in --json-plan and docs/remote-installers.md.\n'
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
    shellcheck shfmt bats sqlite3 netcat-openbsd git-lfs age tree rsync zip \
    lsof strace ltrace ncdu

  if ! have fd && have fdfind; then
    $SUDO ln -sf /usr/bin/fdfind /usr/local/bin/fd
  fi

  git lfs install --system || true

  log "Installing optional base helpers"
  $SUDO apt-get install -y postgresql-client redis-tools dnsutils || true

  log "Installing best-effort developer diagnostics"
  for pkg in hyperfine duf pre-commit; do
    $SUDO apt-get install -y "$pkg" || log "Could not install optional apt package: $pkg"
  done
}

install_server_base() {
  log "Installing server base packages"
  $SUDO apt-get update -y
  $SUDO apt-get install -y ufw fail2ban nginx unattended-upgrades systemd-timesyncd

  log "Configuring unattended upgrades and journald limits"
  $SUDO dpkg-reconfigure -f noninteractive unattended-upgrades || true
  $SUDO mkdir -p /etc/systemd/journald.conf.d
  local tmpfile
  tmpfile="$(mktemp)"
  cat >"$tmpfile" <<'EOF'
[Journal]
SystemMaxUse=1G
SystemKeepFree=1G
RuntimeMaxUse=256M
MaxRetentionSec=14day
EOF
  $SUDO install -m 0644 "$tmpfile" /etc/systemd/journald.conf.d/agentic-workstation.conf
  rm -f "$tmpfile"
  $SUDO systemctl restart systemd-journald || true

  $SUDO systemctl enable --now fail2ban nginx unattended-upgrades || true
  if [[ "${OPENCLAW_ENABLE_UFW:-1}" == "1" ]]; then
    log "Configuring ufw for SSH, HTTP, and HTTPS"
    $SUDO ufw allow OpenSSH || true
    $SUDO ufw allow 'Nginx Full' || true
    $SUDO ufw --force enable || true
  fi
}

install_docker_engine() {
  if have docker && docker compose version >/dev/null 2>&1; then
    log "Docker already installed"
    docker --version || true
    docker compose version || true
    return
  fi

  log "Installing Docker Engine from the official apt repository"
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  # shellcheck disable=SC1091
  source /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  $SUDO systemctl enable --now docker
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

install_rust_server_tools() {
  log "Installing Rust server tools"
  export PATH="${HOME_DIR}/.cargo/bin:${PATH}"
  have cargo || die "cargo is required before installing Rust server tools"

  cargo install --locked sqlx-cli --version "$(locked_tool_version cargo sqlx-cli)" --no-default-features --features native-tls,postgres
  cargo install --locked cargo-nextest --version "$(locked_tool_version cargo cargo-nextest)"
  cargo install --locked cargo-watch --version "$(locked_tool_version cargo cargo-watch)"

  for cmd in sqlx cargo-nextest cargo-watch; do
    if [[ -x "${HOME_DIR}/.cargo/bin/${cmd}" ]]; then
      $SUDO ln -sf "${HOME_DIR}/.cargo/bin/${cmd}" "/usr/local/bin/${cmd}"
    fi
  done
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
    go install "github.com/mikefarah/yq/v4@$(locked_tool_version go github.com/mikefarah/yq/v4)"
    if [[ -x "${HOME_DIR}/go/bin/yq" ]]; then
      $SUDO ln -sf "${HOME_DIR}/go/bin/yq" /usr/local/bin/yq
    fi
  fi

  if have delta; then
    log "delta already installed"
    delta --version || true
  else
    log "Installing delta"
    cargo install --locked git-delta --version "$(locked_tool_version cargo git-delta)"
    if [[ -x "${HOME_DIR}/.cargo/bin/delta" ]]; then
      $SUDO ln -sf "${HOME_DIR}/.cargo/bin/delta" /usr/local/bin/delta
    fi
  fi
}

install_node_globals() {
  log "Installing npm global agent and Workspace CLIs"
  $SUDO npm install -g \
    "@openai/codex@$(locked_tool_version npm @openai/codex)" \
    "@anthropic-ai/claude-code@$(locked_tool_version npm @anthropic-ai/claude-code)" \
    "@google/gemini-cli@$(locked_tool_version npm @google/gemini-cli)" \
    "@github/copilot@$(locked_tool_version npm @github/copilot)" \
    "@google/clasp@$(locked_tool_version npm @google/clasp)" \
    "@googleworkspace/cli@$(locked_tool_version npm @googleworkspace/cli)" \
    "neonctl@$(locked_tool_version npm neonctl)" \
    "@modelcontextprotocol/inspector@$(locked_tool_version npm @modelcontextprotocol/inspector)" \
    "playwright@$(locked_tool_version npm playwright)" \
    "opencode-ai@$(locked_tool_version npm opencode-ai)" \
    "openclaw@$(locked_tool_version npm openclaw)" \
    "codeagents@$(locked_tool_version npm codeagents)"
}

install_python_agent_tools() {
  log "Installing Python agent helper tools"
  python3 -m pip install --user --break-system-packages --upgrade "codeagents==$(locked_tool_version pip codeagents)"
  export PATH="${HOME_DIR}/.local/bin:${PATH}"
  uv tool install --force --python python3.12 --with pip "aider-chat==$(locked_tool_version uv aider-chat)"
  uv tool install --force "llm==$(locked_tool_version uv llm)"
  uv tool install --force "openhands==$(locked_tool_version uv openhands)" --python 3.12
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
    go install "github.com/hetznercloud/cli/cmd/hcloud@$(locked_tool_version go github.com/hetznercloud/cli/cmd/hcloud)"
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
  cargo install --locked zellij --version "$(locked_tool_version cargo zellij)"
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

  $SUDO npm install -g \
    "@go-task/cli@$(locked_tool_version npm @go-task/cli)" \
    "snyk@$(locked_tool_version npm snyk)"

  uv tool install --force "semgrep==$(locked_tool_version uv semgrep)"
  uv tool install --force "dvc==$(locked_tool_version uv dvc)"
  uv tool install --force "deepagents-cli==$(locked_tool_version uv deepagents-cli)"

  cargo install --locked just --version "$(locked_tool_version cargo just)"
  go install "github.com/zricethezav/gitleaks/v8@$(locked_tool_version go github.com/zricethezav/gitleaks/v8)"

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
    go install "github.com/sigstore/cosign/v3/cmd/cosign@$(locked_tool_version go github.com/sigstore/cosign/v3/cmd/cosign)"
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
    curl -fsSLo "${tmpdir}/hadolint" "https://github.com/hadolint/hadolint/releases/download/$(locked_tool_version github_releases hadolint/hadolint)/${hadolint_asset}"
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

install_openclaw_layout() {
  log "Creating OpenClaw server layout"
  for dir in app tools repos otel secrets backups logs; do
    $SUDO install -d -m 0750 -o root -g root "/opt/openclaw/${dir}"
  done
  $SUDO chmod 0700 /opt/openclaw/secrets
}

install_opentelemetry_collector() {
  log "Writing OpenTelemetry Collector Docker Compose stack"
  $SUDO install -d -m 0750 /opt/openclaw/otel

  local tmpfile
  tmpfile="$(mktemp)"
  cat >"$tmpfile" <<'EOF'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.101.0
    restart: unless-stopped
    command:
      - --config=/etc/otelcol-contrib/config.yaml
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
    volumes:
      - ./collector.yaml:/etc/otelcol-contrib/config.yaml:ro
EOF
  $SUDO install -m 0644 "$tmpfile" /opt/openclaw/otel/docker-compose.yaml

  cat >"$tmpfile" <<'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch: {}
  memory_limiter:
    check_interval: 1s
    limit_mib: 256

exporters:
  debug:
    verbosity: basic

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
EOF
  $SUDO install -m 0644 "$tmpfile" /opt/openclaw/otel/collector.yaml
  rm -f "$tmpfile"
}

install_neon_support() {
  log "Installing Neon Postgres client support"
  $SUDO apt-get update -y
  $SUDO apt-get install -y postgresql-client
  if ! have sqlx; then
    install_rust_server_tools
  fi

  $SUDO install -d -m 0750 /opt/openclaw/app
  local tmpfile
  tmpfile="$(mktemp)"
  cat >"$tmpfile" <<'EOF'
# Neon/Postgres connection used by application and sqlx.
DATABASE_URL=postgresql://user:password@host.neon.tech/dbname?sslmode=require
PGHOST=host.neon.tech
PGDATABASE=dbname
PGUSER=user
PGPASSWORD=replace-me
PGSSLMODE=require

# Optional sqlx offline cache mode for CI.
SQLX_OFFLINE=false
EOF
  $SUDO install -m 0640 "$tmpfile" /opt/openclaw/app/.env.example
  rm -f "$tmpfile"
}

install_hetzner_s3_support() {
  log "Installing Hetzner S3 support"
  $SUDO apt-get update -y
  $SUDO apt-get install -y awscli
  $SUDO install -d -m 0750 /opt/openclaw/tools /opt/openclaw/secrets

  local tmpfile
  tmpfile="$(mktemp)"
  cat >"$tmpfile" <<'EOF'
# Hetzner Object Storage uses the S3 API. Set the endpoint for your region.
AWS_ACCESS_KEY_ID=replace-me
AWS_SECRET_ACCESS_KEY=replace-me
AWS_DEFAULT_REGION=fsn1
HETZNER_S3_ENDPOINT=https://fsn1.your-objectstorage.com
HETZNER_S3_BUCKET=openclaw-backups
EOF
  $SUDO install -m 0640 "$tmpfile" /opt/openclaw/secrets/hetzner-s3.env.example

  cat >"$tmpfile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-/opt/openclaw/secrets/hetzner-s3.env}"
if [[ -f "$env_file" ]]; then
  # shellcheck disable=SC1090
  source "$env_file"
fi

: "${HETZNER_S3_ENDPOINT:?set HETZNER_S3_ENDPOINT}"
: "${HETZNER_S3_BUCKET:?set HETZNER_S3_BUCKET}"

aws --endpoint-url "$HETZNER_S3_ENDPOINT" s3api head-bucket --bucket "$HETZNER_S3_BUCKET"
echo "bucket ok: ${HETZNER_S3_BUCKET}"
EOF
  $SUDO install -m 0755 "$tmpfile" /opt/openclaw/tools/check-hetzner-s3-bucket.sh
  rm -f "$tmpfile"
}

install_onepassword_ssh_helper() {
  log "Installing 1Password SSH helper"
  $SUDO install -d -m 0750 /opt/openclaw/tools
  local tmpfile
  tmpfile="$(mktemp)"
  cat >"$tmpfile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  op-ssh-helper --item ITEM [--vault VAULT] [--host HOST] [--output PATH]

Exports a public key from a 1Password SSH key item and appends an SSH host
block that uses the 1Password agent IdentityAgent socket.
USAGE
}

item=""
vault=""
host="github.com"
output="${HOME}/.ssh/id_ed25519_1password.pub"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --item) item="$2"; shift 2 ;;
    --item=*) item="${1#*=}"; shift ;;
    --vault) vault="$2"; shift 2 ;;
    --vault=*) vault="${1#*=}"; shift ;;
    --host) host="$2"; shift 2 ;;
    --host=*) host="${1#*=}"; shift ;;
    --output) output="$2"; shift 2 ;;
    --output=*) output="${1#*=}"; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$item" ]] || { usage >&2; exit 1; }
command -v op >/dev/null 2>&1 || { echo "missing op CLI" >&2; exit 1; }

mkdir -p "${HOME}/.ssh"
chmod 0700 "${HOME}/.ssh"

op_args=(item get "$item" --fields "public key")
if [[ -n "$vault" ]]; then
  op_args+=(--vault "$vault")
fi
op "${op_args[@]}" >"$output"
chmod 0644 "$output"

ssh_config="${HOME}/.ssh/config"
touch "$ssh_config"
chmod 0600 "$ssh_config"
if ! grep -q "agentic-workstation 1password ${host}" "$ssh_config"; then
  cat >>"$ssh_config" <<CONFIG

# agentic-workstation 1password ${host}
Host ${host}
  IdentityAgent ~/.1password/agent.sock
  IdentityFile ${output}
  IdentitiesOnly yes
CONFIG
fi

echo "public key exported: ${output}"
EOF
  $SUDO install -m 0755 "$tmpfile" /opt/openclaw/tools/op-ssh-helper
  rm -f "$tmpfile"
}

install_dotfiles() {
  if [[ -z "${DOTFILES_REPO:-}" ]]; then
    log "Skipping dotfiles; set DOTFILES_REPO to enable"
    return
  fi

  local target="${DOTFILES_TARGET:-${HOME_DIR}/.dotfiles}"
  local use_sudo=0
  if [[ "$target" != "$HOME_DIR" && "$target" != "${HOME_DIR}/"* ]]; then
    use_sudo=1
  fi

  log "Installing optional dotfiles from ${DOTFILES_REPO}"
  if [[ ! -d "${target}/.git" ]]; then
    if [[ "$use_sudo" == "1" ]]; then
      $SUDO git clone "$DOTFILES_REPO" "$target"
    else
      git clone "$DOTFILES_REPO" "$target"
    fi
  else
    if [[ "$use_sudo" == "1" ]]; then
      $SUDO git -C "$target" fetch --all --prune
      $SUDO git -C "$target" pull --ff-only || log "Dotfiles pull skipped or not fast-forwardable"
    else
      git -C "$target" fetch --all --prune
      git -C "$target" pull --ff-only || log "Dotfiles pull skipped or not fast-forwardable"
    fi
  fi

  if [[ "${DOTFILES_RUN_INSTALL:-0}" == "1" ]]; then
    if [[ -x "${target}/install.sh" ]]; then
      if [[ "$use_sudo" == "1" ]]; then
        $SUDO "${target}/install.sh"
      else
        "${target}/install.sh"
      fi
    elif [[ -f "${target}/Makefile" ]]; then
      if [[ "$use_sudo" == "1" ]]; then
        $SUDO make -C "$target" install
      else
        make -C "$target" install
      fi
    else
      log "No dotfiles installer found in ${target}; clone only"
    fi
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

  if [[ "${INSTALL_SERVER_BASE:-0}" == "1" ]]; then
    verify_tool_group "Server base checks" ufw fail2ban-client nginx
  fi

  if [[ "${INSTALL_DOCKER:-0}" == "1" ]]; then
    verify_tool_group "Docker checks" docker
    docker compose version || true
  fi

  if [[ "${INSTALL_RUST_SERVER_TOOLS:-0}" == "1" ]]; then
    verify_tool_group "Rust server tool checks" sqlx cargo-nextest cargo-watch
  fi

  if [[ "${INSTALL_HETZNER_S3:-0}" == "1" ]]; then
    verify_tool_group "Hetzner S3 checks" aws
  fi

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

  local lockfile_hash=""
  if [[ -f "${SCRIPT_DIR}/agentic-tools.lock.yaml" ]]; then
    lockfile_hash="$(sha256sum "${SCRIPT_DIR}/agentic-tools.lock.yaml" | awk '{print $1}')"
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  jq -n \
    --arg profile "$PROFILE" \
    --arg installed_at "$(date -Is)" \
    --arg hostname "$(hostname)" \
    --arg os "$os_id" \
    --arg lockfile_hash "$lockfile_hash" \
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
      lockfile_hash: $lockfile_hash,
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

  if [[ "$JSON_PLAN" == "1" ]]; then
    write_json_plan
    exit 0
  fi
  if [[ "$PLAN_ONLY" == "1" ]]; then
    write_human_plan
    exit 0
  fi

  [[ "${INSTALL_BASE:-0}" == "1" ]] && run_module base apt_install_base
  [[ "${INSTALL_SERVER_BASE:-0}" == "1" ]] && run_module server-base install_server_base
  [[ "${INSTALL_DOCKER:-0}" == "1" ]] && run_module docker install_docker_engine
  [[ "${INSTALL_RUNTIMES:-0}" == "1" ]] && run_module runtimes install_runtimes
  [[ "${INSTALL_RUST_SERVER_TOOLS:-0}" == "1" ]] && run_module rust-server-tools install_rust_server_tools
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
  [[ "${INSTALL_OPENCLAW_LAYOUT:-0}" == "1" ]] && run_module openclaw-layout install_openclaw_layout
  [[ "${INSTALL_OPENTELEMETRY:-0}" == "1" ]] && run_module opentelemetry install_opentelemetry_collector
  [[ "${INSTALL_NEON_SUPPORT:-0}" == "1" ]] && run_module neon install_neon_support
  [[ "${INSTALL_HETZNER_S3:-0}" == "1" ]] && run_module hetzner-s3 install_hetzner_s3_support
  [[ "${INSTALL_ONEPASSWORD_SSH:-0}" == "1" ]] && run_module onepassword-ssh install_onepassword_ssh_helper
  [[ -n "${DOTFILES_REPO:-}" ]] && run_module dotfiles install_dotfiles
  run_module workspace hydrate_workspace
  run_module config configure_workstation
  run_module manifest write_manifest
  verify_tools
  run_doctor

  log "Install pass complete. Open a new shell, then run scripts/auth-status.sh after login."
}

main "$@"
