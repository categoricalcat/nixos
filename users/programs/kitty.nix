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
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = {
      remember_window_size = "no";
      initial_window_width = "90c";
      initial_window_height = "34c";
      scrollback_lines = 100000;
      shell = "${lib.getExe config.programs.zellij.package} attach -c default";
      window_padding_width = 2;
      font_family = "family='${themeAssets.fonts.monospace.name}' style=Light";
      confirm_os_window_close = 0;
    };
    keybindings = {
      "ctrl+shift+t" = "launch --type=os-window ${lib.getExe config.programs.zellij.package}";
      "ctrl+shift+a" = "launch --type=window ${lib.getExe config.programs.zellij.package}";
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
}
