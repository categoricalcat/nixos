{
  inputs,
  pkgs,
  lib,
  options,
  ...
}:

let
  themeAssets = import ./theme-assets.nix { inherit inputs pkgs; };
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  environment.variables = {
    FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0 type1:no-stem-darkening=0";
  };

  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = lib.mkForce themeAssets.fonts.defaultFamilies;

      antialias = true;
      hinting = {
        enable = false;
        style = "none";
      };

      subpixel = {
        rgba = "none";
        lcdfilter = "none";
      };
    };

    fontDir.enable = true;
    enableDefaultPackages = false;

    packages =
      themeAssets.fonts.packages
      ++ lib.optionals (options ? desktop) (
        with unstable;
        [
          dejavu_fonts
          freefont_ttf
          gyre-fonts
          liberation_ttf
          unifont
          noto-fonts-color-emoji
        ]
      );
  };
}
