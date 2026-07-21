{
  pkgs,
  allAddresses,
  config,
  ...
}:

let
  firecrawlPort = allAddresses.hosts.${config.networking.hostName}.services.firecrawl.port;
  searxngPort = allAddresses.hosts.${config.networking.hostName}.services.searxng.port;
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
        ExecStart = "-${pkgs.podman}/bin/podman network create firecrawl_net";
      };
    };
    "podman-firecrawl-redis" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl-postgres" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl-rabbitmq" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl-playwright" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
    "podman-firecrawl" = {
      requires = [ "init-firecrawl-network.service" ];
      after = [ "init-firecrawl-network.service" ];
    };
  };

  # Allow containers to reach aardvark-dns on the host (port 53).
  # Opened globally because nftables fails to parse wildcard interfaces like "podman+".
  # This is safe because AdGuard is explicitly bound to internal LAN/Tailscale IPs,
  # and aardvark-dns is explicitly bound to internal Podman bridge IPs.
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];

  virtualisation.oci-containers.containers = {
    firecrawl-redis = {
      image = "redis:alpine";
      extraOptions = [ "--network=firecrawl_net" ];
    };

    firecrawl-postgres = {
      image = "ghcr.io/firecrawl/nuq-postgres:latest";
      extraOptions = [ "--network=firecrawl_net" ];
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_DB = "postgres";
      };
    };

    firecrawl-rabbitmq = {
      image = "rabbitmq:3-management";
      extraOptions = [ "--network=firecrawl_net" ];
    };

    firecrawl-playwright = {
      image = "ghcr.io/firecrawl/playwright-service:latest";
      extraOptions = [ "--network=firecrawl_net" ];
      environment = {
        PORT = "3000";
        MAX_CONCURRENT_PAGES = "10";
      };
    };

    firecrawl = {
      image = "ghcr.io/firecrawl/firecrawl:latest";
      extraOptions = [ "--network=firecrawl_net" ];
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
        "firecrawl-playwright"
      ];
    };
  };
}
