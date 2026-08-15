# Services configuration module

{
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/services/samba/server.nix
    ../../modules/services/avahi.nix
    ../../modules/services/openssh.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/unbound.nix
    ../../modules/services/cloudflared.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/ai/llama-cpp.nix
    # ../../modules/services/netbird.nix
    # ../../modules/services/playit-agent.nix
    # ../../modules/services/localtonet.nix
    # ../../modules/services/omada-controller.nix
    ../../modules/services/github-runner.nix
    ../../modules/services/forgejo.nix
    ../../modules/services/forgejo-runner.nix
    ../../modules/services/cockpit.nix
    # ../../modules/services/terraria.nix
    #../../modules/services/nextcloud
    # ../../modules/services/monitoring/netdata.nix
    ../../modules/services/monitoring/exporters.nix
    ../../modules/services/monitoring/adguard-exporter
    ../../modules/services/monitoring/prometheus.nix
    ../../modules/services/monitoring/loki.nix
    ../../modules/services/monitoring/promtail.nix
    ../../modules/services/monitoring/grafana.nix
    ../../modules/services/webdav.nix
    ../../modules/services/searxng.nix
    ../../modules/services/valkey.nix
    ../../modules/services/firecrawl.nix
    ../../modules/services/opencode.nix
    ../../modules/services/atticd.nix
    ../../modules/services/attic-watch-store.nix
    ../../modules/services/arr
    ../../modules/services/qbittorrent-vpn.nix
    ../../modules/services/slskd.nix
    ../../modules/services/homepage.nix
    ../../modules/services/ai/sillytavern.nix
  ];
  yi.tailscale = {
    routingMode = "client";
    # Servers must NOT use an exit node. With one set, tailscaled installs
    # `default dev tailscale0` (and, with --exit-node-allow-lan-access=false,
    # captures RFC1918 subnets too) into route table 52. Replies to LAN
    # traffic - both 192.168.0.0/24 via enp4s0 and 10.42.0.0/24 via eno1 -
    # then leave through tailscale0 instead of the interface they arrived
    # on, so on-LAN peers see 100% packet loss to this host.
    exitNodeHost = null;
    acceptRoutes = false;
    ssh = true;
  };

  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  services = {
    logrotate = {
      enable = true;
      checkConfig = true;
    };

    fail2ban = {
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

    llama-cpp-node = {
      enable = true;
      backend = "vulkan";
    };

    tor = {
      enable = true;
      client.enable = true;
    };

    fwupd.enable = true;
    opencode.enable = true;
  };
  yi.services.sillytavern.enable = true;

  environment.systemPackages = with pkgs; [
    google-authenticator
  ];
}
