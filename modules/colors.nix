# Colour helpers built on top of the base16 SSOT (theme.nix).
# theme.nix stays pure so stylix can consume it raw as base16Scheme.
_:
let
  base = import ./theme.nix;

  d = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  h2 = s: d.${builtins.substring 0 1 s} * 16 + d.${builtins.substring 1 1 s};

  toRgb = hex: {
    r = h2 (builtins.substring 0 2 hex);
    g = h2 (builtins.substring 2 2 hex);
    b = h2 (builtins.substring 4 2 hex);
  };

  ansiFg =
    hex:
    let
      c = toRgb hex;
    in
    "38;2;${toString c.r};${toString c.g};${toString c.b}";

  # Pastel hue wheel (S~47% V~95%): 21 stops, H 0-300 step 15.
  asc = [
    127
    155
    184
    212
  ];
  desc = [
    241
    212
    184
    155
  ];
  el = builtins.elemAt;
  sect =
    f:
    map f [
      0
      1
      2
      3
    ];
  wheel =
    (sect (i: {
      r = 241;
      g = el asc i;
      b = 127;
    }))
    ++ (sect (i: {
      r = el desc i;
      g = 241;
      b = 127;
    }))
    ++ (sect (i: {
      r = 127;
      g = 241;
      b = el asc i;
    }))
    ++ (sect (i: {
      r = 127;
      g = el desc i;
      b = 241;
    }))
    ++ (sect (i: {
      r = el asc i;
      g = 127;
      b = 241;
    }))
    ++ [
      {
        r = 241;
        g = 127;
        b = 241;
      }
    ];
in
{
  inherit
    base
    toRgb
    ansiFg
    ;
  hueWheel = map (c: "38;2;${toString c.r};${toString c.g};${toString c.b}") wheel;
}
