{
  pkgs,
  allAddresses,
  config,
  ...
}:

let
  addrs = allAddresses.hosts.${config.networking.hostName};
  inherit (addrs.services.pinepods) domain port;
in
{
  systemd.services = {
    init-pinepods-network = {
      description = "Create Pinepods container network";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "-${pkgs.podman}/bin/podman network create --ignore pinepods_net"
          "-${pkgs.podman}/bin/podman network create --ignore --internal pinepods_internal"
        ];
      };
    };
    "podman-pinepods-db" = {
      requires = [ "init-pinepods-network.service" ];
      after = [ "init-pinepods-network.service" ];
    };
    "podman-pinepods-valkey" = {
      requires = [ "init-pinepods-network.service" ];
      after = [ "init-pinepods-network.service" ];
    };
    "podman-pinepods" = {
      requires = [ "init-pinepods-network.service" ];
      after = [ "init-pinepods-network.service" ];
    };
  };

  virtualisation.oci-containers.containers = {
    pinepods-db = {
      image = "docker.io/library/postgres:18";
      extraOptions = [ "--network=pinepods_internal" ];
      environment = {
        POSTGRES_DB = "pinepods_database";
        POSTGRES_USER = "postgres";
        # Internal-only network, unreachable off-box (same posture as firecrawl-db)
        POSTGRES_PASSWORD = "pinepods";
        PGDATA = "/var/lib/pgdata/pgdata";
      };
      volumes = [ "/var/lib/container-volumes/pinepods/pgdata:/var/lib/pgdata" ];
    };

    pinepods-valkey = {
      image = "docker.io/valkey/valkey:8-alpine";
      extraOptions = [ "--network=pinepods_internal" ];
    };

    pinepods = {
      image = "docker.io/madeofpendletonwool/pinepods:latest";
      ports = [ "127.0.0.1:${toString port}:8040" ];
      extraOptions = [
        "--network=pinepods_internal"
        "--network=pinepods_net"
        "--umask=0002"
      ];
      environment = {
        SEARCH_API_URL = "https://search.pinepods.online/api/search";
        PEOPLE_API_URL = "https://people.pinepods.online";
        HOSTNAME = "https://${domain}";
        DB_TYPE = "postgresql";
        DB_HOST = "pinepods-db";
        DB_PORT = "5432";
        DB_USER = "postgres";
        DB_PASSWORD = "pinepods";
        DB_NAME = "pinepods_database";
        VALKEY_HOST = "pinepods-valkey";
        VALKEY_PORT = "6379";
        DEBUG_MODE = "false";
        TZ = config.time.timeZone;
      };
      volumes = [
        "/persist/media/podcasts:/opt/pinepods/downloads"
        "/var/lib/container-volumes/pinepods/backups:/opt/pinepods/backups"
      ];
      dependsOn = [
        "pinepods-db"
        "pinepods-valkey"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/pinepods 0755 root root - -"
    "d /var/lib/container-volumes/pinepods/pgdata 0755 root root - -"
    "d /var/lib/container-volumes/pinepods/backups 0755 root root - -"
    "d /persist/media/podcasts 2775 root media - -"
  ];
}
