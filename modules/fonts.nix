{
  inputs,
  pkgs,
  lib,
  config,
  options,
  ...
}:

let
  disableHinting = config.networking.hostName == "yixiaoqing";
  themeAssets = import ./theme-assets.nix { inherit inputs pkgs disableHinting; };
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = lib.mkForce themeAssets.fonts.defaultFamilies;

      antialias = true;
      hinting = {
        enable = !disableHinting;
        style = if disableHinting then "none" else "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
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
