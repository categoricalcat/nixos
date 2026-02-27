{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.dms.nixosModules.greeter
  ];

  config = lib.mkIf (config.desktop.greeter == "dms") {
    environment.systemPackages = with pkgs; [
      polkit_gnome
    ];

    services.accounts-daemon.enable = true;

    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };
}
