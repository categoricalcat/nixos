{
  services.tailscale.enable = true;

  # Tailscale's default port for direct connections
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # Trust the tailscale interface
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
