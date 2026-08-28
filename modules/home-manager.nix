{
  keyboardProfile ? "us",
  inputs,
  monitors ? [ ],
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
    {
      desktop.monitors = monitors;
      desktop.keyboard = keyboardProfile;
    }
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
