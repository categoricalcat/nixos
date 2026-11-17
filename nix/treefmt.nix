# Shared formatter policy. Options merge if a consumer imports this module.
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
          # zsh dotfiles (users/assets/dotfiles/zsh/*.zsh) stay deliberately
          # unformatted: shfmt/shellcheck support bash/POSIX only, not zsh.
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
          yamlfmt = {
            enable = true;
            excludes = [ "secrets/secrets.yaml" ];
            # Default formatter deletes blank lines.
            settings.formatter.retain_line_breaks = true;
          };
          jsonfmt = {
            enable = true;
            # modules/keyboard/vial.vil is JSON; appended to the default *.json.
            includes = [ "*.vil" ];
            excludes = [ "modules/services/monitoring/dashboards/vendor/*" ];
          };
          taplo = {
            enable = true;
            settings.formatting.align_comments = false;
          };
          ruff-format.enable = true;
          # mdformat owns Markdown; yamlfmt owns YAML. Prettier's defaults include both.
          prettier = {
            enable = true;
            includes = lib.mkForce [
              "*.css"
              "*.html"
              "*.js"
              "*.ts"
            ];
          };
        };
        settings.formatter = {
          # Upstream statix program only runs `statix check`; wrap `fix` + `check` for treefmt.
          statix.command = lib.mkForce (
            pkgs.writeShellApplication {
              name = "statix-fix";
              runtimeInputs = [ pkgs.statix ];
              text = ''
                for file in "$@"; do
                  statix fix "$file"
                  statix check "$file"
                done
              '';
            }
          );
          shellharden = {
            command = lib.getExe pkgs.shellharden;
            options = [ "--replace" ];
            includes = [ "*.sh" ];
            excludes = [ ".envrc" ];
            priority = 1;
          };
        };
      };
    };
}
