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
          mdformat = {
            enable = true;
            plugins = ps: [
              ps.mdformat-gfm
              ps.mdformat-frontmatter
              ps.mdformat-gfm-alerts
            ];
            settings.wrap = "keep";
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
