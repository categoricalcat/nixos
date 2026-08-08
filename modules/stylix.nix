{
  pkgs,
  inputs,
  ...
}:

let
  themeAssets = import ./theme-assets.nix { inherit inputs pkgs; };
in
{
  stylix = {
    enable = true;
    image = ./desktop/wallpaper.jpg;
    polarity = "dark";
    autoEnable = true;

    inherit (themeAssets) cursor;

    icons = themeAssets.icons // {
      enable = true;
    };

    fonts = {
      inherit (themeAssets.fonts)
        serif
        sansSerif
        monospace
        emoji
        sizes
        ;
    };

    base16Scheme = import ./theme.nix;

    targets.chromium.enable = false;
  };

  home-manager.sharedModules = [
    {
      home.pointerCursor.enable = true;
    }
  ];
}
