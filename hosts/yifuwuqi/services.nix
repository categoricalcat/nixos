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
    # ../../modules/services/playit-agent.nix
    ../../modules/services/localtonet.nix
    # ../../modules/services/github-runner.nix
    ../../modules/services/cockpit.nix
    # ../../modules/services/terraria.nix
  ];

  services.logrotate = {
    enable = true;
    checkConfig = false;
  };

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

  users.users.yi.extraGroups = [ "podman" ];
  users.users.workd.extraGroups = [ "podman" ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    serverTokens = false;

    virtualHosts = {
      # Local test vhost
      "yifuwuqi.local" = {
        serverName = "yifuwuqi.local";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "yifuwuqi.local ok";
          '';
        };
      };

      "yifuwuqi.vpn" = {
        serverName = "yifuwuqi.vpn";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "yifuwuqi.vpn ok";
          '';
        };
      };

      "fufu.land" = {
        forceSSL = false;
        extraConfig = ''
          add_header Content-Type text/markdown;
          return 200 "fufu.land is ok";
        '';
      };
    };
  };

  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    # Container tools
    buildah
    dive
    podman-compose
    podman-tui
    skopeo
    # Security tools
    google-authenticator
  ];
}
