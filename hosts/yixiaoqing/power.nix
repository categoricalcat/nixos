{ pkgs, ... }:

{

  services.system76-scheduler.settings.cfsProfiles.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;

  services.thinkfan.enable = true;
  boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";

  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchDocked = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend-then-hibernate";
      };
    };
  };

  powerManagement = {
    enable = true;
    powertop.enable = false;
  };

  systemd.sleep.settings = {
    Sleep = {
      HibernateDelaySec = "3600";
    };
  };

  systemd.targets = {
    hibernate.enable = true;
    hybrid-sleep.enable = false;
  };

  environment.systemPackages = with pkgs; [
    powertop
    powerstat
  ];
}
