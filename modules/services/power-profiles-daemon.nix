{
  pkgs,
  ...
}:

{
  services.power-profiles-daemon.enable = true;
  services.tlp.enable = false;

  systemd.services.battery-charge-threshold = {
    description = "Set ThinkPad Battery Charge Thresholds";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    startLimitBurst = 0;
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      # "start_threshold" ensures it doesn't micro-charge if it drops to 79%.
      ExecStart = pkgs.writeShellScript "set-battery-thresholds" ''
        # Stop charging at 80%
        echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold

        # Start charging only if below 75%
        echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold
      '';
    };
  };

  # Automatically switch power profiles on AC/Battery
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"
  '';
}
