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
  # One account per container (uid-gid plan, decision 2); pinepods itself
  # keeps the shared media group for the downloads volume.
  users = {
    groups = {
      pinepods-db.gid = 338;
      pinepods-valkey.gid = 339;
    };
    users = {
      pinepods-db = {
        isSystemUser = true;
        uid = 338;
        group = "pinepods-db";
      };
      pinepods-valkey = {
        isSystemUser = true;
        uid = 339;
        group = "pinepods-valkey";
      };
      pinepods = {
        isSystemUser = true;
        uid = 344;
        group = "media";
      };
    };
  };

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
      user = "${toString config.users.users.pinepods-db.uid}:${toString config.users.groups.pinepods-db.gid}";
      extraOptions = [ "--network=pinepods_internal" ];
      environment = {
        POSTGRES_DB = "pinepods_database";
        POSTGRES_USER = "postgres";
        # Internal-only network, unreachable off-box (same posture as firecrawl_internal)
        POSTGRES_PASSWORD = "pinepods";
        PGDATA = "/var/lib/pgdata/pgdata";
      };
      volumes = [ "/var/lib/container-volumes/pinepods/pgdata:/var/lib/pgdata" ];
    };

    pinepods-valkey = {
      image = "docker.io/valkey/valkey:8-alpine";
      user = "${toString config.users.users.pinepods-valkey.uid}:${toString config.users.groups.pinepods-valkey.gid}";
      # Cache with no host volume; the image's /data stays owned by the
      # in-image valkey user, so persistence is off entirely.
      cmd = [
        "valkey-server"
        "--save"
        ""
      ];
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
        # The startup script remaps its in-image user to these and execs
        # horust via su-exec, so every process runs as this identity.
        PUID = toString config.users.users.pinepods.uid;
        PGID = toString config.users.groups.media.gid;
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
    # initdb as the container account needs the data dir owned by it
    "d /var/lib/container-volumes/pinepods/pgdata 0700 pinepods-db pinepods-db - -"
    "d /var/lib/container-volumes/pinepods/backups 0775 pinepods media - -"
    "d /persist/media/podcasts 2775 root media - -"
  ];
}
