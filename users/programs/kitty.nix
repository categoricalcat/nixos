{
  pkgs,
  inputs,
  ...
}:
let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
  zellijStart = pkgs.writeShellScriptBin "zellij-start" ''
    if [ -n "$ZELLIJ" ]; then
      exec ''${SHELL:-zsh}
    fi
    exec ${pkgs.zellij}/bin/zellij
  '';
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
      shell = "${zellijStart}/bin/zellij-start";
      window_padding_width = 2;
      font_family = "family='${themeAssets.fonts.monospace.name}' style=Light";
      confirm_os_window_close = 0;
    };
    keybindings = {
      "ctrl+shift+t" = "new_os_window";
      "f11" = "toggle_fullscreen";
    };
    shellIntegration.enableZshIntegration = true;
  };

  programs.alacritty.enable = true;
}
