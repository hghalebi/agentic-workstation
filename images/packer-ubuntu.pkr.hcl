packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

variable "profile" {
  type    = string
  default = "base-image"
}

# Template stub for local Ubuntu image builds. Fill in ISO, checksum, and boot
# automation for the Ubuntu release you want to bake.
source "qemu" "ubuntu" {
  disk_size    = "20000M"
  memory       = 4096
  cpus         = 2
  accelerator  = "kvm"
  headless     = true
  ssh_username = "ubuntu"
}

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y git curl ca-certificates",
      "git clone https://github.com/hghalebi/agentic-workstation.git /tmp/agentic-workstation",
      "cd /tmp/agentic-workstation && sudo ./install-agentic-tools.sh --profile ${var.profile} --resume",
      "cd /tmp/agentic-workstation && ./scripts/prepare-snapshot.sh"
    ]
  }
}
