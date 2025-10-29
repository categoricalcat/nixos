_:

{

  services.auto-cpufreq.enable = false;
  services.system76-scheduler.settings.cfsProfiles.enable = true; # Better scheduling for CPU cycles - thanks System76!!!
  services.thermald.enable = true; # Enable thermald, the temperature management daemon. (only necessary if on Intel CPUs)
  services.power-profiles-daemon.enable = false; # Disable GNOMEs power management

  # Systemd-logind lid switch handling
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandleLidSwitchExternalPower = "suspend";
      };
    };
  };

  powerManagement = {
    enable = true;
  };


  systemd.targets = {
    hibernate.enable = true;
    hybrid-sleep.enable = false;
  };
}
