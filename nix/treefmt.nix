{ inputs, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      unstable = import ../modules/nixpkgs-unstable.nix {
        inherit inputs pkgs;
      };
    in
    {
      treefmt = {
        projectRootFile = "flake.nix";
        package = unstable.treefmt;
        programs = {
          nixfmt = {
            enable = true;
            package = unstable.nixfmt;
          };
          statix = {
            enable = true;
            package = unstable.statix;
          };
          deadnix = {
            enable = true;
            package = unstable.deadnix;
          };
        };
      };
    };
}
