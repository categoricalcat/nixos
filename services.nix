# Services configuration module

{ config, pkgs, lib, ... }:

{
  # Printing service
  # services.printing.enable = true;  # Disabled - not typically needed on servers

  # Code-server
  services.code-server.enable = true;

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    ports = [ 24212 ];
    openFirewall = true;
    settings = {
      AllowUsers = [
        "fufud"
        "workd"
      ];
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      ChallengeResponseAuthentication = true;
      AuthenticationMethods = "publickey keyboard-interactive";

      # Port forwarding settings
      AllowTcpForwarding = "yes"; # Enable TCP port forwarding
      AllowAgentForwarding = true; # Allow SSH agent forwarding
      AllowStreamLocalForwarding = "yes"; # Allow Unix domain socket forwarding
      PermitTunnel = "yes"; # Allow tun device forwarding (VPN over SSH)
      GatewayPorts = "clientspecified"; # Allow remote hosts to connect to forwarded ports
      # Options for GatewayPorts:
      # - "no" = only loopback addresses can connect (default)
      # - "yes" = all interfaces can connect
      # - "clientspecified" = client decides per forwarding

      # Performance optimizations
      # UseDNS = false; # Already set by default, but explicitly disable for faster connections
      Compression = false; # Disable compression - it hurts performance on fast networks
      TCPKeepAlive = true; # Detect dead connections
      ClientAliveInterval = 30; # Send keepalive every 60 seconds
      ClientAliveCountMax = 10; # Disconnect after 3 missed keepalives

      # Cipher and algorithm optimizations (fastest first)
      Ciphers = [
        "chacha20-poly1305@openssh.com" # Fast on modern CPUs
        "aes128-gcm@openssh.com" # Hardware accelerated on most CPUs
        "aes256-gcm@openssh.com" # Secure but slightly slower
        "aes128-ctr" # Fallback
        "aes256-ctr" # Fallback
      ];

      KexAlgorithms = [
        "curve25519-sha256" # Fast and secure
        "curve25519-sha256@libssh.org" # Alternative implementation
        "diffie-hellman-group-exchange-sha256"
      ];

      # Use faster MACs
      Macs = [
        "umac-128-etm@openssh.com" # Fastest
        "hmac-sha2-256-etm@openssh.com" # Good balance
        "hmac-sha2-512-etm@openssh.com" # More secure but slower
      ];
    };

    # Additional performance settings
    extraConfig = ''
      # Enable connection multiplexing for faster subsequent connections
      MaxSessions 10
      MaxStartups 10:30:100

      # Faster SFTP (if using internal-sftp)
      Subsystem sftp internal-sftp
    '';
  };

  # PAM configuration for SSH with Google Authenticator
  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  # MTR network diagnostic tool
  programs.mtr.enable = true;

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "categoricalcat";
        email = "catufuzgu@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      core = {
        sshCommand = "ssh";
      };
    };
  };

  # SSH agent - enable at system level
  programs.ssh = {
    startAgent = true;
    # enable = true;
    agentTimeout = "15m";
    # addKeysToAgent = "confirm";
  };

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
    nssmdns4 = true;
    nssmdns6 = true;
  };

  services.fail2ban.enable = true;

  services.ollama = {
    enable = true;
    acceleration = "rocm";
    loadModels = [ "deepseek-r1:1.5b" ];
    # rocmOverrideGfx = "gfx1035";
  };

  # Podman configuration (Docker replacement)
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    dockerSocket.enable = false;
    defaultNetwork.settings = {
      dns_enabled = true;
      ipv6_enabled = true;
      mtu = 1500;
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
      search = [ "docker.io" "quay.io" "ghcr.io" ];
    };
    
    containersConf.settings = {
      containers = {
        dns_servers = [ "8.8.8.8" "1.1.1.1" ];
        log_driver = "json-file";
        log_size_max = 10485760;  # 10MB in bytes (10 * 1024 * 1024)
        default_ulimits = [
          "nofile=65536:65536"
        ];
      };
      
      network = {
        default_subnet_pools = [
          { base = "172.17.0.0/16"; size = 24; }
          { base = "172.18.0.0/16"; size = 24; }
        ];
      };
    };
  };

  users.users.fufud.extraGroups = [ "podman" ];
  users.users.workd.extraGroups = [ "podman" ];

  environment.systemPackages = with pkgs; [
    podman-compose  # open source bitchess
    podman-tui
    dive
    skopeo
  ];
}
