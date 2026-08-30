{
  pkgs,
  lib,
  config,
  ...
}:

{
  # Desktop-only stylix targets for Niri, Mango, and GNOME
  config =
    lib.mkIf
      (lib.elem config.desktop.environment [
        "niri"
        "gnome"
        "mango"
      ])
      {
        stylix.targets = {
          gtk.enable = true;

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
            logoAnimated = true;
          };
        };

        environment = {
          sessionVariables = {
            NIXOS_OZONE_WL = "1";
            ELECTRON_OZONE_PLATFORM_HINT = "wayland";
            QT_QPA_PLATFORM = "wayland";
          };
          variables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
          systemPackages = with pkgs; [
            qt6Packages.qt6ct
          ];
        };
      };
}
