_:

{
  programs.dank-material-shell.niri = {
    enableKeybinds = false;
    enableSpawn = false;
    includes = {
      enable = true;
      override = true;
      filesToInclude = [ "binds" ];
    };
  };
}
