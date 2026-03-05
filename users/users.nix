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
      yi = { };
      workd = { };
      none = { };
    };

    users = {
      yi = {
        isNormalUser = true;
        description = "yi";
        group = "yi";
        hashedPasswordFile = config.sops.secrets."passwords/yi".path;
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

    extraUsers = {
      none = {
        enable = true;
        isNormalUser = true;
        description = "none";
        group = "none";
        hashedPasswordFile = config.sops.secrets."passwords/yi".path;
      };
    };
  };

  sops.secrets."passwords/yi" = {
    mode = "0600";
    owner = "yi";
    group = "yi";
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
