{ pkgs, ... }:

{

  services = {
    system76-scheduler.settings.cfsProfiles.enable = true;
    thermald.enable = true;
    upower.enable = true;

    thinkfan.enable = true;

    logind = {
      settings = {
        Login = {
          HandleLidSwitch = "suspend-then-hibernate";
          HandleLidSwitchDocked = "suspend-then-hibernate";
          HandleLidSwitchExternalPower = "suspend-then-hibernate";
        };
      };
    };
  };

  boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";

  powerManagement = {
    enable = true;
    powertop.enable = false;
  };

  environment.etc."systemd/sleep.conf".text = ''
    [Sleep]
    HibernateDelaySec=3600
  '';

  systemd.targets = {
    hibernate.enable = true;
    hybrid-sleep.enable = false;
  };

  environment.systemPackages = with pkgs; [
    powertop
    powerstat
  ];
}
