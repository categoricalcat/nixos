# Services configuration module

{
  pkgs,
  addresses,
  ...
}:

{
  imports = [
    ../../modules/services/nfs/server.nix
    ../../modules/services/samba/server.nix
    ../../modules/services/avahi.nix
    ../../modules/services/openssh.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/cloudflared.nix
    ../../modules/services/playit-agent.nix
    ../../modules/services/localtonet.nix
    ../../modules/services/github-runner.nix
    ../../modules/services/cockpit.nix
  ];

  services.vscode-server.enable = true;
  programs.nix-ld.enable = true;

  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  programs.ssh = {
    startAgent = true;
    # enable = true;
    agentTimeout = "15m";
    # addKeysToAgent = "confirm";
  };

  services.fail2ban = {
    enable = true;
    jails = {
      "nginx-http-auth".enabled = true;
      "nginx-botsearch".enabled = true;
      "nginx-badbots".enabled = true;
    };
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "10.3.0";
    };
  };

  # Let's Encrypt via ACME, using Cloudflare DNS-01 (optional)
  # security.acme = {
  #   acceptTerms = true;
  #   defaults = {
  #     email = "catufuzgu@gmail.com";
  #     dnsProvider = "cloudflare";
  #     credentialsFile = config.sops.secrets."tokens/cloudflare-acme".path;
  #     dnsPropagationCheck = true;
  #     listenHTTP = null; # not needed for DNS-01; set to ":80" only if using HTTP-01
  #   };
  #   certs = {
  #     "fufu.land" = {
  #       domain = "fufu.land";
  #       # extraDomainNames = [ "cockpit.fufu.land" ];
  #     };
  #     # Alternatively, separate certs per host:
  #     # "cockpit.fufu.land" = { domain = "cockpit.fufu.land"; };
  #   };
  # };

  # Podman configuration (Docker replacement)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      dns_enabled = false;
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

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    serverTokens = false;

    virtualHosts = {
      # Local test vhost
      "fufuwuqi.local" = {
        serverName = "fufuwuqi.local";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "fufuwuqi.local ok";
          '';
        };
      };

      "fufuwuqi.vpn" = {
        serverName = "fufuwuqi.vpn";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "fufuwuqi.vpn ok";
          '';
        };
      };

      "fufu.land" = {
        forceSSL = false;
        # useACMEHost = "fufu.land";
        extraConfig = ''
          add_header Content-Type text/markdown;
          return 200 "fufu.land is ok";
        '';
      };

      # "cockpit.fufu.land" = {
      #   forceSSL = true;
      #   useACMEHost = "fufu.land";
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:9090";
      #     extraConfig = ''
      #       proxy_http_version 1.1;
      #       proxy_set_header Upgrade $http_upgrade;
      #       proxy_set_header Connection $connection_upgrade;
      #     '';
      #   };
      # };
    };
  };

  services.fwupd.enable = true;
}
