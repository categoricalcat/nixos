# Minimal server-specific settings for home server
# Focuses on preventing sleep/suspend and essential server optimizations

{ config, lib, ... }:

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
  services = {
    logind = {
      # Disable lid switch actions (if server is a laptop)
      settings = {
        Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "ignore";
        };
      };
    };
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };

  # Automatic SSD maintenance
  services.fstrim = {
    enable = true; # Enable periodic SSD TRIM
    interval = "weekly";
  };

  # Basic system monitoring
  services.smartd = {
    enable = !(config.wsl.enable or false); # Monitor disk health
    notifications = {
      wall.enable = true; # Display warnings on console
    };
  };

  # Journal size limits to prevent disk filling
  services.journald.settings = {
    Journal = {
      Storage = "persistent";
      SystemMaxUse = "800M";
      SystemMaxFileSize = "50M";
      SystemKeepFree = "1G";
      MaxRetentionSec = "7day";
      RateLimitIntervalSec = "100ms";
      RateLimitBurst = 5000;
      Compress = "yes";
    };
  };

  # Override gc retention for servers (longer than default 9d)
  nix.gc.options = lib.mkForce "--delete-older-than 30d";

  # Disable GUI-related power management if present
  services.upower.enable = lib.mkForce false;

  # Headless servers do not need audio hardware, daemons, or sound targets
  xdg.sounds.enable = false;
  systemd.targets.sound.enable = false;
  services.pipewire.enable = lib.mkForce false;
  services.pulseaudio.enable = lib.mkForce false;
  hardware.alsa.enable = lib.mkForce false;

  boot.blacklistedKernelModules = [
    # Sound / ALSA core and controller modules
    "snd"
    "soundcore"
    "snd_pcm"
    "snd_timer"
    "snd_hda_intel"
    "snd_hda_codec"
    "snd_soc_core"
  ];
}
