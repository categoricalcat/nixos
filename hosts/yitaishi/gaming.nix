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
    adb.enable = true;

    alvr = {
      enable = true;
      openFirewall = true;
    };

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

    steam.gamescopeSession.enable = true;

    coolercontrol.enable = true;
  };

  services.lact.enable = true;

  # disabled in favor of ALVR
  services.wivrn.enable = false;

  environment.systemPackages = with pkgs; [
  ];
}
