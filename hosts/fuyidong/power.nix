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
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandleLidSwitchExternalPower = "suspend";
      };
    };
  };

  powerManagement = {
    enable = true;
    powertop.enable = false;
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
