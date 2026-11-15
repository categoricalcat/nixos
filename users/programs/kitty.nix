{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
in
{
  config = lib.mkIf (config.host.desktopEnvironment != null) {
    programs.kitty = {
      enable = true;
      package = pkgs.kitty;
      settings = {
        allow_remote_control = "no";
        remember_window_size = "no";
        initial_window_width = "90c";
        initial_window_height = "34c";
        scrollback_lines = 100000;
        window_padding_width = 2;
        font_family = "family='${themeAssets.fonts.monospace.name}' style=Light";
        confirm_os_window_close = 0;
        dynamic_background_opacity = "yes";
      };
      keybindings = {
        "f11" = "toggle_fullscreen";
      };
      shellIntegration.enableZshIntegration = true;
    };

    # fallbackie
    programs.ghostty = {
      enable = true;
      settings = {
        command = "${pkgs.fish}/bin/fish";
      };
    };
  };
}
