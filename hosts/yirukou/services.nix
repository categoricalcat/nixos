{
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/services/openssh.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/samba/client.nix
    ../../modules/services/adguardhome.nix
    ../../modules/services/dnsdist.nix
    ../../modules/services/nginx-proxy.nix
    ../../modules/services/monitoring/netdata.nix
    ./goaccess.nix
  ];

  yi.tailscale = {
    routingMode = "both";
    advertiseRoutes = [ "10.42.0.0/24" ];
  };

  services.xserver = {
    enable = true;
    desktopManager.lxqt.enable = true;
  };

  services.displayManager.sddm.enable = true;

  environment.systemPackages = with pkgs; [
    ungoogled-chromium
  ];
}
