# Server mode configuration
# This module allows toggling between desktop and headless server modes

{ config, pkgs, lib, ... }:

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
    services.xserver.enable = lib.mkForce false;
    services.xserver.displayManager.gdm.enable = lib.mkForce false;
    services.xserver.desktopManager.gnome.enable = lib.mkForce false;
    
    # Disable auto-login
    services.displayManager.autoLogin.enable = lib.mkForce false;
    
    # Boot to multi-user target instead of graphical
    systemd.defaultUnit = lib.mkForce "multi-user.target";
    
    # Minimal TTY configuration
    services.logind.extraConfig = lib.mkForce ''
      NAutoVTs=2
      ReserveVT=0
    '';
  };
} 