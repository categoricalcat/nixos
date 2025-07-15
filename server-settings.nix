# Minimal server-specific settings for home server
# Focuses on preventing sleep/suspend and essential server optimizations

{ config, pkgs, lib, ... }:

{
  # Disable sleep, hibernation, suspend, and other power management features
  # Essential for a server that should run 24/7
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Power management settings
  services.logind = {
    # Disable lid switch actions (if server is a laptop)
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";

    # Disable power button and suspend key actions
    extraConfig = ''
      HandlePowerKey=ignore
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
      HandleLidSwitch=ignore
      HandleLidSwitchDocked=ignore
      HandleLidSwitchExternalPower=ignore
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  # Disable power management features
  powerManagement = {
    enable = false;
    cpuFreqGovernor = "performance"; # Keep CPU at maximum performance
  };

  # Automatic SSD maintenance
  services.fstrim = {
    enable = true; # Enable periodic SSD TRIM
    interval = "weekly";
  };

  # Basic system monitoring
  services.smartd = {
    enable = true; # Monitor disk health
    notifications = {
      wall.enable = true; # Display warnings on console
    };
  };

  # Journal size limits to prevent disk filling
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemKeepFree=5G
    MaxRetentionSec=1month
  '';

  # Garbage collection for Nix store
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Disable unnecessary desktop services for servers
  services.avahi.enable = false; # mDNS not needed on servers
  
  # Time synchronization
  services.chrony = {
    enable = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

  # Disable GUI-related power management if present
  services.upower.enable = false;
} 