{
  pkgs,
  lib,
  config,
  ...
}:

{
  # Stylix shared configuration for both Niri and GNOME
  config = lib.mkIf (config.desktop.environment == "niri" || config.desktop.environment == "gnome") {
    stylix.enable = true;
    stylix.image = null;
    stylix.polarity = "dark";

    stylix.fonts = {
      serif = {
        package = pkgs.maple-mono.NF-CN-unhinted;
        name = "Maple Mono NF CN";
      };
      sansSerif = {
        package = pkgs.maple-mono.NF-CN-unhinted;
        name = "Maple Mono NF CN";
      };
      monospace = {
        package = pkgs.maple-mono.NF-CN-unhinted;
        name = "Maple Mono NF CN";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    # Catppuccin Mocha (Base16 mapping)
    # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    stylix.base16Scheme = {
      base00 = "0a0a10"; # base
      base01 = "14141f"; # mantle
      base02 = "20212c"; # surface0
      base03 = "2c2e3a"; # surface1
      base04 = "383a47"; # surface2
      base05 = "cdd6f4"; # text
      base06 = "f5e0dc"; # rosewater
      base07 = "b4befe"; # lavender
      base08 = "f38ba8"; # red
      base09 = "fab387"; # peach
      base0A = "f9e2af"; # yellow
      base0B = "a6e3a1"; # green
      base0C = "94e2d5"; # teal
      base0D = "89b4fa"; # blue
      base0E = "cba6f7"; # mauve
      base0F = "f2cdcd"; # flamingo
    };

    stylix.targets = {
      gtk = {
        enable = true;
      };

      # Enable GNOME integration when GNOME is selected
      gnome.enable = config.desktop.environment == "gnome";
      qt = {
        enable = true;
        platform = lib.mkForce "qtct";
      };
    };

    # Wayland/Electron ozone for Wayland sessions
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
