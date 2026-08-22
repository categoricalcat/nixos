{
  keyboardProfile ? "us",
  inputs,
  monitors ? [ ],
  stateVersion,
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

  users.yi = {
    imports = [ ../users/home/yi.nix ];
    home.stateVersion = stateVersion;
  };

  users.workd = {
    imports = [ ../users/home/workd.nix ];
    home.stateVersion = stateVersion;
  };
}
