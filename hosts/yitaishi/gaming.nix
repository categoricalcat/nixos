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

    steam.gamescopeSession.enable = true;

    coolercontrol.enable = true;
  };

  services.lact.enable = true;

  services.wivrn = {
    enable = true;
    openFirewall = true;

    autoStart = false;

    highPriority = true;

    steam = {
      enable = true;
      importOXRRuntimes = true;
    };
  };

  environment.systemPackages = with pkgs; [
    (makeDesktopItem {
      name = "wivrn-server-toggle";
      desktopName = "Toggle WiVRn Server";
      exec = "${writeShellScript "toggle-wivrn" ''
        if ${systemd}/bin/systemctl --user is-active --quiet wivrn.service; then
          ${systemd}/bin/systemctl --user stop wivrn.service
          ${libnotify}/bin/notify-send "WiVRn" "Server stopped"
        else
          ${systemd}/bin/systemctl --user start wivrn.service
          ${libnotify}/bin/notify-send "WiVRn" "Server started"
        fi
      ''}";
      icon = "io.github.wivrn.wivrn";
      categories = [
        "Utility"
        "Network"
      ];
    })
  ];
}
