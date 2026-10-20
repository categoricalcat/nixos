{
  config,
  pkgs,
  allAddresses,
  lib,
  ...
}:

let
  services = allAddresses.hosts.yifuwuqi.services;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/forgejo-runner.nix: may only be imported on yifuwuqi";
    }
  ];

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
