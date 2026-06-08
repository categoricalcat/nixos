# Attic binary cache server on yifuwuqi.
#
# Pre-deploy: generate JWT secret and add to sops as tokens/attic-server-jwt-env:
#   openssl genrsa -traditional 4096 | base64 -w0
#
# Post-deploy bootstrap (on yifuwuqi):
#   atticd-atticadm make-token --sub "*" --validity "10 years"
#   attic login yi http://127.0.0.1:18203 <admin-token>
#   attic cache create yi --public --priority 38
#   attic cache info yi   # → update trusted-public-keys in modules/nix-settings.nix
#   atticd-atticadm make-token --sub "yi" --validity "10 years" --push
#   # → add to sops as tokens/attic-push-token, redeploy
{
  inputs,
  pkgs,
  config,
  allAddresses,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  attic = allAddresses.hosts.yifuwuqi.services.attic;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/atticd.nix: may only be imported on yifuwuqi (services.attic.* hardcodes yifuwuqi addresses)";
    }
  ];

  imports = [ inputs.attic.nixosModules.atticd ];

  nixpkgs.overlays = [ inputs.attic.overlays.default ];

  sops.secrets."tokens/attic-server-jwt-env" = {
    mode = "0400";
  };

  services.atticd = {
    enable = true;
    package = inputs.attic.packages.${system}.attic-server;
    environmentFile = config.sops.secrets."tokens/attic-server-jwt-env".path;
    settings = {
      listen = "[::]:${toString attic.port}";
      chunking = {
        nar-size-threshold = 64 * 1024;
        min-size = 16 * 1024;
        avg-size = 64 * 1024;
        max-size = 256 * 1024;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ attic.port ];
}
