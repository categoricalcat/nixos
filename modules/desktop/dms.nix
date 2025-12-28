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

  config = lib.mkIf (config.desktop.environment == "niri") {
    programs.dank-material-shell.greeter = {
      enable = false;
      compositor.name = "niri";
    };
  };
}
