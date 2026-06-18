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
    hardware.graphics.enable = true;
    fonts.packages = [ themeAssets.fonts.monospace.package ];
    services.kmscon = {
      # Configure fonts using your existing theme-assets
      config = {
        # Enable hardware rendering for better performance
        hwaccel = true;
        font-name = lib.mkDefault themeAssets.fonts.monospace.name;
        font-size = lib.mkDefault 16;
      };
    };
  };
}
