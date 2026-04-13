# Services configuration module

{
  pkgs,
  addresses,
  ...
}:

{
  imports = [
    ../../modules/services/samba/server.nix
    ../../modules/services/avahi.nix
    ../../modules/services/openssh.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/cloudflared.nix
    ../../modules/services/zerotier.nix
    ../../modules/services/ollama-amdgpu.nix
    # ../../modules/services/playit-agent.nix
    ../../modules/services/localtonet.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/omada-controller.nix
    # ../../modules/services/github-runner.nix
    ../../modules/services/cockpit.nix
    # ../../modules/services/terraria.nix
    ../../modules/services/nextcloud
  ];

  services.logrotate = {
    enable = true;
    checkConfig = false;
  };

  services.tailscale = {
    useRoutingFeatures = "server";
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
      "sshd" = {
        settings = {
          mode = "aggressive";
        };
        enabled = true;
      };
      "nginx-http-auth".enabled = true;
      "nginx-botsearch".enabled = true;
      "nginx-badbots".enabled = true;
    };
  };

  services.ollama-amdgpu = {
    enable = true;
    rocmTargets = [ "gfx1035" ];
    rocmOverrideGfx = "10.3.0";
  };

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

      "${addresses.network.tailscale.ipv4.host}" = {
        serverName = "${addresses.network.tailscale.ipv4.host}";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "${addresses.network.tailscale.ipv4.host} ok";
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
    google-authenticator
  ];
}
