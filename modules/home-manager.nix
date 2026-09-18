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
        desktop = {
          inherit monitors;
          keyboard = keyboardProfile;
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
    )
  ];

  users = {
    yi = {
      imports = [ ../users/home/yijia.nix ];
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
