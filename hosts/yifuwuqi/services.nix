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
    # ../../modules/services/zerotier.nix
    ../../modules/services/ai/llama-swap.nix
    # ../../modules/services/playit-agent.nix
    # ../../modules/services/localtonet.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/omada-controller.nix
    ../../modules/hercules-ci.nix
    ../../modules/services/cockpit.nix
    # ../../modules/services/terraria.nix
    #../../modules/services/nextcloud
    ../../modules/services/monitoring/netdata.nix
    ../../modules/services/webdav.nix
    ../../modules/services/searxng.nix
    ../../modules/services/opencode.nix
    ../../modules/services/harmonia.nix
  ];

  services.logrotate = {
    enable = true;
    checkConfig = true;
  };

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

  services.llama-swap-amdgpu = {
    enable = true;
    rocmTargets = [ "gfx1035" ];
    rocmOverrideGfx = "10.3.0";
    # Pull yitaishi's tailscale IP from the address registry so we don't
    # repeat the hardcoded-IP drift that put rpcPeers on the wrong host.
    rpcPeers = [ "${yitaishiTs}:50052" ];
    # Device order is [RPC0, ROCm0_local], so "1,0" sends 100% of weights
    # and KV to the remote 7900 XTX and skips the local 680M entirely.
    # auto-distribution by free VRAM still funnels ~28% to the local APU,
    # which then bottlenecks the pipeline at 100% busy while the remote dGPU
    # idles between hops. Measured benchmark on 7B-class models: 25 tok/s with
    # auto-split vs 56 tok/s with "1,0" (2.27x). All RPC-tagged models in
    # models.nix fit in the 7900 XTX's 24 GiB on their own.
    tensorSplit = "1,0";
  };

  # Tor SOCKS proxy for SearXNG to route upstream engine requests through
  # random exit nodes, bypassing IP-based rate limits and government blocks.
  #
  # `client.enable = true` is REQUIRED for SOCKS to actually listen.
  # nixpkgs#445350: when `client.enable` is unset, the NixOS Tor module
  # force-overrides `SOCKSPort = [ 0 ]` regardless of `settings.SOCKSPort`,
  # so Tor starts but accepts no client connections. The default
  # `client.socksListenAddress` is `127.0.0.1:9050`, matching what SearXNG
  # targets -- declaring `settings.SOCKSPort` alongside would create a
  # duplicate 9050 listener and Tor would refuse to start.
  services.tor = {
    enable = true;
    client.enable = true;
  };

  services.fwupd.enable = true;

  services.opencode.enable = true;

  environment.systemPackages = with pkgs; [
    google-authenticator
  ];
}
