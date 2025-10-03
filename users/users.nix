{
  pkgs,
  config,
  ...
}:

{
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;

    groups = {
      fufud = { };
      workd = { };
    };

    extraUsers = {
      tempd = {
        enable = false;
        isNormalUser = true;
        description = "temp";
        group = "wheel";
        initialPassword = "temp";
      };
    };

    users = {
      fufud = {
        isNormalUser = true;
        description = "lucky'";
        group = "fufud";
        # alway rember to change
        initialHashedPassword = "$y$j9T$TbPknJF9F.7RE1sww8obj/$3.hMSrDCFms5HsGJGsbr15Zde8GoB71uPRfBvlwLXa2";
        extraGroups = [
          "wheel"
          "render"
          "video"
          "dialout"
          "networkmanager"
        ];

      };

      workd = {
        isNormalUser = true;
        description = "lucky work";
        group = "workd";
        hashedPasswordFile = config.sops.secrets."passwords/workd".path;
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

  # services.emacs = {
  #   enable = true;
  #   install = true;
  #   defaultEditor = true;
  #   startWithGraphical = false;
  # };
}
