{ lib, root }:

lib.cleanSourceWith {
  src = root;
  filter = path: type:
    let
      base = baseNameOf path;
    in
    !(lib.elem base [
      ".cache"
      ".direnv"
      ".git"
      "dist"
      "node_modules"
      "result"
      "target"
      "tmp"
    ]);
}
