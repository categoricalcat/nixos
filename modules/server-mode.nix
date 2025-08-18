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
      # Minimal TTY configuration
      logind.extraConfig = lib.mkForce ''
        NAutoVTs=2
        ReserveVT=0
      '';
    };

    # Boot to multi-user target instead of graphical
    systemd.defaultUnit = lib.mkForce "multi-user.target";
  };
}
