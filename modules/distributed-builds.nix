{
  allAddresses,
  config,
  lib,
  ...
}:

let
  builderPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILoRXgk+BMdw/tEdHJSkBd4MmFkB+A3YVmMWNVlLjXb6 yi@yifuwuqi";
  builderPrivateKey = config.sops.secrets."ssh/nix-builder".path;

  defaultSupportedFeatures = [
    "nixos-test"
    "benchmark"
    "big-parallel"
    "kvm"
  ];

  meshNodes = lib.filterAttrs (
    _name: host:
    (host.nixBuild.enable or false)
    && (host.network.tailscale.ipv4.host or null) != null
    && (host.ssh.listenPort or null) != null
  ) allAddresses.hosts;

  remoteBuilders = lib.filterAttrs (
    _name: host: host.hostName != config.networking.hostName
  ) meshNodes;

  buildMachines = lib.mapAttrsToList (_name: host: {
    inherit (host) hostName;
    inherit (host.nixBuild) systems maxJobs;

    sshUser = "nix-builder";
    sshKey = builderPrivateKey;
    protocol = "ssh-ng";
    speedFactor = host.nixBuild.speedFactor or 1;
    supportedFeatures = host.nixBuild.supportedFeatures or defaultSupportedFeatures;
  }) remoteBuilders;

  sshHostConfig = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (_name: host: ''
      Host ${host.hostName}
        HostName ${host.network.tailscale.ipv4.host}
        Port ${toString host.ssh.listenPort}
        User nix-builder
        IdentityFile ${builderPrivateKey}
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new
    '') remoteBuilders
  );
in
{
  assertions = [
    {
      assertion = builtins.hasAttr config.networking.hostName meshNodes;
      message = "This host imports distributed-builds.nix but is not marked nixBuild.enable in allAddresses.";
    }
  ];

  sops.secrets."ssh/nix-builder" = {
    sopsFile = "/etc/nixos/secrets/distributed-builds.yaml";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  users.users.nix-builder.openssh.authorizedKeys.keys = [
    builderPublicKey
  ];

  nix = {
    distributedBuilds = true;
    inherit buildMachines;

    settings = {
      builders-use-substitutes = true;
      connect-timeout = 5;
    };
  };

  programs.ssh.extraConfig = lib.mkAfter sshHostConfig;
}
