{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ../../modules/options/host.nix
    ../../modules/options/server-mode.nix
    ../../modules/options/desktop.nix
    ./common.nix
  ];

  home = {
    username = "workd";
    homeDirectory = "/home/workd";

    packages = lib.optionals config.serverMode.developer (
      with pkgs;
      [
        nodejs_24
      ]
    );
  };
}
