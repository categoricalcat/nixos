# Host identity options.
# Single source of truth for whether a host runs a desktop environment,
# and whether its home-manager profile includes developer tooling.

{ config, ... }:

{
  imports = [ ./options/host.nix ];

  config = {
    serverMode = {
      headless = config.host.desktopEnvironment == null;
      developer = config.host.developer;
      tui = config.host.tui;
    };
  };
}
