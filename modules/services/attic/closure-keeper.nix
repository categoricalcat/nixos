{
  pkgs,
  lib,
  config,
  allAddresses,
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
      message = "modules/services/attic/closure-keeper.nix: may only be imported on yifuwuqi (services.attic.* hardcodes yifuwuqi addresses)";
    }
  ];

  sops.secrets."tokens/attic-push-token" = {
    mode = "0400";
  };

  systemd.services.attic-closure-keeper = {
    description = "Attic cache closure keeper (re-push current system closures)";
    after = [
      "network-online.target"
      "atticd.service"
    ]
    ++ lib.optional config.programs.nh.clean.enable "nh-clean.service";
    wants = [ "network-online.target" ];
    requires = [ "atticd.service" ];

    path = [
      atticClient
      pkgs.coreutils
      pkgs.curl
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "nix-builder";
      Group = "nogroup";
      StateDirectory = "attic-closure-keeper";
      LoadCredential = "attic-push-token:${config.sops.secrets."tokens/attic-push-token".path}";
    };
    script = ''
      set -euo pipefail
      export HOME="/var/lib/attic-closure-keeper"
      ATTIC_TOKEN=$(< "$CREDENTIALS_DIRECTORY/attic-push-token")

      # Wait up to 30s for atticd to finish starting and accept connections
      for _ in {1..30}; do
        if curl -s -f -o /dev/null "${atticEndpoint}/"; then
          break
        fi
        sleep 1
      done

      attic login ${attic.cacheName} ${atticEndpoint} "$ATTIC_TOKEN"

      shopt -s nullglob
      heads=(/nix/store/*-nixos-system-*)
      if [ ''${#heads[@]} -eq 0 ]; then
        echo "No nixos-system heads found in /nix/store"
        exit 0
      fi

      # Push one head at a time: get-missing-paths sends the whole closure as
      # one JSON body, and atticd (axum) caps buffered bodies at 2 MiB.
      # .drv heads alone carry ~23k build-time paths, so a combined push 413s.
      for head in "''${heads[@]}"; do
        attic push ${attic.cacheName}:${attic.cacheName} --ignore-upstream-cache-filter -j 10 "$head"
      done
    '';
  };

  systemd.timers.attic-closure-keeper = {
    description = "Periodic Attic closure keeper run";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "15m";
      Persistent = true;
    };
  };
}
