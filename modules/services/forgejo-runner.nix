{
  config,
  pkgs,
  allAddresses,
  lib,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
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

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances."yifuwuqi" = {
      enable = true;
      name = "yifuwuqi";
      url = "https://${services.forgejo.domain}";
      tokenFile = config.sops.secrets."tokens/forgejo-runner".path;
      labels = [
        "native:host"
      ];
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
        openssh
        config.nix.package
        inputs.attic.packages.${system}.attic-client
      ];
    };
  };

  systemd.services."gitea-runner-yifuwuqi" = {
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
