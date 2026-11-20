{
  pkgs,
  allAddresses,
  config,
  lib,
  ...
}:

let
  firecrawlPort = allAddresses.hosts.${config.networking.hostName}.services.firecrawl.port;
  searxngPort = allAddresses.hosts.${config.networking.hostName}.services.searxng.port;

  # One account per container: each number is shared by the account and its
  # own group, so podman renders `user` at eval time (policy: container
  # accounts pin 330-399, one principal per ID; see nix/checks.nix).
  containerAccounts = {
    firecrawl-postgres = 334;
    firecrawl-rabbitmq = 335;
    firecrawl-redis = 336;
    firecrawl-playwright = 337;
    firecrawl = 343;
  };

  # Retry a probe command until it succeeds (~120s cap). A podman unit is
  # "started" when the container exists, not when the service listens;
  # ExecStartPost with this makes After=/Requires= mean "ready". Container
  # probes run via podman exec; the app probe uses the published host port
  # (the firecrawl image can't be assumed to ship curl/bash).
  waitFor =
    name: probeCmd:
    pkgs.writeShellScript "firecrawl-wait-${name}" ''
      for _ in $(seq 1 60); do
        ${probeCmd} >/dev/null 2>&1 && exit 0
        sleep 2
      done
      echo "timed out waiting for ${name} to become ready" >&2
      exit 1
    '';
in

{
  users.groups = lib.mapAttrs (_: gid: { inherit gid; }) containerAccounts;
  users.users = lib.mapAttrs (name: uid: {
    isSystemUser = true;
    inherit uid;
    group = name;
  }) containerAccounts;

  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/firecrawl 0755 root root - -"
    # initdb as the container account needs an empty, account-owned data dir
    "d /var/lib/container-volumes/firecrawl/pgdata 0700 firecrawl-postgres firecrawl-postgres - -"
    # The broker's HOME and mnesia dir must be writable by its account
    "d /var/lib/container-volumes/firecrawl/rabbitmq 0700 firecrawl-rabbitmq firecrawl-rabbitmq - -"
  ];

  systemd.services = {
    init-firecrawl-network = {
      description = "Create Firecrawl container network";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "-${pkgs.podman}/bin/podman network create --ignore firecrawl_net"
          "-${pkgs.podman}/bin/podman network create --ignore --internal firecrawl_internal"
        ];
      };
    };
    "podman-firecrawl-redis" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl-postgres" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
      # nuq workers connect at boot and crash without retry; mirror upstream's
      # service_healthy gate (docker-compose depends_on condition).
      serviceConfig.ExecStartPost = waitFor "firecrawl-postgres" "${pkgs.podman}/bin/podman exec firecrawl-postgres pg_isready -U postgres -d postgres -q";
    };
    "podman-firecrawl-rabbitmq" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
      # Same race, slower boot: ECONNREFUSED here crashed nuq workers and
      # failed a nixos activation (deploy run 310). Probe the AMQP port, NOT
      # rabbitmq-diagnostics: the diagnostics VM is a whole extra Erlang
      # runtime, and exec'ing it as root used to create a root-owned
      # .erlang.cookie before the entrypoint wrote it — the broker then
      # crashed with eacces (deploy 2026-11-10, fixed by the container account).
      serviceConfig.ExecStartPost = waitFor "firecrawl-rabbitmq" "${pkgs.podman}/bin/podman exec firecrawl-rabbitmq bash -c 'exec 3<>/dev/tcp/127.0.0.1/5672'";
    };
    "podman-firecrawl-playwright" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [
        "init-firecrawl-network.service"
        "podman-firecrawl-playwright.service"
      ];
      # Playwright crash-loops on transient network fetches at boot (corepack
      # pnpm download); the app survives its absence (per-scrape errors), so
      # order after it but never let it block startup (Wants, not Requires).
      wants = [ "podman-firecrawl-playwright.service" ];
      # No start limit: start-limit-hit turned transient crash loops into
      # permanent outages needing manual intervention (2026-11-09). Slow
      # backoff alone is enough; the readiness gates above keep boots clean.
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig.RestartSec = "30s";
      # Gate "ready" on the API answering (GET / returns 200), same rationale
      # as the postgres/rabbitmq gates: After= now means "usable by clients".
      serviceConfig.ExecStartPost = waitFor "firecrawl" "${pkgs.curl}/bin/curl -sf -o /dev/null http://localhost:${toString firecrawlPort}/";
    };
  };

  virtualisation.oci-containers.containers = {
    firecrawl-redis = {
      image = "docker.io/library/redis:alpine";
      user = "${toString config.users.users.firecrawl-redis.uid}:${toString config.users.groups.firecrawl-redis.gid}";
      # Rate-limit/cache store with no host volume; the image's /data stays
      # owned by the in-image redis user, so persistence is off entirely.
      cmd = [
        "redis-server"
        "--save"
        ""
      ];
      extraOptions = [ "--network=firecrawl_internal" ];
    };

    firecrawl-postgres = {
      image = "ghcr.io/firecrawl/nuq-postgres:latest";
      user = "${toString config.users.users.firecrawl-postgres.uid}:${toString config.users.groups.firecrawl-postgres.gid}";
      # PGDATA outside the image VOLUME (overlay bind-mount failure,
      # docker-library/postgres#1363) and owned by the running account:
      # initdb as non-root needs an empty writable data dir. The volume also
      # survives podman auto-update recreations, which the container layer
      # never did.
      volumes = [ "/var/lib/container-volumes/firecrawl/pgdata:/var/lib/pgdata" ];
      extraOptions = [
        "--network=firecrawl_internal"
        # Podman-level health for auto-update and inspection; the systemd
        # ordering gate lives in ExecStartPost above.
        "--health-cmd=pg_isready -U postgres -d postgres -q"
        "--health-start-period=10s"
      ];
      environment = {
        PGDATA = "/var/lib/pgdata/data";
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_DB = "postgres";
      };
    };

    firecrawl-rabbitmq = {
      image = "docker.io/library/rabbitmq:4-management";
      user = "${toString config.users.users.firecrawl-rabbitmq.uid}:${toString config.users.groups.firecrawl-rabbitmq.gid}";
      # HOME and mnesia state on an account-owned host volume (tmpfiles
      # above); without it the writable-layer dirs stay owned by the in-image
      # rabbitmq user and the broker cannot write its cookie.
      volumes = [ "/var/lib/container-volumes/firecrawl/rabbitmq:/var/lib/rabbitmq" ];
      # No podman --health-cmd: the unit's ExecStartPost port probe gates
      # readiness without a second Erlang VM.
      extraOptions = [ "--network=firecrawl_internal" ];
    };

    firecrawl-playwright = {
      image = "ghcr.io/firecrawl/playwright-service:latest";
      user = "${toString config.users.users.firecrawl-playwright.uid}:${toString config.users.groups.firecrawl-playwright.gid}";
      extraOptions = [
        "--network=firecrawl_internal"
        "--network=firecrawl_net"
      ];
      environment = {
        PORT = "3000";
        MAX_CONCURRENT_PAGES = "10";
        # The image HOME (/home/node) is owned by the in-image node user;
        # the declared account needs a writable HOME for Chromium's profile.
        HOME = "/tmp";
      };
    };

    firecrawl = {
      image = "ghcr.io/firecrawl/firecrawl:latest";
      user = "${toString config.users.users.firecrawl.uid}:${toString config.users.groups.firecrawl.gid}";
      extraOptions = [
        "--network=firecrawl_internal"
        "--network=firecrawl_net"
      ];
      ports = [ "${toString firecrawlPort}:3002" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "3002";
        REDIS_URL = "redis://firecrawl-redis:6379";
        REDIS_RATE_LIMIT_URL = "redis://firecrawl-redis:6379";
        POSTGRES_URL = "postgresql://postgres:postgres@firecrawl-postgres:5432/postgres";
        NUQ_DATABASE_URL = "postgresql://postgres:postgres@firecrawl-postgres:5432/postgres";
        PLAYWRIGHT_MICROSERVICE_URL = "http://firecrawl-playwright:3000/scrape";
        NUQ_RABBITMQ_URL = "amqp://firecrawl-rabbitmq:5672";

        # SearXNG Search Integration (host.containers.internal resolves to the host in Podman)
        SEARCH_PROVIDER = "searxng";
        SEARXNG_BASE_URL = "http://host.containers.internal:${toString searxngPort}";
        SEARXNG_ENDPOINT = "http://host.containers.internal:${toString searxngPort}";
        SEARXNG_CATEGORIES = "science,general";
      };
      dependsOn = [
        "firecrawl-redis"
        "firecrawl-postgres"
        "firecrawl-rabbitmq"
      ];
    };
  };
}
