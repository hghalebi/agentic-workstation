{ pkgs, src }:

let
  rustInputs = with pkgs; [
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt
  ];

  agenticWorkstation = pkgs.rustPlatform.buildRustPackage {
    pname = "agentic-workstation";
    version = "0.1.0";

    inherit src;

    cargoLock = {
      lockFile = ../Cargo.lock;
    };
  };

  checkInputs = with pkgs; [
    agenticWorkstation
    actionlint
    bash
    bats
    git
    jq
    pre-commit
    shellcheck
    shfmt
    yamllint
  ];
in
{
  inherit agenticWorkstation checkInputs rustInputs;

  packages = {
    agentic-workstation = agenticWorkstation;
    default = agenticWorkstation;
  };
}
