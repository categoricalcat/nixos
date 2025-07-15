# User configuration module

{ config, pkgs, ... }:

{
  # User accounts
  users.users.fufud = {
    isNormalUser = true;
    description = "fufuwuqi";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      chromium
    ];
  };

  # Default shell
  users.defaultUserShell = pkgs.zsh;

  # Zsh configuration
  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "docker"
        "git"
        "sudo"
      ];
      theme = "agnoster";
    };
  };

  # Environment variables for Zsh
  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  # Enable Zsh completions
  environment.pathsToLink = [ "/share/zsh" ];
}
