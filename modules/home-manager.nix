{
  desktopEnvironment ? null,
  desktopShell ? if desktopEnvironment == "niri" then "dms" else "none",
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
      desktopEnvironment
      desktopShell
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
