{
  config,
  pkgs,
  allAddresses,
  lib,
  ...
}:

let
  services = allAddresses.hosts.yifuwuqi.services;
  # Numeric: the build-time `nft --check` sandbox cannot resolve user names.
  noneUid = toString config.users.users.none.uid;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/forgejo-runner.nix: may only be imported on yifuwuqi";
    }
  ];

  # nix-daemon trusts callers by real uid and nix-builder is a trusted-user, so
  # sandboxed jobs must really become `none`; a bwrap user namespace keeps the uid.
  security.wrappers.drop-to-none = {
    source = lib.getExe' pkgs.util-linux "setpriv";
    owner = "none";
    group = "none";
    setuid = true;
    setgid = true;
    permissions = "u+rx,g+x";
  };

  users.users.nix-builder.extraGroups = [ "none" ];

  networking.nftables.tables.sandbox-egress = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy accept;
        meta skuid ${noneUid} ip daddr 127.0.0.1 meta l4proto { tcp, udp } th dport 53 accept
        meta skuid ${noneUid} ip6 daddr ::1 meta l4proto { tcp, udp } th dport 53 accept
        meta skuid ${noneUid} ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16 } reject
        meta skuid ${noneUid} ip6 daddr { ::1, fc00::/7, fe80::/10 } reject
      }
    '';
  };

  sops.secrets."tokens/forgejo-runner" = {
    owner = "nix-builder";
  };

  sops.secrets."keys/deploy" = {
    path = "/var/lib/nix-builder/.ssh/id_ed25519";
    owner = "nix-builder";
    group = "nogroup";
    mode = "0400";
    restartUnits = [ "forgejo-runner-yifuwuqi.service" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nix-builder/.ssh 0700 nix-builder nogroup -"
  ];

  services.forgejo-runner = {
    instances."yifuwuqi" = {
      enable = true;
      hostPackages = with pkgs; [
        bash
        bubblewrap
        coreutils
        curl
        findutils
        gawk
        git
        gnugrep
        gnused
        jq
        nodejs
        openssh
        nvd
        deploy-rs
        config.nix.package
        pkgs.attic-client
        pkgs.lixPackageSets.lix_2_96.nix-fast-build
      ];
      settings = {
        runner.labels = [ "native:host" ];
        runner.timeout = "12h";
        server.connections.yifuwuqi = {
          url = "https://${services.forgejo.domain}";
          uuid = "e6b2db5f-d74b-41bc-866e-1f530f4a26c4";
        };
      };
      secrets = {
        server.connections.yifuwuqi = {
          token_url = config.sops.secrets."tokens/forgejo-runner".path;
        };
      };
    };
  };

  systemd.services."forgejo-runner-yifuwuqi" = {
    # CD deploying yifuwuqi would otherwise kill its own job mid-activation
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
    # Nix builds need full system access — chroot, mount, /nix/store writes,
    # and process namespacing.
    environment = {
      ATTIC_INTERNAL_URL = "http://${config.networking.hostName}:${toString services.attic.port}";
      ATTIC_CACHE_NAME = services.attic.cacheName;
    };
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "nix-builder";
      Group = lib.mkForce "nogroup";
      PrivateUsers = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      PrivateMounts = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
    };
  };
}
