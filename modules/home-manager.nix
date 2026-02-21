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
  users.fufud = {
    imports = [ ../users/home-fufud.nix ];
    home.stateVersion = stateVersion;
  };
  backupFileExtension = "bkp";
  overwriteBackup = true;
}
