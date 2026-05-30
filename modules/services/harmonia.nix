_:

{
  services.harmonia = {
    cache = {
      enable = true;
      signKeyPaths = [
        "/persist/keys/harmonia/cache-priv-key.pem"
      ];
      settings.bind = "0.0.0.0:5000";
    };
  };

  # Allow cache traffic from the local network (for nginx proxy)
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
