{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.desktop.shell == "noctalia") {
    environment.systemPackages = with pkgs; [
      brightnessctl
      cliphist
    ];
  };
}
