{ lib, ... }:

{
  # Converts standard schema key string ("SUPER,t", "SUPER+SHIFT,space") to GNOME dconf key ("<Super>t", "<Shift><Super>space")
  toGnomeKey =
    keyStr:
    let
      parts = lib.splitString "," keyStr;
      modsPart = lib.elemAt parts 0;
      keyPart = lib.elemAt parts 1;
      modMap = {
        "SUPER" = "<Super>";
        "CTRL" = "<Ctrl>";
        "ALT" = "<Alt>";
        "SHIFT" = "<Shift>";
      };
      mods = lib.filter (m: m != "" && m != "none") (lib.splitString "+" modsPart);
      gnomeMods = lib.concatMapStrings (m: modMap.${m} or "<${m}>") mods;
    in
    "${gnomeMods}${keyPart}";
}
