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
      # nodejs_24
      fnm  # Node.js version manager
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
      fnm  # Node.js version manager
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
      
      # Initialize fnm (Fast Node Manager)
      if command -v fnm &> /dev/null; then
        eval "$(fnm env --use-on-cd)"
      fi
    '';
  };

  # Environment variables for Zsh
  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  # Enable Zsh completions
  environment.pathsToLink = [ "/share/zsh" ];
}
