{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.desktop.greeter == "ly") {
    services.displayManager.ly = {
      enable = true;
      x11Support = false;

      # Dark wine + teal theme. ly runs on the Linux VT (fbcon), which cannot
      # display truecolor SGR sequences (they get mangled into wrong colors),
      # so we use eight-color mode (full_color = false) with termbox palette
      # constants instead of 0x00RRGGBB values. The actual RGB behind each
      # palette slot comes from stylix's console target (console.colors), which
      # sets the VT palette to yimoka: slot 1 (red) = base08 wine, slot 6
      # (cyan) = base0D teal, slot 0 (black) = base00.
      #
      # Values are 32-bit: 0xSSXXXXXX, where SS is a styling byte
      # (0x00 = plain, 0x01 = bold) and XXXXXX is the color id:
      # TB_DEFAULT 0x000000, TB_BLACK 0x000001, TB_RED 0x000002,
      # TB_GREEN 0x000003, TB_YELLOW 0x000004, TB_BLUE 0x000005,
      # TB_MAGENTA 0x000006, TB_CYAN 0x000007, TB_WHITE 0x000008.
      settings = {
        full_color = false;

        # Note: stylix maps its named colors as red=base08, blue=base0D,
        # cyan=base0C, so yimoka teal sits in the TB_BLUE slot, not TB_CYAN.
        bg = "0x00000001"; # TB_BLACK -> base00
        fg = "0x00000005"; # TB_BLUE -> base0D teal (text)
        border_bg = "0x00000001"; # TB_BLACK -> base00
        border_fg = "0x01000002"; # TB_RED|bold -> base08 wine (frame)
        error_bg = "0x00000001"; # TB_BLACK -> base00
        error_fg = "0x01000002"; # TB_RED|bold -> base08 wine

        animation = "none";

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
