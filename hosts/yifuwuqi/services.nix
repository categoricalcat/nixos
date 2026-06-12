# Services configuration module

{
  pkgs,
  allAddresses,
  ...
}:

let
  yitaishiTs = allAddresses.hosts.yitaishi.network.tailscale.ipv4.host;
in
{
  imports = [
    ../../modules/services/samba/server.nix
    ../../modules/services/avahi.nix
    ../../modules/services/openssh.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/cloudflared.nix
    ../../modules/services/netbird.nix
    ../../modules/services/ai/llama-swap.nix
    # ../../modules/services/playit-agent.nix
    # ../../modules/services/localtonet.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/omada-controller.nix
    ../../modules/services/github-runner.nix
    ../../modules/services/forgejo.nix
    ../../modules/services/forgejo-runner.nix
    ../../modules/services/cockpit.nix
    # ../../modules/services/terraria.nix
    #../../modules/services/nextcloud
    ../../modules/services/monitoring/netdata.nix
    ../../modules/services/webdav.nix
    ../../modules/services/searxng.nix
    ../../modules/services/opencode.nix
    ../../modules/services/atticd.nix
    ../../modules/services/attic-watch-store.nix
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

    llama-swap-amdgpu = {
      enable = true;
      rocmTargets = [ "gfx1035" ];
      rocmOverrideGfx = "10.3.0";
      rpcPeers = [ "${yitaishiTs}:50052" ];
      tensorSplit = "1,0";
    };

    tor = {
      enable = true;
      client.enable = true;
    };

    fwupd.enable = true;
    opencode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    google-authenticator
  ];
}
