{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  themeAssets = import ../theme-assets.nix { inherit inputs pkgs; };
in
{
  # Stylix shared configuration for Niri and GNOME
  config = lib.mkIf (config.desktop.environment == "niri" || config.desktop.environment == "gnome") {
    stylix = {
      enable = true;
      image = ./wallpaper.jpg;
      polarity = "dark";
      autoEnable = true;

      inherit (themeAssets) cursor;

      icons = themeAssets.icons // {
        enable = true;
      };

      fonts = {
        inherit (themeAssets.fonts)
          serif
          sansSerif
          monospace
          emoji
          sizes
          ;
      };

      # Catppuccin Mocha (Base16 mapping)
      # base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      base16Scheme = import ../theme.nix;

      targets = {
        gtk = {
          enable = true;
        };

        # Enable GNOME integration when GNOME is selected
        gnome.enable = config.desktop.environment == "gnome";
        qt = {
          enable = true;
          platform = lib.mkForce "qtct";
        };

        grub = {
          enable = true;
          useWallpaper = true;
        };

        plymouth = {
          enable = true;
          # logo = ./wallpaper.png;
          logoAnimated = true;
        };
      };
    };

    # Wayland/Electron ozone for Wayland sessions
    environment = {
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        QT_QPA_PLATFORM = "wayland";
        # Remove QT_QPA_PLATFORMTHEME here to avoid conflicting env.variables
      };
      variables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
      systemPackages = with pkgs; [
        qt6Packages.qt6ct
      ];
    };
  };
}
