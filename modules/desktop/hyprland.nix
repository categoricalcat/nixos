{
  lib,
  config,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "hyprland") {
    programs.hyprland.enable = true;

    services.displayManager = {
      gdm.enable = true;
    };

    environment.systemPackages = with pkgs; [
      waybar
      mako
      fuzzel
    ];
  };
}
