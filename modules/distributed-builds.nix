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

  # Explicitly define the builders we want to use, skipping the current host if it is one.
  remoteBuilders = [
    "yifuwuqi"
    # "yitaishi"
  ];

  activeBuilders = builtins.filter (name: name != config.networking.hostName) remoteBuilders;

  buildMachines = map (name: {
    hostName = name;
    sshUser = "nix-builder";
    sshKey = builderPrivateKey;
    protocol = "ssh-ng";
    maxJobs = allAddresses.hosts.${name}.nixBuild.maxJobs;
    speedFactor = allAddresses.hosts.${name}.nixBuild.speedFactor;
    supportedFeatures = [
      "nixos-test"
      "benchmark"
      "big-parallel"
      "kvm"
    ];
    systems = allAddresses.hosts.${name}.nixBuild.systems;
  }) activeBuilders;

  sshHostConfig = lib.concatStringsSep "\n" (
    map (name: ''
      Host ${name}
        HostName ${allAddresses.hosts.${name}.network.tailscale.ipv4.host}
        Port ${toString allAddresses.hosts.${name}.ssh.listenPort}
        User nix-builder
        IdentityFile ${builderPrivateKey}
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new
        ConnectTimeout 3
        ConnectionAttempts 1
    '') activeBuilders
  );
in
{
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
