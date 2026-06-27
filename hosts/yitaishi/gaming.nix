{
  pkgs,
  config,
  lib,
  ...
}:
let
  systemctl = "${config.systemd.package}/bin/systemctl";

  servicesToToggle = [
    "coolercontrold.service"
    "lactd.service"
  ];

  extensionsToToggle = [
    pkgs.gnomeExtensions.vitals.extensionUuid
  ];
in
{
  hardware.fanatec.enable = true;

  security.sudo.extraRules = [
    {
      users = [ "yi" ];
      commands = lib.concatMap (svc: [
        {
          command = "${systemctl} stop ${svc}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${systemctl} start ${svc}";
          options = [ "NOPASSWD" ];
        }
      ]) servicesToToggle;
    }
  ];

  programs = {
    gamemode.settings = {
      custom = {
        start = "${pkgs.writeShellScript "gamemode-start" ''
          ${lib.concatMapStringsSep "\n" (
            svc: "/run/wrappers/bin/sudo ${systemctl} stop ${svc} || true"
          ) servicesToToggle}
          ${lib.concatMapStringsSep "\n" (
            ext: "/run/current-system/sw/bin/gnome-extensions disable ${ext} || true"
          ) extensionsToToggle}
        ''}";
        end = "${pkgs.writeShellScript "gamemode-end" ''
          ${lib.concatMapStringsSep "\n" (
            svc: "/run/wrappers/bin/sudo ${systemctl} start ${svc} || true"
          ) servicesToToggle}
          ${lib.concatMapStringsSep "\n" (
            ext: "/run/current-system/sw/bin/gnome-extensions enable ${ext} || true"
          ) extensionsToToggle}
        ''}";
      };
    };

    # Enable gamescope micro-compositor for better AMD performance
    steam.gamescopeSession.enable = true;

    # CoolerControl
    # A modern GUI daemon for viewing and controlling system temperatures and cooling devices.
    coolercontrol.enable = true;
  };

  # Linux AMDGPU Controller (LACT)
  # A daemon and GUI for managing AMD Radeon GPUs on Linux.
  services.lact.enable = true;

  # AMDGPU overdrive is enabled in ./graphics.nix so LACT can control voltage,
  # clocks, and power limits.
}
