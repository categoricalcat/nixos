{ ... }:

{
  imports = [
    ../../modules/services/ssh
    ../../modules/services/tailscale.nix
    # ../../modules/services/netbird.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/unbound.nix
    ../../modules/services/valkey.nix
    ../../modules/services/nginx-proxy.nix
    # ../../modules/services/monitoring/netdata.nix
    ../../modules/services/monitoring/exporters.nix
    ../../modules/services/monitoring/adguard-exporter
    ../../modules/services/monitoring/promtail.nix
    ../../modules/services/monitoring/security-monitor
    ./goaccess.nix
  ];

  services.security-monitor.enable = true;
  yi.tailscale = {
    routingMode = "both";
    advertiseRoutes = [ "10.42.0.0/24" ];
    ssh = true;
  };

  # yi.netdata = {
  #   childMode = true;
  # };
}
