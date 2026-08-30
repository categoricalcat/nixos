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

    groups = lib.mkMerge [
      {
        yi = {
          gid = 1000;
        };
        none = {
          gid = 1002;
        };
      }
      (lib.mkIf config.host.workd {
        workd = {
          gid = 1001;
        };
      })
    ];

    users = lib.mkMerge [
      {
        root = {
          # Clients (yitaishi, yixiaoqing) and core server (yifuwuqi) can admin the fleet,
          # but perimeter gateway (yirukou) cannot SSH into other nodes as root.
          openssh.authorizedKeys.keys = [
            keys.hosts.yitaishi.sshPublicKey
            keys.hosts.yixiaoqing.sshPublicKey
            keys.hosts.yifuwuqi.sshPublicKey
            keys.ci.deployPublicKey
          ];
        };

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
            "tss"
            "plugdev"
            "adbusers"
            "podman"
          ];
        };

        nix-builder = {
          isSystemUser = true;
          group = "nogroup";
          description = "Nix remote builder";
          home = "/var/lib/nix-builder";
          createHome = true;
          shell = pkgs.bash;
        };

        # Read-only AI account (see docs/src/services/ai-ssh.md).
        # ForceCommand-gated on the sshd side: a hostile ai key can only run the
        # whitelisted reads in modules/services/ssh/scripts/ai-gate.sh.
        ai = {
          isSystemUser = true;
          group = "nogroup";
          description = "Read-only AI agent";
          shell = "/bin/sh";
          openssh.authorizedKeys.keys = keys.users.ai.sshAuthorizedKeys;
          extraGroups = [ "systemd-journal" ];
        };
      }
      (lib.mkIf config.host.workd {
        workd = {
          uid = 1001;
          isNormalUser = true;
          description = "workd";
          group = "workd";
          hashedPasswordFile = config.sops.secrets."passwords/workd".path;
        };
      })
    ];

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

  sops.secrets = lib.mkMerge [
    {
      "passwords/yi" = {
        mode = "0600";
        owner = "yi";
        group = "yi";
      };
    }
    (lib.mkIf config.host.workd {
      "passwords/workd" = {
        mode = "0600";
        owner = "workd";
        group = "workd";
      };
    })
  ];

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
      # Read-only mesh access lane (used by the opencode systemd unit, which
      # runs as yi but does not see home-manager's ~/.nix-profile/bin).
      (pkgs.writeShellApplication {
        name = "ai-ssh";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./scripts/ai-ssh.sh;
      })
    ];

    variables = {
      ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
    };

    pathsToLink = [ "/share/zsh" ];

    etc."nixos".source =
      pkgs.runCommandLocal "etc-nixos" { }
        "ln -s ${lib.escapeShellArg "${config.users.users.yi.home}/the.files/nixos"} $out";
  };

}
