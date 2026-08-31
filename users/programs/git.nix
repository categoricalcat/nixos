{ config, pkgs, ... }:
let
  keys = import ../../secrets/keys.nix;
  colors = import ../../modules/theme.nix;

  # Color helpers for theme-derived delta backgrounds.
  hexToDec =
    hex:
    let
      mapping = {
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
        "A" = 10;
        "B" = 11;
        "C" = 12;
        "D" = 13;
        "E" = 14;
        "F" = 15;
      };
      c1 = builtins.substring 0 1 hex;
      c2 = builtins.substring 1 1 hex;
    in
    mapping.${c1} * 16 + mapping.${c2};

  decToHex =
    dec:
    let
      mapping = [
        "0"
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "a"
        "b"
        "c"
        "d"
        "e"
        "f"
      ];
      val1 = builtins.elemAt mapping (dec / 16);
      val2 = builtins.elemAt mapping (dec - (dec / 16 * 16));
    in
    val1 + val2;

  mixChannel =
    bg: fg: ratio:
    (bg * (100 - ratio) + fg * ratio) / 100;

  blend =
    bgHex: fgHex: ratio:
    let
      bgR = hexToDec (builtins.substring 0 2 bgHex);
      bgG = hexToDec (builtins.substring 2 2 bgHex);
      bgB = hexToDec (builtins.substring 4 2 bgHex);
      fgR = hexToDec (builtins.substring 0 2 fgHex);
      fgG = hexToDec (builtins.substring 2 2 fgHex);
      fgB = hexToDec (builtins.substring 4 2 fgHex);
    in
    "${decToHex (mixChannel bgR fgR ratio)}${decToHex (mixChannel bgG fgG ratio)}${
      decToHex (mixChannel bgB fgB ratio)
    }";

  minusBg = blend colors.base00 colors.base08 28;
  minusBgEmph = blend colors.base00 colors.base08 42;
  plusBg = blend colors.base00 colors.base0B 28;
  plusBgEmph = blend colors.base00 colors.base0B 42;
in
{
  home.packages = [ pkgs.delta ];

  # Include the base dotfiles .gitconfig and override the signing key
  # for NixOS (uses a dedicated git signing key).
  home.file.".gitconfig" = {
    text = ''
      [include]
      	path = ${../assets/dotfiles/gitconfig}

      [user]
      	signingkey = ${keys.paths.gitSigningKey config.home.homeDirectory}

      [core]
      	pager = env LESS='-R -F -X -S --mouse' ${pkgs.delta}/bin/delta

      [interactive]
      	diffFilter = ${pkgs.delta}/bin/delta --color-only

      [delta]
      	navigate = true
      	side-by-side = true
      	line-numbers = true
      	hyperlinks = true
      	syntax-theme = base16
      	dark = true
      	true-color = always
      	minus-style = "syntax #${minusBg}"
      	minus-emph-style = "syntax #${minusBgEmph}"
      	plus-style = "syntax #${plusBg}"
      	plus-emph-style = "syntax #${plusBgEmph}"
      	
      	line-numbers-minus-style = "#${colors.base08}"
      	line-numbers-plus-style = "#${colors.base0B}"
      	line-numbers-zero-style = "#${colors.base03}"
      	
      	hunk-header-style = "#${colors.base0D}" bold
      	hunk-header-decoration-style = "#${colors.base03}" box

      [merge]
      	conflictstyle = zdiff3

      [diff]
      	colorMoved = default
    '';
    force = true;
  };

  # GitHub CLI with gh-dash extension for a TUI dashboard.
  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-dash ];
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      pager = "${pkgs.delta}/bin/delta";
    };
  };
}
