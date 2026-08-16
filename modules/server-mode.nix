# Server mode configuration
# This module allows toggling between desktop and headless server modes

{ config, lib, ... }:

let
  cfg = config.serverMode;
in
{
  options.serverMode = {
    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable headless server mode (disables GUI)";
    };
    developer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include developer tooling in the home-manager profile on headless hosts";
    };
    tui = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include terminal UI and productivity tools";
    };
  };

  config = lib.mkIf cfg.headless {
    # Disable GUI services when in headless mode
    services = {
      xserver.enable = lib.mkForce false;
      displayManager = {
        gdm.enable = lib.mkForce false;
        # Disable auto-login
        autoLogin.enable = lib.mkForce false;
      };
      desktopManager.gnome.enable = lib.mkForce false;
    };

    # Boot to multi-user target instead of graphical
    systemd.defaultUnit = lib.mkForce "multi-user.target";
  };
}
