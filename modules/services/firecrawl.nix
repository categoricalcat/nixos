{
  pkgs,
  allAddresses,
  config,
  ...
}:

let
  firecrawlPort = allAddresses.hosts.${config.networking.hostName}.services.firecrawl.port;
  searxngPort = allAddresses.hosts.${config.networking.hostName}.services.searxng.port;

  # Retry a probe inside a container until it answers (~120s cap). A podman
  # unit is "started" when the container exists, not when the service listens;
  # ExecStartPost with this makes After=/Requires= mean "ready".
  waitFor =
    name: probe:
    pkgs.writeShellScript "firecrawl-wait-${name}" ''
      for _ in $(seq 1 60); do
        ${pkgs.podman}/bin/podman exec ${name} ${probe} >/dev/null 2>&1 && exit 0
        sleep 2
      done
      echo "timed out waiting for ${name} to become ready" >&2
      exit 1
    '';
in

{
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
      serviceConfig.ExecStartPost = waitFor "firecrawl-postgres" "pg_isready -U postgres -d postgres -q";
    };
    "podman-firecrawl-rabbitmq" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
      # Same race, slower boot: ECONNREFUSED here crashed nuq workers and
      # failed a nixos activation (deploy run 310). Probe the AMQP port, NOT
      # rabbitmq-diagnostics: podman exec runs as root, and a root Erlang VM
      # creates a root-owned .erlang.cookie before the entrypoint writes it —
      # the broker (user rabbitmq) then crashes with eacces (deploy 2026-11-10).
      serviceConfig.ExecStartPost = waitFor "firecrawl-rabbitmq" "bash -c 'exec 3<>/dev/tcp/127.0.0.1/5672'";
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
    };
  };

  virtualisation.oci-containers.containers = {
    firecrawl-redis = {
      image = "docker.io/library/redis:alpine";
      extraOptions = [ "--network=firecrawl_internal" ];
    };

    firecrawl-postgres = {
      image = "ghcr.io/firecrawl/nuq-postgres:latest";
      extraOptions = [
        "--network=firecrawl_internal"
        # Podman-level health for auto-update and inspection; the systemd
        # ordering gate lives in ExecStartPost above.
        "--health-cmd=pg_isready -U postgres -d postgres -q"
        "--health-start-period=10s"
      ];
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_DB = "postgres";
      };
    };

    firecrawl-rabbitmq = {
      image = "docker.io/library/rabbitmq:4-management";
      # No podman --health-cmd: podman runs healthchecks as root, and a root
      # rabbitmq-diagnostics VM poisons .erlang.cookie (root-owned, 400) during
      # boot — the broker then dies with eacces. Readiness is gated by the
      # unit's ExecStartPost port probe instead.
      extraOptions = [ "--network=firecrawl_internal" ];
    };

    firecrawl-playwright = {
      image = "ghcr.io/firecrawl/playwright-service:latest";
      extraOptions = [
        "--network=firecrawl_internal"
        "--network=firecrawl_net"
      ];
      environment = {
        PORT = "3000";
        MAX_CONCURRENT_PAGES = "10";
      };
    };

    firecrawl = {
      image = "ghcr.io/firecrawl/firecrawl:latest";
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
