{ config, ... }:

{
  services.ngrok = {
    enable = true;
    # Merge this declarative snippet with secrets from sops files
    extraConfig = {
      version = "3";
    };
    extraConfigFiles = [
      # Store your ngrok auth in sops at: secrets/ngrok.yaml
      # Example keys supported: authtoken, api_key
      config.sops.secrets."ngrok/config".path
    ];
    tunnels = {
      "fufu.land" = {
        proto = "http";
        addr = 80;
      };
      # "fufu.land-https" = {
      #   proto = "tls";
      #   addr = 443;
      # };
    };
  };
}
