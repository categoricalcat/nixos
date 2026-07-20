{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkMerge [
    (lib.mkIf (config.desktop.shell == "dms") {
      environment.systemPackages = with pkgs; [
        brightnessctl
      ];
    })
  ];
}
