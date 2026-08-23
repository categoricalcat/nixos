{ lib, allAddresses, ... }:

let
  attic = allAddresses.hosts.yifuwuqi.services.attic;
in
{
  nix.settings = {
    substituters = lib.mkBefore [ "https://${attic.domain}/${attic.cacheName}" ];
    trusted-public-keys = lib.mkBefore [
      "${attic.cacheName}:wLUC4OacKKUxGtnXwIxTFGBlLwvJ9IU4BNP5OBDQO60="
    ];
  };
}
