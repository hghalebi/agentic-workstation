{ nixpkgs, system }:

let
  pkgs = import nixpkgs {
    inherit system;
  };

  src = import ./source.nix {
    inherit (pkgs) lib;
    root = ../.;
  };

  packageModule = import ./packages.nix {
    inherit pkgs src;
  };

  checkModule = import ./checks.nix {
    inherit pkgs src;
    inherit (packageModule) agenticWorkstation checkInputs rustInputs;
  };

  appModule = import ./apps.nix {
    inherit pkgs src;
    inherit (packageModule) agenticWorkstation;
    inherit (checkModule) checkScript dockerSmokeScript e2eScript;
  };

  devShellModule = import ./devshells.nix {
    inherit pkgs;
    inherit (packageModule) agenticWorkstation checkInputs rustInputs;
  };
in
{
  packages = packageModule.packages // {
    check = checkModule.checkScript;
    e2e = checkModule.e2eScript;
  };

  apps = appModule.apps;
  checks = checkModule.checks;
  devShells = devShellModule.devShells;
}
