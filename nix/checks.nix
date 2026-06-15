{ pkgs, src, agenticWorkstation, checkInputs, rustInputs }:

let
  lib = pkgs.lib;

  runStaticChecks = ''
    TMPDIR="''${TMPDIR:-$(mktemp -d)}"
    export TMPDIR
    export HOME="$TMPDIR/home"
    export PRE_COMMIT_HOME="$TMPDIR/pre-commit"
    mkdir -p "$HOME" "$PRE_COMMIT_HOME"

    bash -n install-agentic-tools.sh scripts/*.sh cloud/*.sh
    shellcheck install-agentic-tools.sh scripts/*.sh cloud/*.sh
    shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh cloud/*.sh
    actionlint
    yamllint .
    bash scripts/verify-lockfile.sh
  '';

  checkScript = pkgs.writeShellApplication {
    name = "agentic-workstation-check";
    runtimeInputs = checkInputs;
    text = ''
      set -euo pipefail
      ${runStaticChecks}
      bats tests/unit
    '';
  };

  dockerSmokeScript = pkgs.writeShellApplication {
    name = "agentic-workstation-docker-smoke";
    runtimeInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.docker ];
    text = ''
      set -euo pipefail

      if ! command -v docker >/dev/null 2>&1; then
        echo "docker is required for smoke tests" >&2
        exit 1
      fi

      docker build -f tests/Dockerfile.ubuntu-22.04 .
      docker build -f tests/Dockerfile.ubuntu-24.04 .
    '';
  };

  e2eScript = pkgs.writeShellApplication {
    name = "agentic-workstation-e2e";
    runtimeInputs = checkInputs ++ (with pkgs; [
      curl
      gnutar
      nix
    ]);
    text = ''
      set -euo pipefail
      exec bash ${src}/scripts/e2e-nix.sh "$@"
    '';
  };
in
{
  inherit checkScript dockerSmokeScript e2eScript runStaticChecks;

  checks = {
    static = pkgs.runCommand "agentic-workstation-static-checks"
      {
        nativeBuildInputs = checkInputs;
      }
      ''
        cp -R ${src} repo
        chmod -R u+w repo
        cd repo

        ${runStaticChecks}

        touch $out
      '';

    rust-package = agenticWorkstation;

    rustfmt = pkgs.runCommand "agentic-workstation-rustfmt"
      {
        nativeBuildInputs = rustInputs;
      }
      ''
        cp -R ${src} repo
        chmod -R u+w repo
        cd repo

        cargo fmt --check

        touch $out
      '';

    unit = pkgs.runCommand "agentic-workstation-unit-tests"
      {
        nativeBuildInputs = checkInputs;
      }
      ''
        cp -R ${src} repo
        chmod -R u+w repo
        cd repo

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"

        bats tests/unit

        touch $out
      '';
  };
}
