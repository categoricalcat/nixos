{
  allAddresses,
  config,
  lib,
  ...
}:

let
  keys = import ../secrets/keys.nix;
  hostName = config.networking.hostName;
  inherit (allAddresses) hosts;

  localBuild = hosts.${hostName}.nixBuild;
  builderNames = lib.pipe hosts [
    (lib.filterAttrs (
      name: host: name != hostName && host.nixBuild.enable && host.nixBuild.remoteBuilder
    ))
    builtins.attrNames
  ];

  clientNames = lib.pipe hosts [
    (lib.filterAttrs (name: host: name != hostName && host.nixBuild.enable))
    builtins.attrNames
  ];

  buildMachines = map (
    name:
    let
      remoteBuild = hosts.${name}.nixBuild;
      relativeSpeed = remoteBuild.speedFactor / localBuild.speedFactor;
      finalSpeed = if relativeSpeed < 1 then 1 else relativeSpeed;
    in
    {
      hostName = name;
      sshUser = "nix-builder";
      sshKey = keys.paths.sshHostKey;
      protocol = "ssh-ng";
      inherit (remoteBuild) maxJobs;
      speedFactor = finalSpeed;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      inherit (remoteBuild) systems;
    }
  ) builderNames;

  sshHostConfig = lib.concatStringsSep "\n" (
    map (name: ''
      Host ${name}
        HostName ${hosts.${name}.network.vpn.ipv4.host}
        Port ${toString hosts.${name}.ssh.listenPort}
        User nix-builder
        IdentityFile ${keys.paths.sshHostKey}
        IdentitiesOnly yes
        StrictHostKeyChecking yes
        ConnectTimeout 3
        ConnectionAttempts 1
    '') builderNames
  );
in
{
  nix = {
    distributedBuilds = builderNames != [ ];
    inherit buildMachines;

    settings = {
      max-jobs = localBuild.maxJobs;
      builders-use-substitutes = true;
      connect-timeout = 5;
      fallback = true;
    };
  };

  programs.ssh.extraConfig = lib.mkAfter sshHostConfig;

  users.users.nix-builder.openssh.authorizedKeys.keys = lib.optionals localBuild.remoteBuilder (
    map (name: keys.hosts.${name}.sshPublicKey) clientNames
  );
}
