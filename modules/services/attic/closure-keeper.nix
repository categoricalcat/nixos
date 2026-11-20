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
      "atticd.service"
    ]
    ++ lib.optional config.programs.nh.clean.enable "nh-clean.service";
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
      CPUWeight = 50;
      IOWeight = 50;
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
      # Push only active system closures: this host's current system plus the
      # per-host CI GC roots written by ci/build.sh. Globbing /nix/store/
      # directly matches hundreds of .drv files, old generations, and VM tests.
      declare -A heads=()
      for p in /run/current-system /var/lib/nix-builder/gcroots/*/*; do
        resolved=$(readlink -f "$p" 2>/dev/null || true)
        if [ -e "$resolved" ] && [[ $resolved != *.drv ]]; then
          heads[$resolved]=1
        fi
      done
      if [ ''${#heads[@]} -eq 0 ]; then
        echo "No active system closures found"
        exit 0
      fi

      # Push one head at a time: get-missing-paths sends the whole closure as
      # one JSON body, and atticd (axum) caps buffered bodies at 2 MiB.
      for head in "''${!heads[@]}"; do
        attic push ${attic.cacheName}:${attic.cacheName} --ignore-upstream-cache-filter -j 10 "$head"
      done
    '';
  };

  systemd.timers.attic-closure-keeper = {
    description = "Periodic Attic closure keeper run";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "6h";
    };
  };
}
