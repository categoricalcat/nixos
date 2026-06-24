{
  inputs,
  pkgs,
  config,
  allAddresses,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  attic = allAddresses.hosts.yifuwuqi.services.attic;
  atticClient = inputs.attic.packages.${system}.attic-client;
  atticEndpoint = "http://${config.networking.hostName}:${toString attic.port}";
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/attic-watch-store.nix: may only be imported on yifuwuqi (services.attic.* hardcodes yifuwuqi addresses)";
    }
  ];

  sops.secrets."tokens/attic-push-token" = {
    mode = "0400";
  };

  systemd.services.attic-watch-store = {
    description = "Push new /nix/store paths to Attic";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "atticd.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "atticd.service" ];

    path = [ atticClient ];
    serviceConfig = {
      Type = "simple";
      User = "nix-builder";
      Group = "nogroup";
      Restart = "on-failure";
      RestartSec = 10;
      StateDirectory = "attic-watch-store";
      LoadCredential = "attic-push-token:${config.sops.secrets."tokens/attic-push-token".path}";
    };
    script = ''
      set -euo pipefail
      export HOME="/var/lib/attic-watch-store"
      ATTIC_TOKEN=$(< "$CREDENTIALS_DIRECTORY/attic-push-token")
      attic login ${attic.cacheName} ${atticEndpoint} "$ATTIC_TOKEN"
      exec attic watch-store -j 10 ${attic.cacheName}:${attic.cacheName} --ignore-upstream-cache-filter
    '';
  };
}
