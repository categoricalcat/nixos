{ pkgs, ... }:

{
  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "Maple Mono NF CN"
        ];
        sansSerif = [
          # "Lexend"
          "Maple Mono NF CN"
        ];
        serif = [
          # "Roboto Serif"
          "Maple Mono NF CN"
        ];
      };

      antialias = true;
      hinting = {
        enable = false;
        style = "none";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };

    fontDir.enable = true;
    enableDefaultPackages = false;

    packages = with pkgs; [
      maple-mono.NF-CN-unhinted
      (google-fonts.override {
        fonts = [
          "Lexend"
          "Roboto Serif"
        ];
      })
    ];
  };

}
