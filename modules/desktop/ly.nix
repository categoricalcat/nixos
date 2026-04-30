{
  config,
  lib,
  ...
}:

let
  colors = import ../theme.nix;

  # LY colors are 32-bit values: 0xSSRRGGBB, where SS is a styling byte
  # (0x00 = plain, 0x01 = bold, 0x02 = underline, ...). Convert a base16
  # "RRGGBB" hex string into LY's plain (no styling) form.
  toLyColor = hex: "0x00${hex}";
in
{
  config = lib.mkIf (config.desktop.greeter == "ly") {
    services.displayManager.ly = {
      enable = true;
      x11Support = false;

      settings = {
        bg = toLyColor colors.base00;
        fg = toLyColor colors.base05;
        border_fg = toLyColor colors.base0E;
        error_bg = toLyColor colors.base00;
        error_fg = toLyColor colors.base08;

        animation = "colormix";
        colormix_col1 = toLyColor colors.base0E;
        colormix_col2 = toLyColor colors.base0D;
        colormix_col3 = toLyColor colors.base0B;

        clock = "%Y-%m-%d %H:%M";
        bigclock = "en";

        box_title = config.desktop.greeting;

        hide_version_string = true;
        load = true;
        save = true;
        default_input = "password";
      };
    };
  };
}
