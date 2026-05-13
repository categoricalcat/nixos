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
      yi = {
        gid = 1000;
      };
      workd = {
        gid = 1001;
      };
      none = {
        gid = 1002;
      };
    };

    users = {
      yi = {
        uid = 1000;
        isNormalUser = true;
        description = "yi";
        group = "yi";
        hashedPasswordFile = config.sops.secrets."passwords/yi".path;
        extraGroups = [
          "wheel"
          "render"
          "video"
          "audio"
          "dialout"
          "networkmanager"
          "systemd-journal"
        ];
      };

      workd = {
        uid = 1001;
        isNormalUser = true;
        description = "workd";
        group = "workd";
        hashedPasswordFile = config.sops.secrets."passwords/workd".path;
      };

      nix-builder = {
        isSystemUser = true;
        group = "nogroup";
        description = "Nix remote builder";
        home = "/var/lib/nix-builder";
        createHome = true;
        shell = pkgs.bashInteractive;
      };
    };

    extraUsers = {
      none = {
        uid = 1002;
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
  programs.trippy.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nix-sanity" (builtins.readFile ./scripts/nix-sanity.sh))
    (pkgs.writeShellScriptBin "nix-fix-uids" (builtins.readFile ./scripts/nix-fix-uids.sh))
    (pkgs.writeShellScriptBin "gh-backup" (builtins.readFile ./scripts/gh-backup-repos.sh))

  ];

  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  environment.pathsToLink = [ "/share/zsh" ];

  environment.etc."nixos".source = "${config.users.users.yi.home}/the.files/nixos";

  # services.emacs = {
  #   enable = true;
  #   install = true;
  #   defaultEditor = true;
  #   startWithGraphical = false;
  # };
}
