{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # inputs.dms.nixosModules.greeter
  ];

  config = lib.mkIf (config.desktop.environment == "niri") {
    environment.systemPackages = with pkgs; [
      polkit_gnome
    ];

    services.accounts-daemon.enable = true;

    #programs.dank-material-shell.greeter = {
    #  enable = false;
    #  compositor.name = "niri";
    #};
  };
}
