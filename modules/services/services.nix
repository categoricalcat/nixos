# Services configuration module

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./avahi.nix
    ./openssh.nix
    ./dnsmasq.nix
  ];

  # Printing service
  # services.printing.enable = true;  # Disabled - not typically needed on servers

  # Code-server
  services.code-server.enable = true;

  # PAM configuration for SSH with Google Authenticator
  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  # MTR network diagnostic tool
  programs.mtr.enable = true;

  # SSH agent - enable at system level
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
        dns_servers = [
          "8.8.8.8"
          "1.1.1.1"
        ];
        log_driver = "json-file";
        log_size_max = 10485760; # 10MB in bytes (10 * 1024 * 1024)
        default_ulimits = [
          "nofile=65536:65536"
        ];
      };

      network = {
        default_subnet_pools = [
          {
            base = "172.17.0.0/16";
            size = 24;
          }
          {
            base = "172.18.0.0/16";
            size = 24;
          }
        ];
      };
    };
  };

  users.users.fufud.extraGroups = [ "podman" ];
  users.users.workd.extraGroups = [ "podman" ];

  # # Enable getty on USB serial
  # systemd.services."serial-getty@ttyUSB0" = {
  #   enable = true;
  #   wantedBy = [ "getty.target" ];
  #   serviceConfig.Restart = "always";
  # };

  services.cockpit = {
    enable = true;
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
}
