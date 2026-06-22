{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.dms.nixosModules.greeter
  ];

  config = lib.mkMerge [
    (lib.mkIf (config.desktop.greeter == "dms") {
      services.accounts-daemon.enable = true;

      programs.dank-material-shell.greeter = {
        enable = true;
        compositor.name = "niri";
      };
    })
    (lib.mkIf (config.desktop.shell == "dms") {
      environment.systemPackages = with pkgs; [
        brightnessctl
      ];
    })
  ];
}
