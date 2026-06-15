{ pkgs, agenticWorkstation, checkInputs, rustInputs }:

let
  commonPackages = checkInputs ++ rustInputs ++ (with pkgs; [
    curl
    fd
    gh
    just
    ripgrep
    wget
  ]);

  mkAgenticShell = { name, packages, nextSteps }:
    pkgs.mkShell {
      packages = packages ++ [ agenticWorkstation ];

      shellHook = ''
        export AGENTIC_WORKSTATION_NIX=1
        export AGENTIC_WORKSTATION_PROFILE="${name}"
        export PRE_COMMIT_HOME="''${PRE_COMMIT_HOME:-$PWD/.cache/pre-commit}"

        echo "Agentic Workstation ${name} Nix shell ready."
        ${builtins.concatStringsSep "\n" (map (step: "echo \"Run: ${step}\"") nextSteps)}
      '';
    };

  minimalShell = mkAgenticShell {
    name = "minimal";
    packages = with pkgs; [
      bash
      git
      jq
      shellcheck
      shfmt
    ];
    nextSteps = [
      "agentic-workstation plan --profile minimal --json"
      "nix run .#check"
    ];
  };

  codingAgentShell = mkAgenticShell {
    name = "coding-agent";
    packages = commonPackages;
    nextSteps = [
      "agentic-workstation plan --profile coding-agent --json"
      "cargo test"
      "nix run .#check"
      "nix run .#e2e"
    ];
  };

  securityShell = mkAgenticShell {
    name = "security";
    packages = commonPackages ++ (with pkgs; [
      cosign
      gitleaks
      grype
      hadolint
      syft
      trivy
    ]);
    nextSteps = [
      "agentic-workstation plan --profile security --json"
      "gitleaks detect --source . --no-git --redact --verbose"
      "nix run .#check"
    ];
  };

  factoryShell = mkAgenticShell {
    name = "factory";
    packages = commonPackages ++ (with pkgs; [
      age
      duf
      go-task
      hyperfine
      postgresql
      redis
      sqlite
      tree
    ]);
    nextSteps = [
      "agentic-workstation plan --profile factory --json"
      "just check"
      "nix run .#docker-smoke"
    ];
  };
in
{
  devShells = {
    coding-agent = codingAgentShell;
    default = codingAgentShell;
    factory = factoryShell;
    minimal = minimalShell;
    security = securityShell;
  };
}
