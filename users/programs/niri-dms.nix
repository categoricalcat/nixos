{ config, lib, ... }:

{
  config = lib.mkIf (config.host.desktopShell == "dms") {
    programs.dank-material-shell.niri = {
      enableKeybinds = false;
      enableSpawn = false;
      includes = {
        enable = true;
        override = true;
        filesToInclude = [ "binds" ];
      };
    };
  };
}
