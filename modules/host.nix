# Host identity options.
# Single source of truth for whether a host runs a desktop environment,
# and whether its home-manager profile includes developer tooling.

{ config, lib, ... }:

{
  options.host = {
    desktopEnvironment = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "gnome"
          "niri"
        ]
      );
      default = null;
      description = "Desktop environment. null means headless.";
    };

    desktopShell = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "dms"
          "noctalia"
          "none"
        ]
      );
      default = if config.host.desktopEnvironment == "niri" then "dms" else null;
      description = "Desktop shell running on top of the compositor.";
    };

    developer = lib.mkOption {
      type = lib.types.bool;
      default = config.host.desktopEnvironment != null;
      description = "Include developer tooling in the home-manager profile";
    };

    vr = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Host can run VR (SteamVR/OpenXR)";
    };
  };

  config = {
    serverMode.headless = config.host.desktopEnvironment == null;
    serverMode.developer = config.host.developer;
  };
}
