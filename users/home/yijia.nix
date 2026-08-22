{ config, ... }:

{
  imports = [
    ./yi.nix
  ];

  host = {
    desktopEnvironment = null;
    desktopShell = null;
    developer = true;
    tui = true;
    vr = false;
  };

  serverMode.headless = config.host.desktopEnvironment == null;
  desktop.keyboard = "us";
  desktop.monitors = [ ];
}
