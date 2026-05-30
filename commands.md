# Install Command Reference

This page lists the commands embedded in `install-agentic-tools.sh`.

Use it to audit what the installer runs, update vendor sources, or install a subset manually.

## Ubuntu Base

```bash
apt-get update -y
apt-get install -y ca-certificates gnupg lsb-release curl wget unzip git gh jq ripgrep fd-find fzf tmux direnv make build-essential pkg-config libssl-dev python3 python3-pip python3-venv pipx nodejs npm golang-go shellcheck sqlite3 postgresql-client redis-tools dnsutils netcat-openbsd git-lfs age tree rsync zip lsof strace ltrace ncdu bats shfmt hyperfine duf pre-commit
```

## Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile default
```

Source: https://www.rust-lang.org/tools/install

## uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Source: https://docs.astral.sh/uv/getting-started/installation/

## mise

```bash
curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
```

Source: https://mise.jdx.dev/installing-mise.html

## aqua

```bash
curl -fsSLo aqua-installer https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.2/aqua-installer
echo "98b883756cdd0a6807a8c7623404bfc3bc169275ad9064dc23a6e24ad398f43d  aqua-installer" | sha256sum -c -
chmod +x aqua-installer
AQUA_ROOT_DIR=/opt/aquaproj-aqua ./aqua-installer
ln -sf /opt/aquaproj-aqua/bin/aqua /usr/local/bin/aqua
```

Source: https://aquaproj.github.io/docs/products/aqua-installer/

## YAML and Git Helpers

```bash
go install github.com/mikefarah/yq/v4@latest
cargo install --locked git-delta
```

Sources:

- https://github.com/mikefarah/yq
- https://dandavison.github.io/delta/installation.html

## Zellij

```bash
cargo install --locked zellij
ln -sf "$HOME/.cargo/bin/zellij" /usr/local/bin/zellij
```

Source: https://zellij.dev/documentation/installation.html

## Agent and Model CLIs

```bash
npm install -g @openai/codex
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli
npm install -g @github/copilot
npm install -g opencode-ai
npm install -g openclaw@latest
npm install -g codeagents
uv tool install --force llm
uv tool install --force openhands --python 3.12
uv tool install --force --python python3.12 --with pip aider-chat@latest
python3 -m pip install --user --break-system-packages --upgrade codeagents
```

Sources:

- https://help.openai.com/en/articles/11096431
- https://www.npmjs.com/package/@anthropic-ai/claude-code
- https://google-gemini.github.io/gemini-cli/docs/get-started/
- https://docs.github.com/copilot/how-tos/copilot-cli/install-copilot-cli
- https://code-agents.oday-bakkour.com/learn/opencode/01
- https://docs.openhands.dev/openhands/usage/cli/installation
- https://aider.chat/docs/install.html
- https://llm.datasette.io/
- https://docs.openclaw.ai/install/index
- https://pypi.org/project/codeagents/

## MCP and Browser Helpers

```bash
npm install -g @modelcontextprotocol/inspector
npm install -g playwright
npx -y playwright install --with-deps chromium
```

Sources:

- https://modelcontextprotocol.io/docs/tools
- https://playwright.dev/docs/browsers

## Factory: Task Runners

```bash
npm install -g @go-task/cli
cargo install --locked just
```

Sources:

- https://taskfile.dev/docs/installation
- https://github.com/casey/just

## Factory: Security and Supply Chain

```bash
uv tool install semgrep
npm install -g snyk
go install github.com/zricethezav/gitleaks/v8@latest
curl -sSfL https://get.anchore.io/syft | sh -s -- -b /usr/local/bin
curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin
go install github.com/sigstore/cosign/v3/cmd/cosign@latest
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list
apt-get update -y
apt-get install -y trivy
curl -fsSLo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x /usr/local/bin/hadolint
```

Sources:

- https://semgrep.dev/docs/getting-started/cli
- https://docs.snyk.io/developer-tools/snyk-cli/install-or-update-the-snyk-cli/installing-snyk-cli-as-a-binary-using-npm
- https://github.com/gitleaks/gitleaks
- https://oss.anchore.com/docs/installation/
- https://docs.sigstore.dev/cosign/system_config/installation/
- https://trivy.dev/dev/getting-started/installation/
- https://github.com/hadolint/hadolint

## Factory: Tracing

```bash
apt-get install -y bpftrace linux-tools-common linux-tools-generic
```

## Factory: Artifacts

```bash
apt-get install -y httpie pandoc poppler-utils ffmpeg imagemagick tesseract-ocr
```

## Factory: Data and Model Helpers

```bash
uv tool install deepagents-cli
uv tool install dvc
curl -LsSf https://hf.co/cli/install.sh | bash
curl -fsSL https://ollama.com/install.sh | sh
```

Sources:

- https://docs.langchain.com/oss/javascript/deepagents/cli
- https://dvc.org/doc/install/linux
- https://huggingface.co/docs/huggingface_hub/en/guides/cli
- https://docs.ollama.com/linux

## Google Apps Script and Workspace

```bash
npm install -g @google/clasp
npm install -g @googleworkspace/cli
```

Sources:

- https://developers.google.com/apps-script/guides/clasp
- https://github.com/googleworkspace/cli

## Google Cloud CLI

```bash
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update -y
apt-get install -y google-cloud-cli
```

Source: https://docs.cloud.google.com/sdk/docs/install-sdk

## Hetzner Cloud CLI

```bash
go install github.com/hetznercloud/cli/cmd/hcloud@latest
ln -sf "$HOME/go/bin/hcloud" /usr/local/bin/hcloud
```

Source: https://github.com/hetznercloud/cli

## Neon CLI

```bash
npm install -g neonctl
```

Source: https://neon.com/cli

## 1Password CLI

```bash
ARCH="amd64"
OP_VERSION="v$(curl -fsSL https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
curl -fsSLo op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/${OP_VERSION}/op_linux_${ARCH}_${OP_VERSION}.zip"
unzip -o op.zip -d /usr/local/bin/
groupadd -f onepassword-cli
chgrp onepassword-cli /usr/local/bin/op
chmod g+s /usr/local/bin/op
rm op.zip
```

Source: https://www.1password.dev/cli/install-server

## Harness CLI

```bash
curl -fsSL https://raw.githubusercontent.com/harness/harness-cli/v2/install | sh
```

Source: https://developer.harness.io/docs/platform/automation/cli/content/versions/v1/

## Optional Heavy Tools

These are documented but not installed by default.

### Docker

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Source: https://docs.docker.com/engine/install/ubuntu/

### Kubernetes and IaC

```bash
# kubectl: follow the current official Linux binary or apt repository instructions.
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method deb
rm -f install-opentofu.sh
```

Sources:

- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- https://helm.sh/docs/intro/install/
- https://developer.hashicorp.com/terraform/cli/install
- https://opentofu.org/docs/intro/install/deb/

### AWS and Azure

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install --update

curl -sL https://aka.ms/InstallAzureCLIDeb | bash
```

Sources:

- https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
- https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux
