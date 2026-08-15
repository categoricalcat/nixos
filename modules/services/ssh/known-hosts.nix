{
  lib,
  allAddresses,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;

  ipv4For = host: alias: lib.attrByPath alias.path null host;

  # Regenerate the pinned global known_hosts from secrets/keys.nix ×
  # modules/addresses.nix. Covers the bare name, every reachable alias
  # (.lan/.local/.ts/.nb) and the underlying IPs for defense-in-depth.
  knownHostFor =
    name:
    let
      host = allAddresses.hosts.${name};
      resolvedAliases = lib.filter (a: (ipv4For host a) != null) allAddresses.aliases;
    in
    {
      hostNames = lib.unique (
        [ name ]
        ++ (map (a: "${name}.${a.suffix}") resolvedAliases)
        ++ (map (a: ipv4For host a) resolvedAliases)
      );
      publicKey = keys.hosts.${name}.sshPublicKey;
    };
in
{
  programs.ssh.knownHosts = lib.genAttrs (lib.attrNames keys.hosts) knownHostFor;
}
