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
