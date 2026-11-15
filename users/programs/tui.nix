{
  pkgs,
  config,
  lib,
  ...
}:
let
  colors = import ../../modules/theme.nix;
  starshipToml =
    builtins.replaceStrings
      [
        "@base03@"
        "@base08@"
        "@base09@"
        "@base0A@"
        "@base0B@"
        "@base0D@"
        "@base0E@"
      ]
      [
        colors.base03
        colors.base08
        colors.base09
        colors.base0A
        colors.base0B
        colors.base0D
        colors.base0E
      ]
      (builtins.readFile ../assets/dotfiles/starship.toml);
in
{
  config = lib.mkIf config.serverMode.tui {
    programs = {
      mcfly = {
        enable = true;
        package = pkgs.mcfly;
      };

      atuin = {
        enable = true;
        package = pkgs.atuin;
      };

      yazi = {
        enable = true;
        package = pkgs.yazi;
      };

      broot = {
        enable = true;
        package = pkgs.broot;
      };

      lazygit = {
        enable = true;
        package = pkgs.lazygit;
        settings = {
          git = {
            diffRenderers = [
              {
                command = "${pkgs.delta}/bin/delta --dark --paging=never --diff-so-fancy";
                colorArg = "always";
              }
            ];
          };
        };
      };

      gitui = {
        enable = true;
        package = pkgs.gitui;
      };

      bottom = {
        enable = true;
        package = pkgs.bottom;
      };

      zellij =
        let
          themeAssets = import ../../modules/theme-assets.nix { inherit pkgs; };
          terminalOpacity =
            if config ? stylix && config.stylix ? opacity then
              config.stylix.opacity.terminal
            else
              themeAssets.terminalOpacity;
          hex = name: "#${colors.${name}}";
        in
        {
          enable = true;
          package =
            if config.host.desktopEnvironment != null then
              pkgs.callPackage ../../packages/zellij-desktop.nix { }
            else
              pkgs.zellij;
          settings = {
            on_force_close = "quit";
            # Stylix writes themes/stylix.kdl under the "default" block name.
            theme = "default";
            explicit_theme_hue = "dark";
            default_mode = "locked";
            keybinds._props.preset = "unlock-first";
            show_startup_tips = false;
            show_release_notes = false;
            pane_frames = false;
            ui.pane_frames.hide_session_name = true;
            serialize_pane_viewport = true;

            terminal = {
              font = themeAssets.fonts.monospace.name;
              font_size = themeAssets.fonts.sizes.terminal;
              opacity = terminalOpacity;
              padding = 2;
              theme = {
                foreground = hex "base05";
                background = hex "base00";
                cursor = hex "base05";
                black = hex "base00";
                red = hex "base08";
                green = hex "base0B";
                yellow = hex "base0A";
                blue = hex "base0D";
                magenta = hex "base0E";
                cyan = hex "base0C";
                white = hex "base05";
                bright_black = hex "base03";
                bright_red = hex "base08";
                bright_green = hex "base0B";
                bright_yellow = hex "base0A";
                bright_blue = hex "base0D";
                bright_magenta = hex "base0E";
                bright_cyan = hex "base0C";
                bright_white = hex "base07";
              };
            };

            attention.track_commands = true;
          };
        };

      btop = {
        enable = true;
        package =
          if (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64) then
            pkgs.btop.override { rocmSupport = true; }
          else
            pkgs.btop;
        settings = {
          update_ms = 300;
        };
      };

      tmux = {
        enable = true;
        package = pkgs.tmux;
      };

      fzf = {
        enable = true;
        package = pkgs.fzf;
        historyWidget.command = "";
      };

      zoxide = {
        enable = true;
        package = pkgs.zoxide;
      };

      direnv = {
        enable = true;
        package = pkgs.direnv;
        nix-direnv.enable = true;
        nix-direnv.package = pkgs.nix-direnv;
      };

      starship = {
        enable = true;
        settings = fromTOML starshipToml;
      };
    };

    home.file."${config.xdg.configHome}/starship.toml".force = true;

  };
}
