{ inputs, pkgs }:

let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
rec {
  cursor = {
    package = unstable.bibata-cursors;
    name = "Bibata-Modern-Amber-Right";
    size = 26;
  };

  icons = {
    package = unstable.papirus-icon-theme;
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
      serif = [ serif.name ];
      sansSerif = [ sansSerif.name ];
      monospace = [ monospace.name ];
      emoji = [ emoji.name ];
    };

    packages = [
      mapleMono.package
      emoji.package
      googleFonts.package
    ];

    sizes = {
      applications = 11;
      desktop = 11;
    };
  };
}
