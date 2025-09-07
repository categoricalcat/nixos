# User configuration module

{ config, pkgs, ... }:

{
  # User accounts
  users.users.fufud = {
    isNormalUser = true;
    description = "fu's personal";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "render"
      "video"
      "dialout"
    ];
    packages = with pkgs; [
    ];
  };

  users.users.workd = {
    isNormalUser = true;
    description = "fu's work";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "dialout"
    ];
    packages = with pkgs; [
    ];
    hashedPasswordFile = config.sops.secrets."passwords/workd".path;
  };

  # Default shell
  users.defaultUserShell = pkgs.zsh;

  # MTR network diagnostic tool
  programs.mtr.enable = true;

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
