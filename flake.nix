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
                "result"
              ]);
          };

          checkInputs = with pkgs; [
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
          packages.default = checkScript;

          apps.default = {
            type = "app";
            program = "${checkScript}/bin/agentic-workstation-check";
          };

          apps.check = self.apps.${system}.default;

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
            packages = checkInputs ++ (with pkgs; [
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
              echo "Run: nix run .#check"
              echo "Run: nix flake check"
              echo "Run: nix run .#docker-smoke"
            '';
          };
        });
}
