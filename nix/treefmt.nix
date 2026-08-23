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
          shfmt = {
            enable = true;
            indent_size = 2;
          };
          shellcheck = {
            enable = true;
          };
        };
        settings.formatter.shellharden = {
          command = "${pkgs.shellharden}/bin/shellharden";
          options = [ "--replace" ];
          includes = [ "*.sh" ];
          excludes = [ ".envrc" ];
        };
      };
    };
}
