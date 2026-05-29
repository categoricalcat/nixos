{
  allAddresses,
  config,
  lib,
  ...
}:

let
  keys = import ../secrets/keys.nix;
  builderPrivateKey = keys.paths.sshHostKey;

  authorizedClientKeys = lib.pipe keys.hosts [
    (lib.filterAttrs (name: host: host.sshPublicKey != null && name != config.networking.hostName))
    (lib.mapAttrsToList (_: host: host.sshPublicKey))
  ];

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
    _name: host: (host.nixBuild.remoteBuilder or false) && host.hostName != config.networking.hostName
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
        ConnectTimeout 3
        ConnectionAttempts 1
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

  users.users.nix-builder.openssh.authorizedKeys.keys = authorizedClientKeys;

  nix = {
    distributedBuilds = true;
    inherit buildMachines;

    settings = {
      builders-use-substitutes = true;
      connect-timeout = 5;
      fallback = true;
    };
  };

  programs.ssh.extraConfig = lib.mkAfter sshHostConfig;
}
