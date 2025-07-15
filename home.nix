{ pkgs, ... }:

{
  # home-manager settings
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "categoricalcat";
        email = "catufuzgu@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      core = {
        sshCommand = "ssh";
      };
    };
  };

  programs.ssh = {
    enable = true;
    agentTimeout = "15m";
    addKeysToAgent = "confirm";
  };
}
