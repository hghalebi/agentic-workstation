packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.4.0"
    }
  }
}

variable "profile" {
  type    = string
  default = "base-image"
}

source "hcloud" "agentic" {
  image       = "ubuntu-24.04"
  location    = "fsn1"
  server_type = "cx32"
  ssh_keys    = []
}

build {
  sources = ["source.hcloud.agentic"]

  provisioner "shell" {
    inline = [
      "apt-get update -y",
      "apt-get install -y git curl ca-certificates",
      "git clone https://github.com/hghalebi/agentic-workstation.git /opt/agentic-workstation",
      "cd /opt/agentic-workstation && ./install-agentic-tools.sh --profile ${var.profile} --resume",
      "cd /opt/agentic-workstation && ./scripts/prepare-snapshot.sh"
    ]
  }
}
