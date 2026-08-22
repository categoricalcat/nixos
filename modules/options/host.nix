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

    tui = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include terminal UI and productivity tools (starship, tmux, zellij, btop, fzf, zoxide, yazi, etc.)";
    };

    vr = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Host can run VR (SteamVR/OpenXR)";
    };
  };
}
