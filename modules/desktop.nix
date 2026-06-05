{
  lib,
  pkgs,
  config,
  ...
}:

{
  options = {
    desktop.environment = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "niri"
        "cosmic"
      ];
      default = "gnome";
      description = "Desktop environment to use";
    };

    desktop.greeter = lib.mkOption {
      type = lib.types.enum [
        "tuigreet"
        "dms"
        "gdm"
        "regreet"
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

    desktop.shell = lib.mkOption {
      type = lib.types.enum [
        "dms"
        "noctalia"
        "none"
      ];
      default = if config.desktop.environment == "niri" then "dms" else "none";
      description = "Desktop shell to run on top of the compositor";
    };

    desktop.greeting = lib.mkOption {
      type = lib.types.str;
      default = "turmoil accompanies every great change";
      description = "Greeting text for greeters and display managers that support one.";
    };

    desktop.monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Monitor list. Currently, for dash-to-panel.

        useful:
        dconf read /org/gnome/shell/extensions/dash-to-panel/panel-sizes
        awk -F'[<>]' '/<vendor>/{v=$3} /<product>/{print "\"" v "-" $3 "\""}' ~/.config/monitors.xml | sort -u
      '';
    };
  };

  imports = [
    ./desktop/gnome.nix
    ./desktop/hyprland.nix
    ./desktop/niri.nix
    ./desktop/cosmic.nix
    ./desktop/stylix.nix
    ./desktop/dms.nix
    ./desktop/noctalia.nix
    ./desktop/regreet.nix
    ./desktop/apps.nix
    ./desktop/greetd.nix
    ./desktop/ly.nix
  ];

  config = {
    # Base audio — all desktop hosts get PipeWire
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    programs = {
      xwayland.enable = true;
      dconf.enable = true;
    };

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5.addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
      ];

      fcitx5.settings = {
        globalOptions.Hotkey = {
          TriggerKeys = "Control+Shift+space";
          EnumerateForwardKeys = "";
          EnumerateBackwardKeys = "";
          EnumerateGroupForwardKeys = "";
          EnumerateGroupBackwardKeys = "";
          EnumerateSkipFirst = false;
        };

        inputMethod =
          let
            kbLayout = if config.desktop.environment == "gnome" then "us-intl" else "br";
            kbIM = "keyboard-${kbLayout}";
          in
          {
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = kbLayout;
              DefaultIM = kbIM;
            };
            "Groups/0/Items/0" = {
              Name = kbIM;
              Layout = "";
            };
            "Groups/0/Items/1" = {
              Name = "pinyin";
              Layout = "";
            };
            GroupOrder."0" = "Default";
          };
      };
    };

    # Critical for window managers to autostart Fcitx5
    services.xserver.desktopManager.runXdgAutostartIfNone = true;

    services.libinput.enable = true;
    services.gnome.gnome-keyring.enable = true;

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "floorp.desktop" ];
        "x-scheme-handler/https" = [ "floorp.desktop" ];
        "text/html" = [ "floorp.desktop" ];
        "application/pdf" = [
          "floorp.desktop"
        ];
      };
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
  };
}
