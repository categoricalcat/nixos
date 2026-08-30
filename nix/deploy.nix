{
  self,
  inputs,
  lib,
  ...
}:
let
  addresses = import ../modules/addresses.nix;
  keys = import ../secrets/keys.nix;

  mkNode = name: {
    hostname = addresses.hosts.${name}.network.tailscale.ipv4.host;
    sshOpts = [
      "-p"
      (toString addresses.hosts.${name}.ssh.listenPort)
      "-i"
      keys.paths.sshHostKey
      "-i"
      "/var/lib/nix-builder/.ssh/id_ed25519"
    ];
    profiles.system = {
      user = "root";
      sshUser = "root";
      path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${name};
    };
  };
in
{
  flake = {
    deploy = {
      magicRollback = true;
      autoRollback = true;
      confirmTimeout = 30;
      nodes = lib.genAttrs [
        "yifuwuqi"
        "yirukou"
        "yitaishi"
        "yixiaoqing"
      ] mkNode;
    };
  };

  perSystem =
    { system, ... }:
    {
      checks = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;
    };
}
