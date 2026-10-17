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

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "yi") {
        var unit = action.lookup("unit");
        if (unit == "coolercontrold.service" || unit == "lactd.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';

  programs = {

    gamemode.settings = {
      custom = {
        start = "${pkgs.writeShellScript "gamemode-start" ''
          ${lib.concatMapStringsSep "\n" (svc: "${systemctl} stop ${svc} || true") servicesToToggle}
          ${lib.concatMapStringsSep "\n" (
            ext: "/run/current-system/sw/bin/gnome-extensions disable ${ext} || true"
          ) extensionsToToggle}
        ''}";
        end = "${pkgs.writeShellScript "gamemode-end" ''
          ${lib.concatMapStringsSep "\n" (svc: "${systemctl} start ${svc} || true") servicesToToggle}
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
    android-tools
  ];
}
