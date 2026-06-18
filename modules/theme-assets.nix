{
  inputs,
  pkgs,
}:

let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  cursor = {
    package = unstable.bibata-cursors;
    name = "Bibata-Modern-Amber-Right";
    size = 28;
  };

  icons = {
    package = unstable.catppuccin-papirus-folders.override {
      accent = "pink";
      flavor = "mocha";
    };
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };

  fonts = rec {
    mapleMono = {
      package = unstable.maple-mono.NF-CN-unhinted;
      name = "Maple Mono NF CN";
    };

    emoji = {
      package = unstable.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };

    googleFonts = rec {
      names = [
        "Lexend"
        "Roboto Serif"
      ];
      package = unstable.google-fonts.override {
        fonts = names;
      };
    };

    serif = mapleMono;
    sansSerif = mapleMono;
    monospace = mapleMono;

    defaultFamilies = {
      serif = [
        serif.name
        "Noto Serif"
        "Noto Serif CJK SC"
        "Noto Serif CJK JP"
        "DejaVu Serif"
      ];
      sansSerif = [
        sansSerif.name
        "Noto Sans"
        "Noto Sans CJK SC"
        "Noto Sans CJK JP"
        "DejaVu Sans"
      ];
      monospace = [
        monospace.name
        "Noto Sans Mono"
        "DejaVu Sans Mono"
      ];
      emoji = [
        emoji.name
        "Noto Color Emoji"
      ];
    };

    packages = [
      mapleMono.package
      emoji.package
      unstable.noto-fonts
      unstable.noto-fonts-cjk-sans
      unstable.noto-fonts-cjk-serif
      googleFonts.package
    ];

    sizes = {
      applications = 11;
      desktop = 11;
      terminal = 16;
    };
  };
}
