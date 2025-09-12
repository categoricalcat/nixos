# User configuration module

{ pkgs, config, ... }:

{
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;

    groups = {
      fufud = { };
      workd = { };
    };

    extraUsers = {
      wsl = {
        isNormalUser = true;
        description = "WSL default user";
        group = "wheel";
        initialPassword = "wsl";
        packages = with pkgs; [ ];
      };
    };

    users = {
      fufud = {
        isNormalUser = true;
        description = "fu's personal";
        group = "fufud";
        hashedPasswordFile = config.sops.secrets."passwords/fufud".path;
        extraGroups = [
          "wheel"
          "render"
          "video"
          "dialout"
        ];
        packages = with pkgs; [ ];
      };

      workd = {
        isNormalUser = true;
        description = "fu's work";
        group = "workd";
        hashedPasswordFile = config.sops.secrets."passwords/workd".path;
        extraGroups = [ "wheel" ];
        packages = with pkgs; [ ];
      };
    };
  };

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
