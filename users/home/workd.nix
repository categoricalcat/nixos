{
  pkgs,
  lib,
  developer ? false,
  ...
}:

{
  imports = [ ./common.nix ];

  home = {
    username = "workd";
    homeDirectory = "/home/workd";

    packages = lib.optionals developer (
      with pkgs;
      [
        nodejs_24
      ]
    );
  };
}
