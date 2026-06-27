# Self-hosted git forge with read-only pull mirror from GitHub.
#
# Bootstrap (once, via git.fufu.land UI):
#   1. Create admin user, then set service.DISABLE_REGISTRATION = true and redeploy
#   2. New Migration -> mirror https://github.com/categoricalcat/nixos (read-only)
#   3. Site Administration -> Actions -> Runners -> Create new runner
{ config, allAddresses, ... }:

let
  services = allAddresses.hosts.yifuwuqi.services;
  inherit (services) forgejo;
  postgres = services.postgresql;
  forgejoServer = config.services.forgejo.settings.server;
  trustedCidrs = [
    allAddresses.hosts.yirukou.network.lan.ipv4.cidr
    # allAddresses.hosts.yifuwuqi.network.tailscale.ipv4.cidr
    allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr
  ];
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/forgejo.nix: may only be imported on yifuwuqi (services.forgejo.domain hardcodes yifuwuqi addresses)";
    }
  ];

  services.forgejo = {
    enable = true;
    database = {
      type = "postgres";
      createDatabase = false;
      socket = postgres.socketDir;
      name = postgres.databases.forgejo;
      user = postgres.databases.forgejo;
    };
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = forgejo.domain;
        ROOT_URL = "https://${forgejoServer.DOMAIN}/";
        HTTP_PORT = forgejo.httpPort;
        SSH_PORT = 24212;
        START_SSH_SERVER = false;
      };
      # Flip to true after creating the admin account.
      service.DISABLE_REGISTRATION = false;
      actions.ENABLED = true;
      webhook.ALLOWED_HOST_LIST = "external,loopback," + builtins.concatStringsSep "," trustedCidrs;
      "repository.mirror".ENABLED = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ forgejoServer.HTTP_PORT ];

  systemd.services.forgejo = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };
}
