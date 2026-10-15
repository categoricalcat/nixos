{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.desktop.shell == "noctalia") {
    services.accounts-daemon.enable = true;
    services.upower.enable = true;

    environment.systemPackages = with pkgs; [
      brightnessctl
      cliphist
    ];
  };
}
