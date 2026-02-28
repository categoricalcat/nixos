{
  desktopEnvironment ? null,
  inputs,
  stateVersion,
}:
{
  useGlobalPkgs = true;
  useUserPackages = true;
  extraSpecialArgs = {
    inherit desktopEnvironment inputs stateVersion;
  };
  users.yi = {
    imports = [ ../users/home-yi.nix ];
    home.stateVersion = stateVersion;
  };
  backupFileExtension = "bkp";
  overwriteBackup = true;
}
