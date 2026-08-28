{
  lib,
  pkgs,
  config,
  ...
}:

let
  keyboardProfiles = {
    us = {
      layout = "us";
      variant = "intl";
      keyMap = "us-acentos";
      fcitxLayout = "us-intl";
    };
    br = {
      layout = "br";
      variant = "thinkpad";
      keyMap = "br-abnt2";
      fcitxLayout = "br-thinkpad";
    };
  };
  kb = keyboardProfiles.${config.desktop.keyboard};
in
{
  options.desktop = {
    environment = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "niri"
        "cosmic"
      ];
      default =
        if config.host.desktopEnvironment != null then config.host.desktopEnvironment else "gnome";
      description = "Desktop environment to use";
    };

    greeter = lib.mkOption {
      type = lib.types.enum [
        "tuigreet"
        "dms"
        "gdm"
        "ly"
        "none"
      ];
      default =
        if config.desktop.environment == "gnome" then
          "gdm"
        else if config.desktop.environment == "niri" then
          "tuigreet"
        else
          "none";
      description = "Greeter to use";
    };

    shell = lib.mkOption {
      type = lib.types.enum [
        "dms"
        "noctalia"
        "none"
      ];
      default =
        if config.host.desktopShell != null then
          config.host.desktopShell
        else if config.desktop.environment == "niri" then
          "dms"
        else
          "none";
      description = "Desktop shell to run on top of the compositor";
    };

    greeting = lib.mkOption {
      type = lib.types.str;
      default = "turmoil accompanies every great change";
      description = "Greeting text for greeters and display managers that support one.";
    };

  };

  imports = [
    ./options/desktop.nix
    ./stylix.nix
    ./desktop/gnome
    #./desktop/hyprland.nix
    ./desktop/niri.nix
    #./desktop/cosmic.nix
    ./desktop/stylix.nix
    ./desktop/dms.nix
    ./desktop/noctalia.nix
    ./desktop/apps.nix
    ./desktop/web-apps.nix
    ./desktop/greetd.nix
    ./desktop/ly.nix
    ./desktop/valent.nix
  ];

  config = {
    services = {
      # Base audio — all desktop hosts get PipeWire
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      xserver = {
        xkb = {
          inherit (kb) layout variant;
        };
        # Critical for window managers to autostart Fcitx5
        desktopManager.runXdgAutostartIfNone = true;
      };

      libinput.enable = true;
      gnome.gnome-keyring.enable = true;
    };

    security.rtkit.enable = true;

    console.keyMap = kb.keyMap;

    programs = {
      xwayland.enable = true;
      dconf.enable = true;
    };

    environment.systemPackages = lib.optionals (config.desktop.environment != "gnome") [
      pkgs.polkit_gnome
    ];

    systemd.user.services.polkit-gnome-agent = lib.mkIf (config.desktop.environment != "gnome") {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config =
        lib.genAttrs
          [
            "common"
            "gnome"
            "niri"
          ]
          (_: {
            "org.freedesktop.impl.portal.AppChooser" = lib.mkForce [ "gtk" ];
            "org.freedesktop.impl.portal.Access" = lib.mkForce [ ];
          });
    };
  };
}
