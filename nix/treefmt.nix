_: {
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        package = pkgs.treefmt;
        programs = {
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          statix = {
            enable = true;
            package = pkgs.statix;
          };
          deadnix = {
            enable = true;
            package = pkgs.deadnix;
          };
        };
      };
    };
}
