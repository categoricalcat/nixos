{
  lib,
  pkgs,
  config,
  ...
}:

let
  keys = import ../secrets/keys.nix;
in
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
        openssh.authorizedKeys.keys = keys.users.yi.sshAuthorizedKeys;
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
        shell = pkgs.bash;
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

  sops.secrets = {
    "passwords/yi" = {
      mode = "0600";
      owner = "yi";
      group = "yi";
    };
    "passwords/workd" = {
      mode = "0600";
      owner = "workd";
      group = "workd";
    };
  };

  programs = {
    mtr.enable = true;
    trippy.enable = true;
    zsh = {
      enable = true;
    };
  };

  environment = {
    systemPackages = [
      (pkgs.writeShellScriptBin "nix-sanity" (builtins.readFile ./scripts/nix-sanity.sh))
      (pkgs.writeShellScriptBin "nix-fix-uids" (builtins.readFile ./scripts/nix-fix-uids.sh))
      (pkgs.writeShellScriptBin "gh-backup" (builtins.readFile ./scripts/gh-backup-repos.sh))

    ];

    variables = {
      ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
    };

    pathsToLink = [ "/share/zsh" ];

    etc."nixos".source =
      pkgs.runCommandLocal "etc-nixos" { }
        "ln -s ${lib.escapeShellArg "${config.users.users.yi.home}/the.files/nixos"} $out";
  };

  # services.emacs = {
  #   enable = true;
  #   install = true;
  #   defaultEditor = true;
  #   startWithGraphical = false;
  # };
}
