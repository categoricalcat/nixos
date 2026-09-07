{
  lib,
  allAddresses,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;

  ipFor = host: alias: lib.attrByPath alias.path null host;

  # Regenerate the pinned global known_hosts from secrets/keys.nix ×
  # modules/addresses.nix. Covers the bare name, every reachable alias
  # (.lan/.local/.ts/.nb) and the underlying IPs for defense-in-depth.
  # For non-standard ports (e.g. 24212), OpenSSH requires '[name]:port' in
  # known_hosts to match.
  knownHostFor =
    name:
    let
      host = allAddresses.hosts.${name};
      resolvedAliases = lib.filter (a: (ipFor host a) != null) allAddresses.aliases;
      port = host.ssh.listenPort or null;
      rawNames = lib.unique (
        [ name ]
        ++ (map (a: "${name}.${a.suffix}") resolvedAliases)
        ++ (map (a: ipFor host a) resolvedAliases)
      );
      portNames = if port != null && port != 22 then map (n: "[${n}]:${toString port}") rawNames else [ ];
    in
    {
      hostNames = rawNames ++ portNames;
      publicKey = keys.hosts.${name}.sshPublicKey;
    };
in
{
  programs.ssh.knownHosts = lib.genAttrs (lib.attrNames keys.hosts) knownHostFor;
}
