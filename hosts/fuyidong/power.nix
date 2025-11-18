{ pkgs, ... }:

{

  # services.auto-cpufreq.enable = true;
  services.system76-scheduler.settings.cfsProfiles.enable = true; # Better scheduling for CPU cycles - thanks System76!!!
  services.thermald.enable = true; # Enable thermald, the temperature management daemon. (only necessary if on Intel CPUs)
  services.power-profiles-daemon.enable = false;
  services.upower.enable = true;

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
    powertop.enable = true;
  };

  systemd.targets = {
    hibernate.enable = true;
    hybrid-sleep.enable = false;
  };

  environment.systemPackages = with pkgs; [
    powertop
    powerstat
  ];

  systemd.services.powertop-autotune = {
    description = "PowerTOP auto-tune";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
    };
  };
}
