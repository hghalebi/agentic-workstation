{
  description = "Reproducible Nix dev shells, packages, and validation checks for Agentic Workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        import ./nix {
          inherit nixpkgs system;
        });
}
