{
  lib,
  pkgs,
  config,
  ...
}:

let
  keys = import ../secrets/keys.nix;
  hostName = config.networking.hostName;
  hasForgejoRunner = config.services.forgejo-runner.instances != { };

  # Capability groups, granted only when the host actually declares the group.
  # Deriving membership from declaration instead of a host flag keeps the list
  # honest: a host without podman/docker/NM cannot inherit a dead membership,
  # and no separate "developer" toggle has to be kept in sync by hand.
  capabilityGroups = [
    "render"
    "video"
    "dialout"
    "networkmanager"
    "tss"
    "plugdev"
    "podman"
    "docker"
  ];
  grantedGroups = builtins.filter (g: config.users.groups ? ${g}) capabilityGroups;
  # Only hosts with a sops identity can decrypt the hash.
  sopsHost = keys.hosts ? ${hostName};

  desktopGroups = [
    "audio"
    "input"
    "adbusers"
  ];
in
{
  sops.secrets."passwords/yi" = lib.mkIf sopsHost { neededForUsers = true; };

  users = {
    mutableUsers = true;
    defaultUserShell = lib.mkIf config.programs.zsh.enable pkgs.zsh;

    groups = lib.mkMerge [
      {
        yi = {
          gid = 1000;
        };
        # One group per service principal; dynamic ids stay in the account
        # database. After the switch, chgrp -R nix-builder /var/lib/nix-builder.
        nix-builder = { };
        ai = { };
      }
      (lib.mkIf hasForgejoRunner {
        none = {
          gid = 1002;
        };
      })
      (lib.mkIf config.host.workd {
        workd = {
          gid = 1001;
        };
      })
    ];

    users = lib.mkMerge [
      {
        root = lib.mkMerge [
          {
            openssh.authorizedKeys.keys = keys.access.root.${hostName};
          }
          (lib.mkIf
            (lib.elem hostName [
              "yitaishi"
              "yixiaoqing"
            ])
            {
              hashedPasswordFile = "/persist/keys/passwords/root";
            }
          )
        ];

        yi = {
          uid = 1000;
          isNormalUser = true;
          description = "yi";
          group = "yi";
          openssh.authorizedKeys.keys = keys.access.yi.${hostName};
          extraGroups = [
            "systemd-journal"
          ]
          ++ grantedGroups
          ++ lib.optionals (config.host.desktopEnvironment != null) desktopGroups;
          # With mutableUsers the hash is written only when the account is
          # created: a fresh install, or every boot once / is ephemeral.
          hashedPasswordFile = lib.mkIf sopsHost config.sops.secrets."passwords/yi".path;
        };

        nix-builder = {
          isSystemUser = true;
          group = "nix-builder";
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
          group = "ai";
          description = "Read-only AI agent";
          shell = "/bin/sh";
          openssh.authorizedKeys.keys = keys.access.ai.${hostName};
          extraGroups = [ "systemd-journal" ];
        };
      }
      (lib.mkIf config.host.workd {
        workd = {
          uid = 1001;
          isNormalUser = true;
          description = "workd";
          group = "workd";
          linger = true;
        };
      })
    ];

    extraUsers = lib.mkIf hasForgejoRunner {
      none = {
        uid = 1002;
        enable = true;
        isNormalUser = true;
        description = "none";
        group = "none";
      };
    };
  };

  programs = {
    mtr.enable = true;
    trippy.enable = true;
    zsh = {
      enable = lib.mkDefault true;
    };
  };

  environment = {
    systemPackages = lib.optional (config.services.opencode.enable or false) (
      # Read-only mesh access lane: the opencode systemd unit runs as yi but
      # does not see home-manager's ~/.nix-profile/bin, so this must be a
      # system package rather than a devshell one. `nix-sanity` and `gh-backup`
      # are repo tools and live in `nix develop`.
      pkgs.writeShellApplication {
        name = "ai-ssh";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./scripts/ai-ssh.sh;
      }
    );

    variables = lib.mkIf config.programs.zsh.enable {
      ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
    };

    pathsToLink = lib.mkIf config.programs.zsh.enable [ "/share/zsh" ];

    etc."nixos".source =
      pkgs.runCommandLocal "etc-nixos" { }
        "ln -s ${lib.escapeShellArg "${config.users.users.yi.home}/the.files/nixos"} $out";
  };

}
