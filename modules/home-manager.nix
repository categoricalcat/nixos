{
  desktopEnvironment ? null,
  inputs,
  stateVersion,
}:
{
  useGlobalPkgs = true;
  useUserPackages = true;
  overwriteBackup = true;
  backupFileExtension = "bkp";
  extraSpecialArgs = {
    inherit desktopEnvironment inputs stateVersion;
  };

  users.yi = {
    imports = [ ../users/home/yi.nix ];
    home.stateVersion = stateVersion;
  };
}
