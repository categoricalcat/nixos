# Woodpecker CI server + local-backend agent on yifuwuqi.
#
# Post-deploy:
#   1. Put woodpecker/* secrets in sops (agent-secret: openssl rand -hex 32)
#   2. Create Forgejo OAuth app -> woodpecker/forgejo-client + forgejo-secret
#   3. Log in at ci.fufu.land, enable categoricalcat/nixos repo
#   4. Add repo secrets: attic_token, github_status_token
{
  config,
  pkgs,
  inputs,
  lib,
  allAddresses,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  internalHost = config.networking.hostName;
  repo = "categoricalcat/nixos";
  services = allAddresses.hosts.yifuwuqi.services;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/woodpecker.nix: may only be imported on yifuwuqi (services.* domains hardcode yifuwuqi addresses)";
    }
  ];

  sops = {
    secrets = {
      "woodpecker/agent-secret" = { };
      "woodpecker/forgejo-client" = { };
      "woodpecker/forgejo-secret" = { };
    };

    templates."woodpecker.env".content = ''
      WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/agent-secret"}
      WOODPECKER_FORGEJO_CLIENT=${config.sops.placeholder."woodpecker/forgejo-client"}
      WOODPECKER_FORGEJO_SECRET=${config.sops.placeholder."woodpecker/forgejo-secret"}
    '';
  };

  services.woodpecker-server = {
    enable = true;
    environment = {
      WOODPECKER_HOST = "https://${services.woodpecker.domain}";
      WOODPECKER_SERVER_ADDR = ":${toString services.woodpecker.httpPort}";
      WOODPECKER_GRPC_ADDR = ":${toString services.woodpecker.grpcPort}";
      WOODPECKER_OPEN = "true";
      WOODPECKER_ADMIN = "categoricalcat";
      WOODPECKER_FORGEJO = "true";
      WOODPECKER_FORGEJO_URL = config.services.forgejo.settings.server.ROOT_URL;
    };
    environmentFile = [ config.sops.templates."woodpecker.env".path ];
  };

  services.woodpecker-agents.agents."local" = {
    enable = true;
    environment = {
      WOODPECKER_SERVER = "${internalHost}:${toString services.woodpecker.grpcPort}";
      WOODPECKER_BACKEND = "local";
      WOODPECKER_HEALTHCHECK_ADDR = ":${toString services.woodpecker.healthPort}";
      WOODPECKER_MAX_WORKFLOWS = "2";
      ATTIC_INTERNAL_URL = "http://${internalHost}:${toString services.attic.port}";
      ATTIC_CACHE_NAME = services.attic.cacheName;
      GITHUB_REPO = repo;
    };
    path = with pkgs; [
      bash
      coreutils
      curl
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      openssh
      config.nix.package
      inputs.attic.packages.${system}.attic-client
    ];
    environmentFile = [ config.sops.templates."woodpecker.env".path ];
  };

  systemd.services.woodpecker-agent-local = {
    # Nix builds need full system access — chroot, mount, /nix/store writes,
    # and process namespacing. Each mkForce false below is required for the
    # Woodpecker local backend to function.
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "nix-builder";
      Group = "nogroup";
      PrivateUsers = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      PrivateMounts = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
    };
  };

  networking.firewall.allowedTCPPorts = [ services.woodpecker.httpPort ];
}
