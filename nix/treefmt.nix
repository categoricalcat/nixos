{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        package = pkgs.treefmt;
        programs = {
          deadnix = {
            enable = true;
            package = pkgs.deadnix;
            priority = 1;
          };
          nixf-diagnose = {
            enable = true;
            package = pkgs.nixf-diagnose;
            priority = 2;
          };
          statix = {
            enable = true;
            package = pkgs.statix;
            priority = 3;
          };
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
            priority = 4;
          };
          shfmt = {
            enable = true;
            indent_size = 2;
            priority = 2;
          };
          shellcheck = {
            enable = true;
            priority = 3;
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
        settings.formatter = {
          statix.command = lib.mkForce (
            pkgs.writeShellScriptBin "statix-fix" ''
              set -euo pipefail
              for file in "$@"; do
                ${lib.getExe pkgs.statix} fix "$file"
                ${lib.getExe pkgs.statix} check "$file"
              done
            ''
          );
          shellharden = {
            command = "${pkgs.shellharden}/bin/shellharden";
            options = [ "--replace" ];
            includes = [ "*.sh" ];
            excludes = [ ".envrc" ];
            priority = 1;
          };
        };
      };
    };
}
