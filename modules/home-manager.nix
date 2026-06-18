{
  desktopEnvironment ? null,
  desktopShell ? if desktopEnvironment == "niri" then "dms" else "none",
  inputs,
  stateVersion,
}:
{
  useGlobalPkgs = true;
  useUserPackages = true;
  overwriteBackup = true;
  backupFileExtension = "bkp";
  extraSpecialArgs = {
    inherit
      desktopEnvironment
      desktopShell
      inputs
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
