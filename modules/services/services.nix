# Services configuration module

{
  pkgs,
  addresses,
  config,
  ...
}:

{
  imports = [
    ./avahi.nix
    ./openssh.nix
    ./dnsmasq.nix
  ];

  services.code-server.enable = true;

  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  programs.mtr.enable = true;

  programs.ssh = {
    startAgent = true;
    # enable = true;
    agentTimeout = "15m";
    # addKeysToAgent = "confirm";
  };

  services.fail2ban.enable = true;

  services.ollama = {
    enable = true;
    acceleration = "rocm";
  };

  # Podman configuration (Docker replacement)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      dns_enabled = true;
      ipv6_enabled = true;
      mtu = 1492;
    };

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Enable container networking
  virtualisation.containers = {
    enable = true;

    storage.settings = {
      storage = {
        driver = "overlay";
        runroot = "/run/containers/storage";
        graphroot = "/var/lib/containers/storage";
        options.overlay.mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
      };
    };

    registries = {
      search = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];
    };

    containersConf.settings = {
      containers = {
        # dns_servers = [
        #   "8.8.8.8"
        #   "1.1.1.1"
        # ];
        log_driver = "journald";
        log_size_max = 10485760; # 10MB in bytes (10 * 1024 * 1024)
        default_ulimits = [
          "nofile=65536:65536"
        ];
      };

      network = {
        default_subnet_pools = addresses.containers.subnetPools;
      };
    };
  };

  users.users.fufud.extraGroups = [ "podman" ];
  users.users.workd.extraGroups = [ "podman" ];

  # Ensure ddclient user/group exist for sops secret ownership and service
  users.groups.ddclient = { };
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
    description = "ddclient daemon user";
  };

  systemd.services."serial-getty@ttyUSB0" = {
    enable = false;
    wantedBy = [ "getty.target" ];
    serviceConfig.Restart = "always";
  };

  services.cockpit = {
    enable = false;
    port = 9090;
    allowed-origins = [
      "https://fufuwuqi.local:9090"
      "http://fufuwuqi.local:9090"
      "https://localhost:9090"
      "http://localhost:9090"
      "https://cockpit.fufu.land"
    ];
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "fufuwuqi.local" = {
        serverName = "fufuwuqi.local";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "hello, gently, from self :3";
          '';
        };
      };
    };
  };

  # Dynamic DNS via ddclient (Cloudflare)
  services.ddclient = {
    enable = true;
    package = pkgs.ddclient;
    interval = "5min"; # seconds
    ssl = true;
    protocol = "cloudflare";
    usev4 = "webv4";
    usev6 = "webv6";
    verbose = true;
    zone = "fufu.land"; # TODO: change if different
    username = "catufuzgu@gmail.com"; # using API token auth
    passwordFile = config.sops.secrets."tokens/cloudflare-ddclient".path;
    domains = [
      "fufu.land"
      "cockpit.fufu.land"
    ];
  };

  services.fwupd.enable = true;
}
