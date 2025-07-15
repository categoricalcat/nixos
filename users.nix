# User configuration module

{ config, pkgs, ... }:

{
  # User accounts
  users.users.fufud = {
    isNormalUser = true;
    description = "fu's personal";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      chromium
    ];
  };

  users.users.workd = {
    isNormalUser = true;
    description = "fu's work";
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

    # Configure Zsh to run fastfetch on SSH connections
    interactiveShellInit = ''
      # Run fastfetch when connecting via SSH
      if [[ -n "$SSH_CONNECTION" ]]; then
        ${pkgs.fastfetch}/bin/fastfetch
      fi
      
      # Enable direnv for automatic environment switching
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    '';
  };

  # Environment variables for Zsh
  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  # Enable Zsh completions
  environment.pathsToLink = [ "/share/zsh" ];
}
