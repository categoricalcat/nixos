{
  system,
  nixpkgs,
  treefmt-nix,
}:

let
  pkgs = import nixpkgs { inherit system; };
  treefmtEval = treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";
    programs = {
      nixfmt = {
        enable = true;
        package = pkgs.nixfmt;
      };
      statix.enable = true;
      deadnix.enable = true;
    };
  };
in
treefmtEval.config.build.wrapper
