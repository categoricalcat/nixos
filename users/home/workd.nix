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

  host = {
    desktopEnvironment = lib.mkDefault null;
    desktopShell = lib.mkDefault null;
    developer = lib.mkDefault true;
    tui = lib.mkDefault true;
    vr = lib.mkDefault false;
  };

  serverMode = {
    headless = lib.mkDefault (config.host.desktopEnvironment == null);
    developer = lib.mkDefault true;
    tui = lib.mkDefault true;
  };

  desktop = {
    keyboard = lib.mkDefault "us";
    monitors = lib.mkDefault [ ];
  };

  home = {
    username = lib.mkDefault "workd";
    homeDirectory = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then "/Users/workd" else "/home/workd"
    );

    packages = lib.optionals config.serverMode.developer (
      with pkgs;
      [
        nodejs_24
      ]
    );
  };
}
