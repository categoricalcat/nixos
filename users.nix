# User configuration module

{ config, pkgs, ... }:

{
  # User accounts
  users.users.fufud = {
    isNormalUser = true;
    description = "fufu personal";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      chromium
      nodejs_24
    ];
  };

  users.users.work = {
    isNormalUser = true;
    description = "work account";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      chromium
      nodejs_20
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
