#
#   __ _       _                _
#  / _| | __ _| | _____   _ __ (_)_  __
# | |_| |/ _` | |/ / _ \ | '_ \| \ \/ /
# |  _| | (_| |   <  __/_| | | | |>  <
# |_| |_|\__,_|_|\_\___(_)_| |_|_/_/\_\
#
{
  inputs = {
    emacs-src.flake = false;
    emacs-src.url = "git+https://github.com/emacs-mirror/emacs";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      lib = import ./lib { inherit inputs; };
      inherit (lib._) mapModules eachDefaultSystem;
      #inherit (inputs.flake-utils.lib) eachDefaultSystem;

    in
      (eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {};
            overlays = lib.flatten (lib.attrValues overlayModules);
          };

          overlayModules =
            mapModules
              ./overlays
              (o: import o { inherit system inputs pkgs; });
        in
          {
            packages.default = pkgs.emacsGit;
          }
      ));
}
