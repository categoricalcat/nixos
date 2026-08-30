{ lib, ... }:

{
  options.desktop = {
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
            connector = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "DRM connector name (e.g. DP-1, HDMI-A-1) for compositors that match on connector.";
            };
            vrr = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable variable refresh rate (VRR / Adaptive Sync / FreeSync / G-Sync)";
            };
            hdr = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable High Dynamic Range (HDR)";
            };
            hdrMinLum = lib.mkOption {
              type = lib.types.nullOr (lib.types.either lib.types.float lib.types.int);
              default = null;
              description = "Mastering display minimum luminance in cd/m²";
            };
            hdrMaxLum = lib.mkOption {
              type = lib.types.nullOr (lib.types.either lib.types.float lib.types.int);
              default = null;
              description = "Mastering display peak luminance in cd/m²";
            };
            hdrMaxAvgLum = lib.mkOption {
              type = lib.types.nullOr (lib.types.either lib.types.float lib.types.int);
              default = null;
              description = "Max frame-average light level in cd/m²";
            };
            hdrForce = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Force HDR even if EDID does not advertise BT.2020/PQ";
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
}
