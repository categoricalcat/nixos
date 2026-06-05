{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.kmscon;
  themeAssets = import ../theme-assets.nix { inherit inputs pkgs; };
in
{
  config = lib.mkIf cfg.enable {
    services.kmscon = {
      # Enable hardware rendering for better performance
      hwRender = true;

      # Configure fonts using your existing theme-assets
      fonts = [
        {
          name = themeAssets.fonts.monospace.name;
          package = themeAssets.fonts.monospace.package;
        }
      ];

      # Any extra options (like setting custom font sizes or configuring behavior)
      extraConfig = ''
        font-size=16
      '';
    };
  };
}
