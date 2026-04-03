{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.dms.nixosModules.greeter
  ];

  config = lib.mkIf (config.desktop.greeter == "dms") {
    services.accounts-daemon.enable = true;

    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };
}
