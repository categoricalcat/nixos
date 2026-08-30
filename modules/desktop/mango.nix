{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "mango") {
    home-manager.users.yi.imports = [
      inputs.mango.hmModules.mango
      inputs.dms.homeModules.dank-material-shell
      ../../users/programs/dms.nix
      ../../users/programs/noctalia
      ../../users/programs/mango.nix
    ];

    environment.systemPackages = with pkgs; [
      wlr-randr
    ];

    programs.mango.enable = true;
  };
}
