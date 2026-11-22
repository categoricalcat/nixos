# Attic binary cache server on yifuwuqi.
#
# Pre-deploy: generate JWT secret and add to sops as tokens/attic-server-jwt-env:
#   openssl genrsa -traditional 4096 | base64 -w0
#
# Post-deploy bootstrap (on yifuwuqi):
#   atticd-atticadm make-token --sub "*" --validity "10 years" --pull "*" --push "*" --create-cache "*" --configure-cache "*" --configure-cache-retention "*" --destroy-cache "*"
#   attic login yi http://127.0.0.1:24203 <admin-token>
#   attic cache create yi --public --priority 38
#   attic cache info yi   # → update trusted-public-keys in modules/services/attic/client.nix
#   atticd-atticadm make-token --sub "yi" --validity "10 years" --push
#   # → add to sops as tokens/attic-push-token, redeploy
{
  pkgs,
  config,
  allAddresses,
  ...
}:

let
  services = allAddresses.hosts.yifuwuqi.services;
  inherit (services) attic;
  postgres = services.postgresql;
  atticd = config.services.atticd;
  gcSlot = config.yi.maintenance.slots.atticGc;
  gcConfig = (pkgs.formats.toml { }).generate "attic-gc.toml" atticd.settings;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/attic/server.nix: may only be imported on yifuwuqi (services.attic.* hardcodes yifuwuqi addresses)";
    }
  ];

  sops.secrets."tokens/attic-server-jwt-env" = {
    mode = "0400";
    restartUnits = [ "atticd.service" ];
  };

  services.atticd = {
    enable = true;
    package = pkgs.attic-server;
    environmentFile = config.sops.secrets."tokens/attic-server-jwt-env".path;
    settings = {
      listen = "127.0.0.1:${toString attic.port}";
      database.url = postgres.urls.atticd;
      # Objects are collected only when both `created_at` and `last_accessed_at`
      # are past the window. `attic push` skips paths already cached, so a
      # re-push never refreshes `created_at`; only a NAR download bumps
      # `last_accessed_at`. Devshell closures are rooted by ci/build.sh and
      # re-pushed by attic-closure-keeper every 6h, so 3 days covers the
      # longest observed gap between develop CI runs (2.15d) plus that
      # restore latency. 1 day dropped pushed objects before the keeper
      # could re-push them.
      garbage-collection = {
        interval = "0 seconds";
        default-retention-period = "3 days";
      };
      chunking = {
        nar-size-threshold = 64 * 1024;
        min-size = 16 * 1024;
        avg-size = 256 * 1024;
        max-size = 1024 * 1024;
      };
    };
  };

  systemd = {
    services = {
      atticd.serviceConfig = {
        # Cache pushes peak 9.7 threads / 95% NVMe busy (measured:
        # docs/src/hardware/new-compute-host-research.md); yield under load.
        CPUWeight = 50;
        IOWeight = 50;
        ExecStartPre = pkgs.lib.mkAfter [
          "+${pkgs.bash}/bin/bash -c 'if [ -d /var/lib/private/atticd/storage ]; then ${pkgs.coreutils}/bin/chown -R --reference=/var/lib/private/atticd /var/lib/private/atticd/storage; fi'"
        ];
      };

      attic-gc = {
        description = "Attic garbage collection";
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
        before = [ "fstrim.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.lib.getExe atticd.package} -f ${gcConfig} --mode garbage-collector-once";
          EnvironmentFile = atticd.environmentFile;
          DynamicUser = true;
          User = atticd.user;
          Group = atticd.group;
          StateDirectory = "atticd";
        };
      };
    };

    timers.attic-gc = gcSlot.timer;
  };
  environment.systemPackages = [
    pkgs.attic-client
    (import ../../../packages/wipe-attic-cache.nix { inherit pkgs; })
  ];
}
