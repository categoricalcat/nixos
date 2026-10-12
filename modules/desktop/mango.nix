{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  baseMango = inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.mango;

  patchedMango = baseMango.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../packages/mango-monitor-focus.patch
    ];
  });

  # Monitor focus tracking carry-patch, only wanted on the multi-head host.
  mangoPackage = if config.networking.hostName == "yitaishi" then patchedMango else baseMango;
in
{
  config = lib.mkIf (config.desktop.environment == "mango") {
    programs.mango.package = mangoPackage;

    home-manager.users.yi.imports = [
      inputs.mango.hmModules.mango
      inputs.dms.homeModules.dank-material-shell
      ../../users/programs/dms.nix
      ../../users/programs/noctalia
      ../../users/programs/mango.nix
      {
        wayland.windowManager.mango.package = mangoPackage;
        programs.fuzzel = {
          enable = true;
          settings = {
            main = {
              width = 80;
              lines = 15;
              horizontal-pad = 20;
              vertical-pad = 12;
              inner-pad = 8;
              border-width = 2;
              border-radius = 10;
            };
          };
        };
      }
    ];

    environment.systemPackages = with pkgs; [
      wlr-randr
      fuzzel
      slurp
    ];

    xdg.portal.wlr = {
      enable = true;
      settings = {
        screencast = {
          max_fps = 60;
          chooser_type = "dmenu";
          chooser_cmd = "${pkgs.fuzzel}/bin/fuzzel -d -p 'Share: ' --width 80 --lines 15";
        };
      };
    };

    programs.mango.enable = true;
  };
}
