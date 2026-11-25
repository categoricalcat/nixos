# The address and service registry, in four sections:
#
#   addresses/network.nix    global network constants and DNS upstreams
#   addresses/hosts.nix      per-host registry (exported as `hosts`)
#   addresses/monitoring.nix monitoring/probe topology (exported as `monitoring`)
#   addresses/aliases.nix    derived alias list
#
# Kept pure `builtins`-only so `nix eval --file modules/addresses.nix` in
# ci/deploy.sh evaluates without instantiating nixpkgs.
let
  network = import ./addresses/network.nix;
  hosts = import ./addresses/hosts.nix {
    inherit (network) baseDomain sharedDnsUpstreams;
  };
in
{
  inherit (network)
    baseDomain
    legacyDomain
    email
    tailscale
    publicDnsResolvers
    privateDestinations
    ;

  inherit hosts;
  monitoring = import ./addresses/monitoring.nix { inherit hosts; };
  aliases = import ./addresses/aliases.nix;
}
