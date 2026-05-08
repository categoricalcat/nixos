{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  themeAssets = import ./theme-assets.nix { inherit inputs pkgs; };
in
{
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
        rgba = "rgb";
        lcdfilter = "light";
      };
    };

    fontDir.enable = true;
    enableDefaultPackages = false;

    inherit (themeAssets.fonts) packages;
  };

}
