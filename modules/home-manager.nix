{
  keyboardProfile ? "us",
  inputs,
  monitors ? [ ],
  animationRate ? null,
  stateVersion,
  enableWorkd ? false,
}:
{
  useGlobalPkgs = true;
  useUserPackages = true;
  overwriteBackup = true;
  backupFileExtension = "bkp";
  extraSpecialArgs = {
    inherit
      inputs
      stateVersion
      ;
  };

  sharedModules = [
    (
      {
        osConfig ? null,
        lib,
        ...
      }:
      {
        # stylix still writes programs.wayprompt, which home-manager removed.
        # Drop the target until stylix follows suit.
        disabledModules = [ "${inputs.stylix}/modules/wayprompt/hm.nix" ];

        home = {
          backupFileExtension = "bkp";
          overwriteBackup = true;
        };

        desktop = {
          inherit monitors;
          keyboard = keyboardProfile;
        }
        // lib.optionalAttrs (osConfig != null && osConfig ? desktop && osConfig.desktop ? mouse) {
          inherit (osConfig.desktop) mouse;
        }
        // lib.optionalAttrs (osConfig != null && osConfig ? desktop && osConfig.desktop ? hdr) {
          inherit (osConfig.desktop) hdr;
        }
        // lib.optionalAttrs (animationRate != null) {
          inherit animationRate;
        }
        //
          lib.optionalAttrs
            (
              animationRate == null && osConfig != null && osConfig ? desktop && osConfig.desktop ? animationRate
            )
            {
              animationRate = osConfig.desktop.animationRate;
            };
      }
      // lib.optionalAttrs (osConfig ? host) {
        inherit (osConfig) host;
      }
      // lib.optionalAttrs (osConfig ? serverMode) {
        inherit (osConfig) serverMode;
      }
    )
  ];

  users = {
    yi = {
      imports = [ ../users/home/yijia.nix ];
      home.stateVersion = stateVersion;
    };
    root = {
      imports = [ ../users/home/root.nix ];
      home.stateVersion = stateVersion;
    };
  }
  // (
    if enableWorkd then
      {
        workd = {
          imports = [ ../users/home/workd.nix ];
          home.stateVersion = stateVersion;
        };
      }
    else
      { }
  );
}
