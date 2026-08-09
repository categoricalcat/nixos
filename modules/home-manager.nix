{
  keyboardProfile ? "us-intl",
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
      keyboardProfile
      monitors
      stateVersion
      ;
  };

  users.yi = {
    imports = [ ../users/home/yi.nix ];
    home.stateVersion = stateVersion;
  };

  users.workd = {
    imports = [ ../users/home/workd.nix ];
    home.stateVersion = stateVersion;
  };
}
