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
      default = "gnome";
      description = "Desktop environment to use";
    };

    greeter = lib.mkOption {
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

    shell = lib.mkOption {
      type = lib.types.enum [
        "dms"
        "noctalia"
        "none"
      ];
      default = if config.desktop.environment == "niri" then "dms" else "none";
      description = "Desktop shell to run on top of the compositor";
    };

    greeting = lib.mkOption {
      type = lib.types.str;
      default = "turmoil accompanies every great change";
      description = "Greeting text for greeters and display managers that support one.";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Monitor name (e.g. eDP-1) or make/model string.";
            };
            scale = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Monitor scale";
            };
            mode = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Monitor mode (e.g. 2880x1800@60)";
            };
            position = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    x = lib.mkOption { type = lib.types.int; };
                    y = lib.mkOption { type = lib.types.int; };
                  };
                }
              );
              default = null;
              description = "Monitor position x and y";
            };
            transform = lib.mkOption {
              type = lib.types.enum [
                "normal"
                "90"
                "180"
                "270"
                "flipped"
                "flipped-90"
                "flipped-180"
                "flipped-270"
              ];
              default = "normal";
              description = "Monitor transform";
            };
          };
        }
      );
      default = [ ];
      description = ''
        Monitor list. Used for dash-to-panel and niri outputs.

        useful:
        dconf read /org/gnome/shell/extensions/dash-to-panel/panel-sizes
        awk -F'[<>]' '/<vendor>/{v=$3} /<product>/{print "\"" v "-" $3 "\""}' ~/.config/monitors.xml | sort -u
      '';
    };

    keyboard = lib.mkOption {
      type = lib.types.enum [
        "us"
        "br"
      ];
      default = "us";
      description = "Keyboard layout profile";
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
