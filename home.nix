{ pkgs, ... }:

{
  # home-manager settings

  programs.ssh = {
    enable = true;
    agentTimeout = "15m";
    addKeysToAgent = "confirm";
  };
}
