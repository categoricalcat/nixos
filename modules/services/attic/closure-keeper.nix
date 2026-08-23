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
    ];
    wants = [ "network-online.target" ];
    requires = [ "atticd.service" ];

    path = [
      atticClient
      pkgs.coreutils
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
      attic login ${attic.cacheName} ${atticEndpoint} "$ATTIC_TOKEN"

      shopt -s nullglob
      heads=(/nix/store/*-nixos-system-*)
      if [ ''${#heads[@]} -eq 0 ]; then
        echo "No nixos-system heads found in /nix/store"
        exit 0
      fi

      printf '%s\n' "''${heads[@]}" | attic push ${attic.cacheName}:${attic.cacheName} --stdin --ignore-upstream-cache-filter -j 10
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
