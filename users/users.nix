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
      "workd"
    ];
    packages = with pkgs; [
    ];
    hashedPasswordFile = config.sops.secrets."passwords/workd".path;
  };

  users.defaultUserShell = pkgs.zsh;

  programs.mtr.enable = true;

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

  services.emacs = {
    enable = true;
    install = true;
    defaultEditor = true;
    startWithGraphical = false;
  };
}
