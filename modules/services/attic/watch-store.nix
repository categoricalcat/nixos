{
  pkgs,
  config,
  allAddresses,
  systemdHardening,
  ...
}:

let
  attic = allAddresses.hosts.yifuwuqi.services.attic;
  atticClient = pkgs.attic-client;
  # Attic binds loopback behind the local ingress; this service runs on-host.
  atticEndpoint = "http://127.0.0.1:${toString attic.port}";
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/attic/watch-store.nix: may only be imported on yifuwuqi (services.attic.* hardcodes yifuwuqi addresses)";
    }
  ];

  sops.secrets."tokens/attic-push-token" = {
    mode = "0400";
  };

  systemd.services.attic-watch-store = {
    description = "Push new /nix/store paths to Attic";
    wantedBy = [ "multi-user.target" ];
    after = [
      "atticd.service"
      "network-online.target"
      "atticd.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "atticd.service" ];

    path = [ atticClient ];
    serviceConfig = systemdHardening // {
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
      # atticd may not be listening yet right after an activation restart
      for i in 1 2 3 4 5; do
        attic login ${attic.cacheName} ${atticEndpoint} "$ATTIC_TOKEN" && break
        sleep 2
      done
      exec attic watch-store -j 10 ${attic.cacheName}:${attic.cacheName} --ignore-upstream-cache-filter
    '';
  };
}
