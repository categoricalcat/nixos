{
  pkgs,
  config,
  ...
}:

{
  users = {
    mutableUsers = true;
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
        initialHashedPassword = "$y$j9T$uEVCCoJ6X8FQi9DNxMICY1$8SnMAQ3bUuHnjG2icND.yEx1/RS0hxoXxzLh/VMxGVA";
      };
    };

    users = {
      fufud = {
        isNormalUser = true;
        description = "fufud";
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
        description = "workd";
        group = "workd";
        hashedPasswordFile = config.sops.secrets."passwords/workd".path;
      };
    };
  };

  sops.secrets."passwords/fufud" = {
    mode = "0600";
    owner = "fufud";
    group = "fufud";
  };
  sops.secrets."passwords/workd" = {
    mode = "0600";
    owner = "workd";
    group = "workd";
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
