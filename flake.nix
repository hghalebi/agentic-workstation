{
  description = "Reproducible Nix dev shell and validation checks for Agentic Workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          lib = pkgs.lib;

          src = lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                base = baseNameOf path;
              in
              !(lib.elem base [
                ".direnv"
                ".git"
                ".cache"
                "result"
                "target"
                "tmp"
              ]);
          };

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
              lockFile = ./Cargo.lock;
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

          runStaticChecks = ''
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
        in
        {
          packages.agentic-workstation = agenticWorkstation;
          packages.check = checkScript;
          packages.default = agenticWorkstation;

          apps.default = {
            type = "app";
            program = "${agenticWorkstation}/bin/agentic-workstation";
          };

          apps.check = {
            type = "app";
            program = "${checkScript}/bin/agentic-workstation-check";
          };

          apps.docker-smoke = {
            type = "app";
            program = "${dockerSmokeScript}/bin/agentic-workstation-docker-smoke";
          };

          checks.static = pkgs.runCommandNoCC "agentic-workstation-static-checks"
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

          checks.rust-package = agenticWorkstation;

          checks.rustfmt = pkgs.runCommandNoCC "agentic-workstation-rustfmt"
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

          checks.unit = pkgs.runCommandNoCC "agentic-workstation-unit-tests"
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

          devShells.default = pkgs.mkShell {
            packages = checkInputs ++ rustInputs ++ (with pkgs; [
              curl
              fd
              gh
              ripgrep
              wget
            ]);

            shellHook = ''
              export AGENTIC_WORKSTATION_NIX=1
              export PRE_COMMIT_HOME="''${PRE_COMMIT_HOME:-$PWD/.cache/pre-commit}"

              echo "Agentic Workstation Nix shell ready."
              echo "Run: agentic-workstation plan --profile coding-agent --json"
              echo "Run: cargo test"
              echo "Run: nix run .#check"
              echo "Run: nix flake check"
              echo "Run: nix run .#docker-smoke"
            '';
          };
        });
}
